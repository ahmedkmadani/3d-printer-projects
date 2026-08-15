// ============================================================================
//  Jota — device controller
//
//  Everything about the link: what is in range, what is paired, what a sync is
//  doing right now. Screens read this; nothing else in the app talks to a
//  scanner or a sync engine directly.
//
//  Depends only on the interfaces in lib/ble/, so the same controller drives the
//  real radio and the simulated device used by the web preview.
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble/background_sync.dart';
import '../ble/device_scanner.dart';
import '../ble/jota_protocol.dart';
import '../ble/sync_service.dart';
import '../data/settings_store.dart';
import 'notes_controller.dart';

class DeviceController extends ChangeNotifier {
  DeviceController({
    required DeviceScanner scanner,
    required SyncService sync,
    required SettingsStore settings,
    required BackgroundSyncController background,
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

    _adapter = _scanner.adapterNow;
    _adapterSub = _scanner.adapterState.listen((AdapterStatus s) {
      _adapter = s;
      notifyListeners();
    });

    _scanSub = _scanner.devices.listen((List<JotaAdvertisement> ads) {
      _inRange = ads;
      // Remember the last real reading, so a device that walks out of range
      // leaves its charge behind rather than blanking it.
      final int? seen = pairedAdvertisement?.battery;
      if (seen != null) _lastBattery = seen;
      notifyListeners();
      unawaited(_maybeAutoSync());
    });
  }

  final DeviceScanner _scanner;
  final SyncService _sync;
  final SettingsStore _settings;
  final BackgroundSyncController _background;
  final NotesController _notes;

  StreamSubscription<SyncProgress>? _progressSub;
  StreamSubscription<AdapterStatus>? _adapterSub;
  StreamSubscription<List<JotaAdvertisement>>? _scanSub;

  // ---- state ---------------------------------------------------------------

  AdapterStatus _adapter = AdapterStatus.unavailable;
  AdapterStatus get adapter => _adapter;
  bool get bluetoothReady => _adapter.isReady;

  /// Ask the OS to turn Bluetooth on. Android shows a system dialog and this
  /// resolves true once it comes on; iOS cannot enable the radio from an app, so
  /// it returns false and the UI nudges the system prompt / guides the user.
  Future<bool> turnOnBluetooth() => _scanner.turnOn();

  List<JotaAdvertisement> _inRange = <JotaAdvertisement>[];
  List<JotaAdvertisement> get inRange => _inRange;

  SyncProgress _progress = SyncProgress.idle;
  SyncProgress get progress => _progress;
  bool get isSyncing => _sync.isRunning;

  bool get isScanning => _scanner.isScanning;

  String? get pairedId => _settings.deviceId;
  bool get hasPairedDevice => _settings.hasDevice;

  BackgroundMode get backgroundMode => _background.mode;

  /// Whether the scan belongs to background sync rather than to whatever screen
  /// happens to be open — a screen must not stop a scan it does not own.
  bool get wantsBackgroundScan => _settings.backgroundSync;

  /// The paired device's advertisement, if it is in range right now. This is the
  /// object that answers "how many notes are waiting" WITHOUT connecting.
  JotaAdvertisement? get pairedAdvertisement {
    final String? id = pairedId;
    if (id == null) return null;
    for (final JotaAdvertisement a in _inRange) {
      if (a.remoteId == id) return a;
    }
    return null;
  }

  /// Notes waiting on the device, straight from the advertisement. Null when the
  /// device is not in range — which is different from zero, and the UI says so.
  int? get pendingOnDevice => pairedAdvertisement?.pending;

  /// Charge on the paired device, 0..100.
  ///
  /// Null covers three different things that all mean "do not show a figure":
  /// out of range, no sense pin wired on that board, or firmware that predates
  /// the field. None of them is 0%, and showing 0% for any of them would send
  /// someone looking for a charger.
  ///
  /// Comes from the advertisement, so it is current WITHOUT connecting; the
  /// last connected reading stands in while the device is away.
  int? get batteryOnDevice => pairedAdvertisement?.battery ?? _lastBattery;

  int? _lastBattery;

  String? _lastError;
  String? get lastError => _lastError;

  /// Set while a sync is blocked waiting for the user to type the code from the
  /// e-paper.
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
    // Store the id-bearing name, not the bare local name: every Jota advertises
    // as "JOTA", so remembering that tells you nothing later. `JOTA-91C4` is the
    // same four characters the device prints on its own screen.
    await _settings.setDevice(ad.remoteId, name: ad.shortName);
    notifyListeners();
    _autoSyncBlocked = false;
    await syncNow();
  }

  /// What to call the paired device in the UI. Prefers what it is broadcasting
  /// right now, so a device that has been re-flashed still reads correctly.
  String get pairedName =>
      pairedAdvertisement?.shortName ?? _settings.deviceName ?? kJotaLocalName;

  /// This phone's own id, shown in Settings so two people can see which phone a
  /// Jota belongs to.
  String get appId => _settings.appId;

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
  ///
  /// [interactive] is what separates "the user pressed Save" from "the device
  /// wandered into range". Only a deliberate sync may stop and ask for the six
  /// digits: the prompt is surfaced by the Sync screen, so an automatic run that
  /// asked while the user was reading their notes would block on a dialog
  /// nobody could see.
  Future<SyncResult?> syncNow({
    JotaAdvertisement? ad,
    bool interactive = true,
  }) async {
    final String? id = ad?.remoteId ?? pairedId;
    if (id == null) {
      _lastError = 'no device paired';
      notifyListeners();
      return null;
    }
    if (_sync.isRunning) return null;

    _lastError = null;
    // Scanning while connecting is slow and pointless — but it has to come
    // BACK afterwards, or the screen that was watching for this device goes
    // dark the moment it succeeds and reports it as out of range.
    final bool wasScanning = _scanner.isScanning;
    await _scanner.stop();
    notifyListeners();

    final SyncResult result = await _sync.run(
      id,
      onPairCodeNeeded: interactive ? _requestPairCode : _neverPrompt,
    );

    // App-first tags: the phone owns the tag list, so push it to the device on
    // every successful sync (covers tags added while it was out of range).
    if (result.ok) {
      try {
        await _sync.writeTags(
          id,
          _settings.tags,
          onPairCodeNeeded: _neverPrompt,
        );
      } on Exception catch (_) {
        // Non-fatal: tags will try again next sync.
      }
    }

    if (!result.ok) _lastError = result.error;
    if (result.notesAdded > 0) await _notes.refresh();
    if (wasScanning) await _scanner.start(timeout: null);
    notifyListeners();
    return result;
  }

  /// Opportunistic: the paired device just appeared and says it has notes.
  ///
  /// This is the whole story in a few lines — the advertisement says there is
  /// work, so we connect; if it says zero, we never do.
  ///
  /// Being in range IS the trigger. It used to require the background-sync
  /// setting even while the app was open and the user was watching the Sync
  /// screen, so a Jota sitting on the desk with three notes on it would be
  /// found, listed, counted — and then wait to be told to sync. Coming into
  /// range is the entire signal a person expects to be enough.
  Future<void> _maybeAutoSync() async {
    if (_sync.isRunning) return;
    final JotaAdvertisement? ad = pairedAdvertisement;
    if (ad == null || !ad.hasWork) return;

    // Don't re-attempt a device that just failed on us — a bad code or a
    // device out of reach would otherwise retry on every advertisement, a few
    // seconds apart, forever.
    if (_autoSyncBlocked) return;

    final bool background = !_foreground;
    if (background && !_settings.backgroundSync) return;

    if (background) await _background.report('Pulling ${ad.pending} note(s)');
    final SyncResult? r = await syncNow(ad: ad, interactive: false);
    if (background) await _background.report('Listening for notes');

    // One failure parks the automatic path until something changes: the user
    // taps sync, or the app comes back to the foreground.
    if (r != null && !r.ok) _autoSyncBlocked = true;
  }

  /// True while the app is on screen. Set by the shell.
  bool _foreground = true;
  bool _autoSyncBlocked = false;

  /// Called when the Sync surface is shown or the app resumes: try again, and
  /// keep watching rather than giving up after one scan window.
  void resumeAutoSync({bool foreground = true}) {
    _foreground = foreground;
    _autoSyncBlocked = false;
    unawaited(_maybeAutoSync());
  }

  Future<void> _afterSync() async {
    await _notes.refresh();
    await _notes.drainTranscriptions();
  }

  // ---- tags ----------------------------------------------------------------

  /// Tag work never interrupts anyone for a pair code.
  ///
  /// Opening the Tags tab is not a request to pair, and a phone that is not the
  /// device's owner must not be answered with a modal asking for six digits off
  /// a device that may be in a drawer. Returning null cancels the handshake, the
  /// operation gives up, and the phone's own list — which is the authority
  /// anyway — carries on unaffected.
  static Future<String?> _neverPrompt() async => null;

  /// Read the device's tag list. Null if no device is reachable, so the editor can
  /// fall back to what is stored locally.
  Future<List<String>?> readDeviceTags() async {
    final String? id = pairedId;
    if (id == null || _sync.isRunning) return null;
    try {
      return await _sync.readTags(id, onPairCodeNeeded: _neverPrompt);
    } on Exception catch (e) {
      _lastError = e is SyncException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Push the phone's list to the device. False means it did not land — the list
  /// is still saved locally, and the next sync pushes it again.
  Future<bool> writeDeviceTags(List<String> tags) async {
    final String? id = pairedId;
    if (id == null) return false;
    // A sync already ends by pushing the tags, so there is nothing to gain by
    // fighting it for the radio — and a great deal to lose: a second connection
    // to the same device tears down the one the transfer is using.
    if (_sync.isRunning) return false;
    try {
      await _sync.writeTags(id, tags, onPairCodeNeeded: _neverPrompt);
      return true;
    } on Exception catch (e) {
      _lastError = e is SyncException ? e.message : e.toString();
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

  bool _disposed = false;

  /// Nearly everything here finishes after an `await` on a radio. Any of those
  /// can land after the controller is gone — a screen closing mid-scan is the
  /// ordinary case, not an edge one — and notifying a disposed ChangeNotifier
  /// throws. Swallow it in one place rather than guarding a dozen call sites.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _progressSub?.cancel();
    _adapterSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }
}
