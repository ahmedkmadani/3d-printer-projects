// ============================================================================
//  Jota — device controller
//
//  Everything about the link: what is in range, what is paired, what a sync is
//  doing right now. Screens read this; nothing else in the app talks to
//  flutter_blue_plus directly.
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/background_sync.dart';
import '../ble/jota_protocol.dart';
import '../ble/jota_scanner.dart';
import '../ble/sync_engine.dart';
import '../data/settings_store.dart';
import 'notes_controller.dart';

class DeviceController extends ChangeNotifier {
  DeviceController({
    required JotaScanner scanner,
    required SyncEngine sync,
    required SettingsStore settings,
    required BackgroundSync background,
    required NotesController notes,
  })  : _scanner = scanner,
        _sync = sync,
        _settings = settings,
        _background = background,
        _notes = notes {
    _progressSub = _sync.progress.listen((SyncProgress p) {
      _progress = p;
      notifyListeners();
      if (p.phase == SyncPhase.done) {
        // Notes are on disk; get the text moving without blocking the UI.
        unawaited(_afterSync());
      }
    });

    _adapterSub = JotaScanner.adapterState.listen((BluetoothAdapterState s) {
      _adapter = s;
      notifyListeners();
    });

    _scanSub = _scanner.devices.listen((List<JotaAdvertisement> ads) {
      _inRange = ads;
      notifyListeners();
      unawaited(_maybeAutoSync());
    });
  }

  final JotaScanner _scanner;
  final SyncEngine _sync;
  final SettingsStore _settings;
  final BackgroundSync _background;
  final NotesController _notes;

  StreamSubscription<SyncProgress>? _progressSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<JotaAdvertisement>>? _scanSub;

  // ---- state ---------------------------------------------------------------

  BluetoothAdapterState _adapter = BluetoothAdapterState.unknown;
  BluetoothAdapterState get adapter => _adapter;
  bool get bluetoothReady => _adapter == BluetoothAdapterState.on;

  List<JotaAdvertisement> _inRange = <JotaAdvertisement>[];
  List<JotaAdvertisement> get inRange => _inRange;

  SyncProgress _progress = SyncProgress.idle;
  SyncProgress get progress => _progress;
  bool get isSyncing => _sync.isRunning;

  bool get isScanning => _scanner.isScanning;

  String? get pairedId => _settings.deviceId;
  bool get hasPairedDevice => _settings.hasDevice;

  BackgroundMode get backgroundMode => _background.mode;

  /// The paired device's advertisement, if it is in range right now. This is
  /// the object that answers "how many notes are waiting" WITHOUT connecting.
  JotaAdvertisement? get pairedAdvertisement {
    final String? id = pairedId;
    if (id == null) return null;
    for (final JotaAdvertisement a in _inRange) {
      if (a.remoteId == id) return a;
    }
    return null;
  }

  /// Notes waiting on the device, straight from the advertisement. Null when
  /// the device is not in range — which is different from zero, and the UI
  /// says so.
  int? get pendingOnDevice => pairedAdvertisement?.pending;

  String? _lastError;
  String? get lastError => _lastError;

  /// Set while a sync is blocked waiting for the user to type the code from
  /// the e-paper.
  Completer<String?>? _pairCodeRequest;
  bool get needsPairCode => _pairCodeRequest != null;

  // ---- scanning ------------------------------------------------------------

  Future<void> startScan({Duration? timeout}) async {
    _lastError = null;
    notifyListeners();
    try {
      await _scanner.start(timeout: timeout ?? const Duration(seconds: 15));
    } on Exception catch (e) {
      _lastError = e.toString();
    }
    notifyListeners();
  }

  Future<void> stopScan() async {
    await _scanner.stop();
    notifyListeners();
  }

  // ---- pairing -------------------------------------------------------------

  Future<void> pairWith(JotaAdvertisement ad) async {
    await _settings.setDevice(ad.remoteId, name: ad.name);
    notifyListeners();
    await syncNow();
  }

  Future<void> forgetDevice() async {
    await _settings.setDevice(null);
    notifyListeners();
  }

  /// Called by the pair screen when the user has typed the six digits.
  void submitPairCode(String? code) {
    final Completer<String?>? c = _pairCodeRequest;
    _pairCodeRequest = null;
    notifyListeners();
    if (c != null && !c.isCompleted) c.complete(code);
  }

  Future<String?> _requestPairCode() {
    final Completer<String?> c = Completer<String?>();
    _pairCodeRequest = c;
    notifyListeners();
    return c.future;
  }

  // ---- sync ----------------------------------------------------------------

  /// Sync with the paired device, or with [ad] if given.
  Future<SyncResult?> syncNow({JotaAdvertisement? ad}) async {
    final String? id = ad?.remoteId ?? pairedId;
    if (id == null) {
      _lastError = 'no device paired';
      notifyListeners();
      return null;
    }
    if (_sync.isRunning) return null;

    _lastError = null;
    await _scanner.stop(); // scanning while connecting is slow and pointless
    notifyListeners();

    final SyncResult result = await _sync.run(
      JotaScanner.deviceFor(id),
      onPairCodeNeeded: _requestPairCode,
    );

    if (!result.ok) _lastError = result.error;
    if (result.notesAdded > 0) await _notes.refresh();
    notifyListeners();
    return result;
  }

  /// Opportunistic: the paired device just appeared and says it has notes.
  ///
  /// This is the whole background story in three lines — the advertisement says
  /// there is work, so we connect; if it says zero, we never do.
  Future<void> _maybeAutoSync() async {
    if (_sync.isRunning) return;
    if (!_settings.backgroundSync) return;
    final JotaAdvertisement? ad = pairedAdvertisement;
    if (ad == null || !ad.hasWork) return;

    await _background.report('Pulling ${ad.pending} note(s)');
    await syncNow(ad: ad);
    await _background.report('Listening for notes');
  }

  Future<void> _afterSync() async {
    await _notes.refresh();
    await _notes.drainTranscriptions();
  }

  // ---- tags ----------------------------------------------------------------

  /// Read the device's tag list. Returns null if no device is reachable, so the
  /// editor can fall back to what is stored locally.
  Future<List<String>?> readDeviceTags() async {
    final String? id = pairedId;
    if (id == null) return null;
    try {
      return await _sync.readTags(JotaScanner.deviceFor(id));
    } on Exception catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> writeDeviceTags(List<String> tags) async {
    final String? id = pairedId;
    if (id == null) return false;
    try {
      await _sync.writeTags(JotaScanner.deviceFor(id), tags);
      return true;
    } on Exception catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ---- background ----------------------------------------------------------

  Future<void> setBackgroundSync(bool on) async {
    await _settings.setBackgroundSync(on);
    if (on) {
      await _background.enable();
      // Keep a filtered scan alive so an advertisement can trigger a pull.
      await _scanner.start(timeout: null);
    } else {
      await _background.disable();
      await _scanner.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _adapterSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }
}
