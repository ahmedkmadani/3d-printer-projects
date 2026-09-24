// ============================================================================
//  Jota — the real SyncService
//
//  The sequence from the contract, in order, with resume:
//
//    connect  ->  auth (first time)  ->  clock  ->  index
//             ->  for each pending note: fetch / data… / verify / ack
//
//  The three rules this file exists to enforce:
//
//    1. NEVER ack without a verified CRC32 over the whole note. An ack tells the
//       device to forget the recording; the phone's copy becomes the only copy at
//       that instant. A wrong ack destroys a note silently.
//    2. Subscribe to `data` BEFORE writing `fetch`, or the first chunks land with
//       nobody listening.
//    3. Keep partial bytes keyed by note id and resume from what we hold. A
//       dropped link should cost the bytes still outstanding and nothing else —
//       no retry button, no restart, no user involvement.
// ============================================================================
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../audio/adpcm.dart';
import '../audio/crc32.dart';
import '../data/audio_store.dart';
import '../data/note.dart';
import '../data/note_repository.dart';
import '../data/partial_store.dart';
import '../data/settings_store.dart';
import 'device_diag.dart';
import 'jota_link.dart';
import 'jota_protocol.dart';
import 'jota_scanner.dart';
import 'sync_service.dart';

// Every step of a sync, on one tag, so a stalled run can be read off logcat:
//
//     adb logcat -s flutter | grep jota/ble
//
// This file had no logging at all, and the cost was days: a sync that read the
// index and then quietly stopped looked identical from the outside whether the
// device sent nothing, the parse returned nothing, or a subscribe threw. All
// three were guessed at before any of them was measured.
void _log(String step, [Object? detail]) {
  debugPrint('jota/ble  $step${detail == null ? '' : '  $detail'}');
}

class SyncEngine implements SyncService {
  SyncEngine({
    required NoteRepository notes,
    required PartialStore partials,
    required AudioStore audio,
    required SettingsStore settings,
  })  : _notes = notes,
        _partials = partials,
        _audio = audio,
        _settings = settings;

  final NoteRepository _notes;
  final PartialStore _partials;
  final AudioStore _audio;

  /// Read for one thing only: this phone's [SettingsStore.appId], which every
  /// connection presents so the device can recognise its owner.
  final SettingsStore _settings;

  final StreamController<SyncProgress> _progress =
      StreamController<SyncProgress>.broadcast();

  @override
  Stream<SyncProgress> get progress => _progress.stream;

  SyncProgress _last = SyncProgress.idle;

  @override
  SyncProgress get current => _last;

  DeviceDiag? _lastDiag;

  @override
  DeviceDiag? get lastDiag => _lastDiag;

  bool _running = false;

  @override
  bool get isRunning => _running;

  /// No chunk for this long and we treat the transfer as stalled. Generous: a
  /// busy phone can starve the BLE callback for a while, and giving up early only
  /// costs a reconnect.
  static const Duration chunkTimeout = Duration(seconds: 12);

  /// A note whose CRC keeps failing after this many whole attempts is a real
  /// fault, not a flaky link. We stop re-downloading it and surface it.
  static const int maxCrcAttempts = 3;

  void _emit(SyncProgress p) {
    _last = p;
    if (!_progress.isClosed) _progress.add(p);
  }

  /// Bring a freshly opened link up to authenticated, and return the status it
  /// answered with.
  ///
  /// The device's `authed` is PER CONNECTION, so every link starts
  /// unauthenticated — a sync run, a tag read, a clock write, all of them.
  ///
  /// This used to decide it was already paired if `readStatus()` merely
  /// succeeded. It always succeeds: `status` is deliberately ungated, precisely
  /// so an unauthenticated phone can discover that it is unauthenticated. So the
  /// app never sent anything, `index` answered `[]` to an unauthenticated
  /// reader, and every sync reported "all caught up" while the notes sat on the
  /// device and the advertisement kept saying three were waiting.
  Future<JotaStatus> _authenticate(
    JotaLink link,
    PairCodeRequest onPairCodeNeeded,
  ) async {
    JotaStatus status = await link.readStatus();
    if (status.authed) return status;

    // Introduce ourselves. If this phone is the owner, that is the whole
    // handshake — no code, no prompt, nothing shown on the e-paper.
    await link.authenticate(_settings.appId);
    status = await link.readStatus();
    if (status.authed) return status;

    // Not the owner (or nobody is). Now the six digits are genuinely needed.
    _emit(
      SyncProgress(
        phase: SyncPhase.authenticating,
        message: status.owned
            ? 'This Jota is paired to another phone — enter the code it shows'
            : 'Enter the code shown on the device',
      ),
    );
    final String? code = await onPairCodeNeeded();
    if (code == null) {
      throw const JotaLinkException('pairing cancelled');
    }

    await link.authenticate(_settings.appId, code: code);
    status = await link.readStatus();
    if (status.authed) return status;

    // Be specific: "wrong code" and "press PAIR on the device first" need
    // different things from the person holding it.
    throw JotaLinkException(
      status.owned
          ? 'wrong code — open PAIR on the Jota and use the code it shows'
          : 'the code did not match; open PAIR on the Jota for a fresh one',
      isAuthFailure: true,
    );
  }

  @override
  Future<SyncResult> run(
    String remoteId, {
    required PairCodeRequest onPairCodeNeeded,
    bool autoConnect = false,
  }) async {
    if (_running) {
      return const SyncResult(
        notesAdded: 0,
        notesRemaining: 0,
        error: 'a sync is already running',
      );
    }
    _running = true;

    JotaLink? link;
    int added = 0;
    int remaining = 0;

    try {
      // ---- connect ------------------------------------------------------
      _emit(
        const SyncProgress(
          phase: SyncPhase.connecting,
          message: 'Connecting',
        ),
      );
      link = await JotaLink.open(
        JotaScanner.deviceFor(remoteId),
        autoConnect: autoConnect,
      );

      final String deviceId = link.remoteId;

      final JotaStatus status = await _authenticate(link, onPairCodeNeeded);

      // ---- diag -----------------------------------------------------------
      // One read per connection, never fatal: null is old firmware or a
      // refusal, and a device that cannot introduce itself still hands over
      // audio — the part that cannot wait.
      final DeviceDiag? diag = await link.readDiag();
      if (diag != null) {
        _lastDiag = diag;
        _log('diag', diag);
      }

      // ---- clock --------------------------------------------------------
      // Unconditional, every connect. The device has no other time source, so
      // this is the only thing that makes its timestamps real rather than an
      // offset from boot. `clockLooksUnset` only decides what we SAY — the write
      // happens either way.
      _emit(
        SyncProgress(
          phase: SyncPhase.settingClock,
          message: status.clockLooksUnset() ? 'Setting clock' : 'Syncing clock',
        ),
      );
      await link.setClock();

      // ---- tags ----------------------------------------------------------
      // The phone owns the tag list; the device holds a copy so it can offer
      // them in the seconds after a recording. Pushing it HERE, as part of
      // every authenticated connection, is the fix for a real bug: it used to
      // happen only after a sync had completed successfully, so while
      // transfers were failing the device kept whatever list it had — in
      // practice a single leftover test tag — and the defaults never landed.
      // Tags that only arrive once the thing they annotate already worked are
      // no use to anyone.
      //
      // Only the top few travel. The device offers them one button-press at a
      // time on a panel that takes two seconds to redraw, so its list is
      // deliberately shorter than the app's — see kDeviceTagSlots.
      try {
        final List<String> want = _settings.tags.take(kDeviceTagSlots).toList();
        await link.writeTags(want);
        _log('tags', 'pushed ${want.length}: $want');
      } on Exception catch (e) {
        // Never fatal. A device with a stale tag list still hands over audio,
        // and that is the part that cannot wait.
        _log('tags', 'push failed (not fatal): $e');
      }

      // ---- index --------------------------------------------------------
      _emit(
        const SyncProgress(
          phase: SyncPhase.readingIndex,
          message: 'Reading index',
        ),
      );
      final List<JotaNoteIndexEntry> index = await link.readIndex();
      _log(
          'index',
          '${index.length} note(s): '
              '${index.map((JotaNoteIndexEntry e) => '#${e.id}/${e.bytes}b').join(', ')}');
      if (index.isEmpty) {
        _log('index', 'EMPTY - nothing to fetch, this run ends here');
      }

      // Drop partials for notes the device no longer offers — deleted on the
      // device, or acked in a run whose bookkeeping we lost.
      await _partials.retainOnly(
        deviceId,
        index.map((JotaNoteIndexEntry e) => e.id).toSet(),
      );

      // ---- data subscription, ONCE for the session ----------------------
      // Opened before the first `fetch` and kept for every note, so there is no
      // window in which a chunk can arrive unobserved.
      _log('subscribe', 'opening data notifications');
      final Stream<List<int>> dataStream = await link.openDataStream();
      _log('subscribe', 'open');

      final List<int> known = (await _notes.knownIds(deviceId)).toList();
      _log('known', '${known.length} already stored: $known');

      _emit(
        SyncProgress(
          phase: SyncPhase.transferring,
          notesTotal: index.length,
          message: 'Syncing',
        ),
      );

      for (final JotaNoteIndexEntry entry in index) {
        if (!link.isConnected) {
          remaining = index.length - added;
          break;
        }

        // Already have it, byte-identical? The ack must have been lost on the way
        // out. Re-ack without moving a single byte of audio.
        if (known.contains(entry.id)) {
          final Note? have = await _notes.byId(deviceId, entry.id);
          if (have != null && have.crc == entry.crc) {
            _log(
              'skip',
              '#${entry.id} already stored byte-identical, re-acking',
            );
            await link.sendAck(entry.id, entry.crc);
            added++;
            _emit(
              SyncProgress(
                phase: SyncPhase.transferring,
                notesDone: added,
                notesTotal: index.length,
                currentNoteId: entry.id,
                message: 'Already stored',
              ),
            );
            continue;
          }
        }

        _log('transfer', 'starting #${entry.id} (${entry.bytes} bytes)');
        final bool ok = await _transferOne(
          link: link,
          dataStream: dataStream,
          deviceId: deviceId,
          entry: entry,
          notesDone: added,
          notesTotal: index.length,
        );

        _log('transfer', '#${entry.id} ${ok ? 'complete' : 'INCOMPLETE'}');
        if (ok) {
          added++;
        } else {
          remaining++;
        }
      }

      _emit(
        SyncProgress(
          phase: SyncPhase.done,
          notesDone: added,
          notesTotal: index.length,
          message: added == 0 ? 'Nothing to sync' : 'Synced',
        ),
      );

      _log('done', 'added=$added remaining=$remaining');
      return SyncResult(notesAdded: added, notesRemaining: remaining);
    } on Exception catch (e, st) {
      // A failure here is routine, not exceptional: the user walked out of range.
      // Everything downloaded so far is on disk and the device still lists the
      // note, so the next connection continues.
      //
      // Routine is not the same as invisible, though. _humanise() throws away
      // the type and the stack, and what reaches the screen is one soft line
      // like "timed out" — which is why a sync that died inside the subscribe
      // call was indistinguishable from a device with nothing to send.
      _log('FAILED', '${e.runtimeType}: $e');
      _log('FAILED', st.toString().split('\n').take(4).join(' | '));
      _emit(
        SyncProgress(
          phase: SyncPhase.failed,
          notesDone: added,
          error: _humanise(e),
        ),
      );
      return SyncResult(
        notesAdded: added,
        notesRemaining: remaining,
        error: _humanise(e),
      );
    } finally {
      _running = false;
      await link?.close();
    }
  }

  /// Fetch one note to completion, verify it, ack it, store it.
  ///
  /// Returns true only if the note is now safely in the archive.
  Future<bool> _transferOne({
    required JotaLink link,
    required Stream<List<int>> dataStream,
    required String deviceId,
    required JotaNoteIndexEntry entry,
    required int notesDone,
    required int notesTotal,
  }) async {
    await _notes.rememberPartial(
      deviceId: deviceId,
      noteId: entry.id,
      expectedBytes: entry.bytes,
      crc: entry.crc,
      secs: entry.secs,
      // A device that has never been told the time sends 0, and a note stamped
      // 0 lands in 1970 — outside every window the app measures, so three real
      // notes showed up as "0 notes, 0 minutes this week". The phone always
      // knows the real time; when the device does not, the moment we received
      // the note is the closest true thing we have.
      recordedAt: entry.time > 0
          ? entry.time
          : DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    // Where do we start? resumeOffset() rounds down to a 256-byte ADPCM block —
    // every block carries the predictor and step index it needs in its own
    // header, so a block boundary is the only offset the decoder can start from
    // cold, and it is what the firmware seeks to.
    final int offset = await _partials.resumeOffset(deviceId, entry.id);
    final bool resumed = offset > 0;

    if (offset >= entry.bytes) {
      // We already hold the whole thing from a previous run that died before it
      // could verify. Skip straight to the CRC.
      return _verifyAndAck(
        link: link,
        deviceId: deviceId,
        entry: entry,
        notesDone: notesDone,
        notesTotal: notesTotal,
      );
    }

    _emit(
      SyncProgress(
        phase: SyncPhase.transferring,
        notesDone: notesDone,
        notesTotal: notesTotal,
        currentNoteId: entry.id,
        bytesReceived: offset,
        bytesExpected: entry.bytes,
        resumed: resumed,
        message: resumed ? 'Resuming' : 'Receiving',
      ),
    );

    final Completer<void> done = Completer<void>();
    Timer? stall;
    int received = offset;
    Object? failure;

    void resetStall() {
      stall?.cancel();
      stall = Timer(chunkTimeout, () {
        if (!done.isCompleted) {
          failure = const JotaLinkException('transfer stalled');
          done.complete();
        }
      });
    }

    // The device reports a bad fetch through `status`, not through `data`:
    // "fetch with offset beyond the file length, or for an unknown id, gets a
    // status notify with {"error":"range"} and no data."
    final StreamSubscription<JotaStatus> statusSub = link.statusStream.listen((
      JotaStatus s,
    ) {
      if (s.isError && !done.isCompleted) {
        failure = JotaLinkException('device rejected fetch: ${s.error}');
        done.complete();
      }
    });

    // Disk writes are chained, and `received` moves BEFORE any await.
    //
    // This handler used to be `async` and await the append inline. Dart does
    // not serialise async stream listeners: chunks arrive faster than a disk
    // write completes, so several handlers ran at once, every one of them read
    // the same stale `received`, and their appends interleaved. The byte count
    // still reached the target — so nothing stalled and nothing threw — while
    // the bytes on disk were out of order. Every note then failed its CRC and
    // came back INCOMPLETE with no error to show for it.
    //
    // The laptop probe appends to an in-memory buffer synchronously, which is
    // precisely why it could pull all three notes while the app could not pull
    // one.
    Future<void> writes = Future<void>.value();

    // What actually came off the radio, so a CRC failure can be compared
    // against a known-good capture instead of reasoned about.
    int chunks = 0;
    final List<int> firstBytes = <int>[];
    final Set<int> chunkSizes = <int>{};

    final StreamSubscription<List<int>> dataSub = dataStream.listen(
      (List<int> chunk) {
        if (done.isCompleted || chunk.isEmpty) return;
        resetStall();

        // "Do not assume chunk boundaries mean anything — reassemble by order,
        // and trust only the CRC." So: append in arrival order, never inspect.
        // Clip a final chunk that overshoots the declared length rather than
        // writing bytes that are not part of the note.
        final int room = entry.bytes - received;
        if (room <= 0) return;
        // OWN the bytes. `chunk` belongs to the platform channel and must not
        // be held across an await — the write below is queued, so by the time
        // it runs the underlying buffer may already carry a later
        // notification. sublist() copies, but the unclipped path did not, so
        // the common case was handing the file a reference to memory that was
        // still moving.
        final Uint8List use = Uint8List.fromList(
          chunk.length > room ? chunk.sublist(0, room) : chunk,
        );

        // Synchronous, so the next chunk sees the true figure, and queued in
        // arrival order so the file is written in that order too.
        received += use.length;
        chunks++;
        chunkSizes.add(chunk.length);
        if (firstBytes.length < 16) {
          firstBytes.addAll(use.take(16 - firstBytes.length));
        }
        writes = writes.then((_) => _partials.append(deviceId, entry.id, use));

        _emit(
          SyncProgress(
            phase: SyncPhase.transferring,
            notesDone: notesDone,
            notesTotal: notesTotal,
            currentNoteId: entry.id,
            bytesReceived: received,
            bytesExpected: entry.bytes,
            resumed: resumed,
            message: resumed ? 'Resuming' : 'Receiving',
          ),
        );

        if (received >= entry.bytes && !done.isCompleted) {
          done.complete();
        }
      },
      onError: (Object e) {
        if (!done.isCompleted) {
          failure = e;
          done.complete();
        }
      },
    );

    try {
      resetStall();
      // The subscription is live (it was opened for the session), so it is safe
      // to ask for the bytes now.
      await link.requestFetch(entry.id, offset);
      await done.future;
      // Every queued write must land before anything reads the file back to
      // CRC it. Without this the verify races the last few chunks.
      await writes;
      _log(
        'chunks',
        '#${entry.id} $chunks notification(s), sizes=${chunkSizes.toList()..sort()}, '
            'first16=${firstBytes.map((int b) => b.toRadixString(16).padLeft(2, "0")).join()}',
      );
    } finally {
      stall?.cancel();
      await dataSub.cancel();
      await statusSub.cancel();
    }

    if (failure != null) {
      // WHY it failed, and how far it got. "INCOMPLETE" on its own cannot tell
      // a transfer that never received a single byte from one that stalled
      // near the end, and those have completely different causes.
      _log(
        'transfer',
        '#${entry.id} failed after ${received - offset} of ${entry.bytes} '
            'bytes (mtu=${link.mtu}): ${_humanise(failure!)}',
      );
      // Partial bytes stay on disk. The note stays pending on the device because
      // we never acked, so it stays in the advertisement's count, so the phone
      // wakes for it again. Nothing to retry by hand.
      _emit(
        SyncProgress(
          phase: SyncPhase.transferring,
          notesDone: notesDone,
          notesTotal: notesTotal,
          currentNoteId: entry.id,
          bytesReceived: received,
          bytesExpected: entry.bytes,
          error: _humanise(failure!),
        ),
      );

      final Object f = failure!;
      if (f is JotaLinkException && f.message.contains('range')) {
        // Our offset was not valid for this file — the note changed underneath
        // us. Start it over rather than resuming into garbage.
        await _partials.discard(deviceId, entry.id);
      }
      return false;
    }

    return _verifyAndAck(
      link: link,
      deviceId: deviceId,
      entry: entry,
      notesDone: notesDone,
      notesTotal: notesTotal,
    );
  }

  /// CRC the complete note, and only then ack and archive.
  Future<bool> _verifyAndAck({
    required JotaLink link,
    required String deviceId,
    required JotaNoteIndexEntry entry,
    required int notesDone,
    required int notesTotal,
  }) async {
    _emit(
      SyncProgress(
        phase: SyncPhase.verifying,
        notesDone: notesDone,
        notesTotal: notesTotal,
        currentNoteId: entry.id,
        bytesReceived: entry.bytes,
        bytesExpected: entry.bytes,
        message: 'Verifying',
      ),
    );

    final int held = await _partials.receivedBytes(deviceId, entry.id);
    if (held != entry.bytes) {
      _log('verify', '#${entry.id} short: hold $held of ${entry.bytes} bytes');
      return false; // incomplete; try again next connection
    }

    // Streamed by the store rather than read whole: a long note is several MB
    // and there is no reason to hold it in memory just to checksum it.
    final int crc = await _partials.crc32Of(deviceId, entry.id);

    if (!Crc32.matches(crc, entry.crc)) {
      // Say it. A CRC failure on a full-length file means the bytes arrived
      // but were assembled wrongly, which is a completely different fault from
      // a transfer that stopped early — and for a long time both showed up as
      // the single word INCOMPLETE.
      _log(
        'verify',
        '#${entry.id} CRC MISMATCH: got ${crc.toRadixString(16).padLeft(8, "0")} '
            'want ${entry.crc} over $held bytes',
      );
      // The bytes are not the note. Throw them away — keeping them would make
      // the next resume ask for the wrong offset — and let the device offer it
      // again. We do NOT ack, so nothing is lost on its side.
      final int attempts = await _notes.bumpPartialAttempts(deviceId, entry.id);
      await _partials.discard(deviceId, entry.id);
      _emit(
        SyncProgress(
          phase: SyncPhase.transferring,
          notesDone: notesDone,
          notesTotal: notesTotal,
          currentNoteId: entry.id,
          error: attempts >= maxCrcAttempts
              ? 'Note ${entry.id} failed verification $attempts times'
              : 'Checksum mismatch, will retry',
        ),
      );
      return false;
    }

    // ---- the note is real ------------------------------------------------
    // Move it into the archive BEFORE acking. If the process dies between these
    // two steps the device re-offers the note, we find it already stored with a
    // matching CRC, and the fast path above re-acks it without a transfer. The
    // other order would lose the note.
    final String dest = _audio.archivePathFor(deviceId, entry.id);
    await _partials.promote(deviceId, entry.id, dest);

    await _notes.insert(
      Note(
        deviceId: deviceId,
        noteId: entry.id,
        recordedAt: entry.recordedAt,
        secs: entry.secs > 0
            ? entry.secs
            : Adpcm.secondsForBytes(entry.bytes).round(),
        bytes: entry.bytes,
        crc: entry.crc,
        adpcmPath: dest,
        // Whatever was armed on the device's TAGS screen when this was
        // recorded. The phone can still change it later; this is just the
        // filing the device already did for you.
        tag: entry.tag,
        syncedAt: DateTime.now(),
      ),
    );

    await link.sendAck(entry.id, entry.crc);
    await _notes.forgetPartial(deviceId, entry.id);

    _emit(
      SyncProgress(
        phase: SyncPhase.transferring,
        notesDone: notesDone + 1,
        notesTotal: notesTotal,
        currentNoteId: entry.id,
        message: 'Stored',
      ),
    );
    return true;
  }

  // ---- tags -----------------------------------------------------------------
  //
  // A tag operation opens a link of its own, so it must not collide with one.
  // Two things enforce that:
  //
  //  * it refuses to run while a sync holds the radio. flutter_blue_plus hands
  //    out ONE BluetoothDevice per remote id, so a second `open` re-discovers
  //    services underneath the sync and the matching `close` disconnects the
  //    link the sync is still using — which showed up as the app hanging until
  //    the transfer's timeouts expired.
  //  * tag operations queue behind each other on [_tagOp], so editing three
  //    tags in a row is three writes over one connection at a time rather than
  //    three overlapping connects.
  //
  // The connect timeout is also much shorter than a sync's. A tag write is a
  // background courtesy — the list is already saved on the phone — so it should
  // give up quickly rather than sit on the radio.

  static const Duration _tagTimeout = Duration(seconds: 8);

  Future<void> _tagOp = Future<void>.value();

  /// Run [body] against an authenticated link, serialised against every other
  /// tag operation.
  @override
  Future<void> forgetOnDevice(String remoteId) {
    // _neverPrompt is not passed here: if this phone is NOT the owner there is
    // nothing to forget, and asking for a pair code in order to un-pair would
    // be a strange thing to put in front of someone.
    return _withTagLink(remoteId, _neverPromptCode, (JotaLink link) async {
      await link.forgetMe(_settings.appId);
      _log('forget', 'bond cleared on ${link.remoteId}');
    });
  }

  static Future<String?> _neverPromptCode() async => null;

  @override
  Future<void> eraseDevice(String remoteId) {
    return _withTagLink(remoteId, _neverPromptCode, (JotaLink link) async {
      if (!link.supportsErase) throw const EraseUnsupported();
      final JotaStatus st = await link.readStatus();

      // Subscribe BEFORE the write, or the confirmation can land with nobody
      // listening — the same rule as `data` before `fetch`.
      final Completer<void> done = Completer<void>();
      final StreamSubscription<JotaStatus> sub = link.statusStream.listen(
        (JotaStatus s) {
          if (s.error == 'erased' && !done.isCompleted) done.complete();
        },
        // The stream closing means the link died; if that happens after the
        // write, the device may well have wiped and rebooted its radio state.
        // Treat it as confirmation rather than leaving the phone claiming a
        // bond the device no longer remembers.
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      try {
        await link.writeErase(st.device);
        // The wipe is file I/O over every note; give it room.
        await done.future.timeout(const Duration(seconds: 15));
        _log('erase', 'device wiped and confirmed');
      } on TimeoutException {
        throw const JotaLinkException('the Jota did not confirm the erase');
      } finally {
        await sub.cancel();
      }
    });
  }

  Future<T> _withTagLink<T>(
    String remoteId,
    PairCodeRequest onPairCodeNeeded,
    Future<T> Function(JotaLink link) body,
  ) async {
    if (_running) {
      throw const SyncException('a sync is using the connection');
    }

    final Completer<T> result = Completer<T>();

    _tagOp = _tagOp.then((_) async {
      JotaLink? link;
      try {
        link = await JotaLink.open(
          JotaScanner.deviceFor(remoteId),
          timeout: _tagTimeout,
        );
        await _authenticate(link, onPairCodeNeeded);
        result.complete(await body(link));
      } on EraseUnsupported catch (e, st) {
        // Typed on purpose: the UI answers it with the two-button fallback,
        // which is a different sentence from any failure.
        result.completeError(e, st);
      } on Object catch (e, st) {
        result.completeError(SyncException(_humanise(e)), st);
      } finally {
        await link?.close();
      }
    });

    return result.future;
  }

  /// Read the tag list off the device. Separate from a sync run so the tag editor
  /// can show what the device holds without pulling notes.
  @override
  Future<List<String>> readTags(
    String remoteId, {
    required PairCodeRequest onPairCodeNeeded,
  }) {
    return _withTagLink(
      remoteId,
      onPairCodeNeeded,
      (JotaLink link) => link.readTags(),
    );
  }

  @override
  Future<void> writeTags(
    String remoteId,
    List<String> tags, {
    required PairCodeRequest onPairCodeNeeded,
  }) {
    return _withTagLink(remoteId, onPairCodeNeeded, (JotaLink link) async {
      await link.setClock();
      await link.writeTags(tags);
    });
  }

  @override
  Future<void> dispose() async {
    await _progress.close();
  }

  static String _humanise(Object e) {
    if (e is JotaLinkException) return e.message;
    if (e is FlutterBluePlusException) {
      return e.description ?? 'bluetooth error ${e.code}';
    }
    if (e is TimeoutException) return 'timed out';
    return e.toString();
  }
}

/// Convenience for tests: reassemble chunks the way the engine does, so the
/// reassembly rule ("by order, trust only the CRC") can be exercised without a
/// radio or a filesystem.
Uint8List reassemble(List<List<int>> chunks, {int? limit}) {
  final BytesBuilder b = BytesBuilder(copy: false);
  for (final List<int> c in chunks) {
    if (limit != null && b.length + c.length > limit) {
      b.add(c.sublist(0, limit - b.length));
      break;
    }
    b.add(c);
  }
  return b.toBytes();
}
