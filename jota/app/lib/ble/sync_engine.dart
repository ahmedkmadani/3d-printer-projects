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

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../audio/adpcm.dart';
import '../audio/crc32.dart';
import '../data/audio_store.dart';
import '../data/note.dart';
import '../data/note_repository.dart';
import '../data/partial_store.dart';
import '../data/settings_store.dart';
import 'jota_link.dart';
import 'jota_protocol.dart';
import 'jota_scanner.dart';
import 'sync_service.dart';

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

      // ---- index --------------------------------------------------------
      _emit(
        const SyncProgress(
          phase: SyncPhase.readingIndex,
          message: 'Reading index',
        ),
      );
      final List<JotaNoteIndexEntry> index = await link.readIndex();

      // Drop partials for notes the device no longer offers — deleted on the
      // device, or acked in a run whose bookkeeping we lost.
      await _partials.retainOnly(
        deviceId,
        index.map((JotaNoteIndexEntry e) => e.id).toSet(),
      );

      // ---- data subscription, ONCE for the session ----------------------
      // Opened before the first `fetch` and kept for every note, so there is no
      // window in which a chunk can arrive unobserved.
      final Stream<List<int>> dataStream = await link.openDataStream();

      final List<int> known = (await _notes.knownIds(deviceId)).toList();

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

        final bool ok = await _transferOne(
          link: link,
          dataStream: dataStream,
          deviceId: deviceId,
          entry: entry,
          notesDone: added,
          notesTotal: index.length,
        );

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

      return SyncResult(notesAdded: added, notesRemaining: remaining);
    } on Exception catch (e) {
      // A failure here is routine, not exceptional: the user walked out of range.
      // Everything downloaded so far is on disk and the device still lists the
      // note, so the next connection continues.
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
      recordedAt: entry.time,
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

    final StreamSubscription<List<int>> dataSub = dataStream.listen(
      (List<int> chunk) async {
        if (done.isCompleted || chunk.isEmpty) return;
        resetStall();

        // "Do not assume chunk boundaries mean anything — reassemble by order,
        // and trust only the CRC." So: append in arrival order, never inspect.
        // Clip a final chunk that overshoots the declared length rather than
        // writing bytes that are not part of the note.
        final int room = entry.bytes - received;
        final List<int> use =
            chunk.length > room ? chunk.sublist(0, room) : chunk;

        await _partials.append(deviceId, entry.id, use);
        received += use.length;

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
    } finally {
      stall?.cancel();
      await dataSub.cancel();
      await statusSub.cancel();
    }

    if (failure != null) {
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
      return false; // incomplete; try again next connection
    }

    // Streamed by the store rather than read whole: a long note is several MB
    // and there is no reason to hold it in memory just to checksum it.
    final int crc = await _partials.crc32Of(deviceId, entry.id);

    if (!Crc32.matches(crc, entry.crc)) {
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
