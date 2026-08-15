// ============================================================================
//  Jota — a simulated device for the web preview
//
//  A scanner that advertises, and a sync service that walks the real sequence —
//  connect, auth, clock, index, fetch, verify, ack — on a timer instead of a
//  radio. It emits the same SyncProgress objects the real engine does, so the
//  SYNC screen's ratio, progress bar, per-note byte counter and RESUMED flag are
//  all driven by the code that ships.
//
//  What it does NOT do is any of the things that can actually go wrong: no GATT,
//  no MTU, no chunk reassembly, no CRC over bytes that came off a wire. See the
//  README for the full list.
// ============================================================================
import 'dart:async';
import 'dart:typed_data';

import '../audio/crc32.dart';
import '../ble/background_sync.dart';
import '../ble/device_scanner.dart';
import '../ble/jota_protocol.dart';
import '../ble/sync_service.dart';
import '../data/note.dart';
import '../data/note_repository.dart';
import '../data/settings_store.dart';
import 'in_memory_stores.dart';
import 'seed_data.dart';

/// The device's own state, shared between the scanner and the sync service the
/// way a real device's state is shared by its advertisement and its GATT server.
class FakeJota {
  FakeJota({
    List<PendingNote> pending = kPendingOnDevice,
    this.pairCode = kPreviewPairCode,
  }) : pending = List<PendingNote>.of(pending);

  final List<PendingNote> pending;
  final String pairCode;

  bool paired = false;

  /// This fake device's own id, and the uuid of the phone that owns it.
  ///
  /// The owner is what makes "pair once" real: a phone presenting a matching
  /// uuid is let in with no code. Modelled here so the preview and the tests
  /// walk the same handshake the firmware implements, rather than a shortcut
  /// that would hide a broken one.
  final String deviceId = kPreviewDeviceIdHex;
  String? ownerAppId;

  /// Charge, or null to simulate a board with no battery sense wired — which
  /// is what the firmware reports until the ADC pin is known.
  int? battery = 62;

  bool get owned => ownerAppId != null;

  /// What a Jota holds before a phone has ever written to it — the same three
  /// the firmware seeds in `tagsSetDefaults`.
  List<String> tags = List<String>.of(kDefaultTags);

  int get pendingCount => pending.length;

  JotaAdvertisement get advertisement => JotaAdvertisement(
        remoteId: kPreviewDeviceId,
        name: kJotaLocalName,
        pending: pendingCount,
        paired: paired,
        owned: owned,
        deviceId: int.parse(
          deviceId.substring(deviceId.length - 4),
          radix: 16,
        ),
        battery: battery,
        // A plausible in-the-same-room signal, drifting a little so the SYNC
        // screen's dBm readout is not suspiciously static.
        rssi: -52 - (DateTime.now().second % 7),
      );
}

// ---- scanner ---------------------------------------------------------------

class FakeScanner implements DeviceScanner {
  FakeScanner(this._device);

  final FakeJota _device;

  final StreamController<List<JotaAdvertisement>> _found =
      StreamController<List<JotaAdvertisement>>.broadcast();
  final StreamController<AdapterStatus> _adapter =
      StreamController<AdapterStatus>.broadcast();

  Timer? _ticker;
  Timer? _firstAdvert;
  Timer? _timeout;
  bool _scanning = false;

  @override
  Stream<List<JotaAdvertisement>> get devices => _found.stream;

  @override
  Stream<AdapterStatus> get adapterState => _adapter.stream;

  @override
  AdapterStatus get adapterNow => AdapterStatus.on;

  @override
  bool get isScanning => _scanning;

  @override
  Future<void> start({Duration? timeout}) async {
    await stop();
    _scanning = true;

    // A real advertisement takes a moment to arrive; showing the device
    // instantly would make the empty state impossible to see.
    //
    // All three timers are held and cancelled in stop(). A fake that leaks a
    // pending timer fails every widget test that touches it, which is a good
    // reason to be as tidy here as the real scanner has to be.
    _firstAdvert = Timer(const Duration(milliseconds: 700), _emit);
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) => _emit());
    if (timeout != null) {
      _timeout = Timer(timeout, stop);
    }
  }

  void _emit() {
    if (!_scanning || _found.isClosed) return;
    _found.add(<JotaAdvertisement>[_device.advertisement]);
  }

  @override
  Future<void> stop() async {
    _ticker?.cancel();
    _firstAdvert?.cancel();
    _timeout?.cancel();
    _ticker = null;
    _firstAdvert = null;
    _timeout = null;
    _scanning = false;
  }

  @override
  Future<bool> turnOn() async => true; // preview Bluetooth is always "on"

  @override
  Future<void> dispose() async {
    await stop();
    await _found.close();
    await _adapter.close();
  }
}

// ---- sync ------------------------------------------------------------------

class FakeSyncService implements SyncService {
  FakeSyncService({
    required FakeJota device,
    required NoteRepository notes,
    required InMemoryAudioStore audio,
    required SettingsStore settings,
  })  : _device = device,
        _notes = notes,
        _audio = audio,
        _settings = settings;

  final FakeJota _device;
  final NoteRepository _notes;
  final InMemoryAudioStore _audio;
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

  void _emit(SyncProgress p) {
    _last = p;
    if (!_progress.isClosed) _progress.add(p);
  }

  static Future<void> _beat([int ms = 420]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// The bonding handshake, modelled the way the firmware implements it.
  /// Returns null on success, or the message to show.
  ///
  /// Worth simulating rather than shortcutting: an app that syncs only because
  /// the fake never challenges it is an app that fails the first time it meets
  /// real hardware — which is exactly what happened.
  Future<String?> _authenticate(PairCodeRequest onPairCodeNeeded) async {
    // The owner reconnecting: no code, no prompt, nothing on the e-paper.
    if (_device.ownerAppId == _settings.appId) {
      _device.paired = true;
      return null;
    }

    _emit(
      SyncProgress(
        phase: SyncPhase.authenticating,
        message: _device.owned
            ? 'This Jota is paired to another phone — enter the code it shows'
            : 'Enter the code shown on the device',
      ),
    );
    final String? code = await onPairCodeNeeded();
    if (code == null) return 'pairing cancelled';

    await _beat();
    if (code.replaceAll(RegExp(r'\D'), '') != _device.pairCode) {
      return 'device rejected the pair code';
    }

    // A correct code takes ownership, even from another phone: possession of
    // the device outranks the stored bond.
    _device.ownerAppId = _settings.appId;
    _device.paired = true;
    return null;
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

    int added = 0;

    try {
      _emit(
        const SyncProgress(
          phase: SyncPhase.connecting,
          message: 'Connecting',
        ),
      );
      await _beat(700);

      // ---- auth ---------------------------------------------------------
      // The owner is let straight back in. That is the whole point of the bond,
      // and modelling it here is what keeps the preview honest: an app that
      // only works because the fake never asks would fail on real hardware.
      final String? authError = await _authenticate(onPairCodeNeeded);
      if (authError != null) {
        _emit(SyncProgress(phase: SyncPhase.failed, error: authError));
        return SyncResult(
          notesAdded: 0,
          notesRemaining: _device.pendingCount,
          error: authError,
        );
      }

      _emit(
        const SyncProgress(
          phase: SyncPhase.settingClock,
          message: 'Setting clock',
        ),
      );
      await _beat(300);

      _emit(
        const SyncProgress(
          phase: SyncPhase.readingIndex,
          message: 'Reading index',
        ),
      );
      await _beat(500);

      final List<PendingNote> queue = List<PendingNote>.of(_device.pending);
      final int total = queue.length;

      if (total == 0) {
        _emit(
          const SyncProgress(
            phase: SyncPhase.done,
            message: 'Nothing to sync',
          ),
        );
        return const SyncResult(notesAdded: 0, notesRemaining: 0);
      }

      for (final PendingNote p in queue) {
        final Uint8List adpcm = syntheticAdpcm(p.secs, seed: p.id);
        final int totalBytes = adpcm.length;

        // ---- fetch / data -----------------------------------------------
        // Stepped in chunks so the byte counter and the bar move the way they do
        // on a real transfer (~8 KB of ADPCM per second of audio, arriving in a
        // few hundred bytes at a time).
        const int steps = 14;
        for (int i = 1; i <= steps; i++) {
          _emit(
            SyncProgress(
              phase: SyncPhase.transferring,
              notesDone: added,
              notesTotal: total,
              currentNoteId: p.id,
              bytesReceived: (totalBytes * i / steps).round(),
              bytesExpected: totalBytes,
              message: 'Receiving',
            ),
          );
          await _beat(90);
        }

        // ---- verify ------------------------------------------------------
        _emit(
          SyncProgress(
            phase: SyncPhase.verifying,
            notesDone: added,
            notesTotal: total,
            currentNoteId: p.id,
            bytesReceived: totalBytes,
            bytesExpected: totalBytes,
            message: 'Verifying',
          ),
        );
        await _beat(260);

        // ---- store, then ack ---------------------------------------------
        _audio.put(kPreviewDeviceId, p.id, adpcm);
        final DateTime recorded = DateTime.now().subtract(
          Duration(minutes: p.minutesAgo),
        );
        await _notes.insert(
          Note(
            deviceId: kPreviewDeviceId,
            noteId: p.id,
            recordedAt: recorded,
            secs: p.secs,
            bytes: totalBytes,
            crc: Crc32.toHex(Crc32.compute(adpcm)),
            adpcmPath: _audio.archivePathFor(kPreviewDeviceId, p.id),
            // The tag the device armed when this was recorded, carried up in
            // `index` exactly as the firmware sends it.
            tag: p.tag,
            // Arrives untranscribed, exactly as a real note does — the text
            // catches up afterwards through the queue.
            syncedAt: DateTime.now(),
          ),
        );
        _previewTranscripts[p.id] = p.transcript;

        _device.pending.removeWhere((PendingNote q) => q.id == p.id);
        added++;

        _emit(
          SyncProgress(
            phase: SyncPhase.transferring,
            notesDone: added,
            notesTotal: total,
            currentNoteId: p.id,
            message: 'Stored',
          ),
        );
        await _beat(200);
      }

      _emit(
        SyncProgress(
          phase: SyncPhase.done,
          notesDone: added,
          notesTotal: total,
          message: 'Synced',
        ),
      );
      return SyncResult(notesAdded: added, notesRemaining: 0);
    } finally {
      _running = false;
    }
  }

  @override
  Future<List<String>> readTags(
    String remoteId, {
    required PairCodeRequest onPairCodeNeeded,
  }) async {
    if (_running) throw const SyncException('a sync is using the connection');
    await _beat(600);
    final String? error = await _authenticate(onPairCodeNeeded);
    if (error != null) throw SyncException(error);
    return List<String>.of(_device.tags);
  }

  @override
  Future<void> writeTags(
    String remoteId,
    List<String> tags, {
    required PairCodeRequest onPairCodeNeeded,
  }) async {
    if (_running) throw const SyncException('a sync is using the connection');
    await _beat(600);
    final String? error = await _authenticate(onPairCodeNeeded);
    if (error != null) throw SyncException(error);
    // The device clamps to the contract's ceiling, so the fake must too —
    // otherwise the preview happily shows nine tags that real hardware drops.
    _device.tags = tags
        .take(kMaxTags)
        .map(
          (String t) =>
              t.length > kMaxTagLength ? t.substring(0, kMaxTagLength) : t,
        )
        .toList();
  }

  @override
  Future<void> dispose() async {
    await _progress.close();
  }
}

/// What the simulated Whisper will return for a freshly pulled note, keyed by
/// note id. Populated as notes are "received" so the transcript appears after the
/// sync rather than being suspiciously present already.
final Map<int, String?> _previewTranscripts = <int, String?>{};

String? previewTranscriptFor(int noteId) => _previewTranscripts[noteId];

// ---- background ------------------------------------------------------------

class FakeBackgroundSync implements BackgroundSyncController {
  BackgroundMode _mode = BackgroundMode.off;

  final StreamController<BackgroundMode> _changes =
      StreamController<BackgroundMode>.broadcast();

  @override
  BackgroundMode get mode => _mode;

  @override
  Stream<BackgroundMode> get modeChanges => _changes.stream;

  @override
  void configure() {}

  /// Reports the Android answer, because that is the branch with the most to
  /// look at — a persistent notification and the copy that explains it.
  @override
  Future<BackgroundMode> enable() async =>
      _set(BackgroundMode.foregroundService);

  @override
  Future<BackgroundMode> disable() async => _set(BackgroundMode.off);

  @override
  Future<void> report(String text) async {}

  BackgroundMode _set(BackgroundMode m) {
    _mode = m;
    if (!_changes.isClosed) _changes.add(m);
    return m;
  }

  @override
  Future<void> dispose() async {
    await _changes.close();
  }
}
