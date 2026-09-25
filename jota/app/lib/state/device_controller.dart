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
import '../ble/device_diag.dart';
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
      // Pairing is DONE the moment the handshake is behind us — the bond is
      // stored on the device from that instant. Waiting for the whole first
      // sync meant sitting on the pairing screen through every note transfer,
      // which on a first pairing is the longest sync there will ever be, with
      // nothing on screen explaining the wait. The transfer carries on; Home
      // is where it belongs, because Home has the progress chip.
      if (_pairing &&
          p.phase != SyncPhase.connecting &&
          p.phase != SyncPhase.authenticating &&
          p.phase != SyncPhase.idle &&
          p.phase != SyncPhase.failed) {
        _pairing = false;
      }
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

  /// True from the instant a sync is asked for until the engine owns it.
  /// See syncNow for why `_sync.isRunning` alone leaves a race open.
  bool _syncStarting = false;

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

  /// Fires with the count each time a sync brings notes over, whichever
  /// path started it. The shell turns it into one line on screen; before
  /// this an automatic sync landed notes with no account of it, now that
  /// the SYNC word is gone from the archive's corner.
  final StreamController<int> _syncedNotes = StreamController<int>.broadcast();
  Stream<int> get syncedNotes => _syncedNotes.stream;

  /// Set while a sync is blocked waiting for the user to type the code from the
  /// e-paper.
  Completer<String?>? _pairCodeRequest;
  bool get needsPairCode => _pairCodeRequest != null;

  // ---- scanning ------------------------------------------------------------

  /// Android quietly downgrades a BLE scan that has run for about half an
  /// hour, and a downgraded scan delivers nothing: the paired Jota then
  /// reads as ASLEEP while it sits there advertising a pending note. This
  /// has now bitten three different features. So an open-ended scan is
  /// restarted on a timer, well inside the downgrade window, for as long
  /// as one is wanted.
  static const Duration _scanFreshEvery = Duration(minutes: 8);
  Timer? _scanRefresh;

  Future<void> startScan({Duration? timeout}) async {
    _lastError = null;
    notifyListeners();
    final bool openEnded = timeout == null;
    _scanRefresh?.cancel();
    if (openEnded) {
      _scanRefresh = Timer.periodic(_scanFreshEvery, (_) async {
        if (_disposed) return;
        try {
          await _scanner.stop();
          await _scanner.start(timeout: null);
        } on Exception {
          // The next tick tries again; a scan that cannot start now is
          // usually the radio mid-toggle.
        }
      });
    }
    try {
      await _scanner.start(timeout: timeout ?? const Duration(seconds: 15));
    } on Exception catch (e) {
      _lastError = e.toString();
    }
    notifyListeners();
  }

  Future<void> stopScan() async {
    _scanRefresh?.cancel();
    _scanRefresh = null;
    await _scanner.stop();
    notifyListeners();
  }

  // ---- pairing -------------------------------------------------------------

  /// True from the moment a pairing is attempted until it has settled.
  ///
  /// Connect needs this because `hasPairedDevice` goes true the instant an id
  /// is WRITTEN DOWN, which happens before a single byte has been exchanged.
  /// Treating that as "paired" made the Connect screen replace itself with
  /// Home while the handshake was still running, so the code prompt arrived
  /// with nowhere to appear.
  bool get isPairing => _pairing;
  bool _pairing = false;

  /// Returns true only when the bond was actually made.
  Future<bool> pairWith(JotaAdvertisement ad) async {
    _pairing = true;
    // Store the id-bearing name, not the bare local name: every Jota advertises
    // as "JOTA", so remembering that tells you nothing later. `JOTA-91C4` is the
    // same four characters the device prints on its own screen.
    await _settings.setDevice(ad.remoteId, name: ad.shortName);
    notifyListeners();
    _autoSyncBlocked = false;
    try {
      final SyncResult? r = await syncNow();
      // The handshake is what "paired" means. Notes may still have failed to
      // move — that is a transfer problem, not a pairing one, and it must not
      // undo a bond the device has already stored.
      final bool bonded = r != null && r.ok;
      if (!bonded) {
        // Never leave a device recorded as paired when the bond was never
        // made. Otherwise a wrong code leaves the app claiming a Jota it
        // cannot talk to, and every screen afterwards lies about it.
        await _settings.setDevice(null);
      }
      return bonded;
    } finally {
      _pairing = false;
      notifyListeners();
    }
  }

  /// What to call the paired device in the UI. Prefers what it is broadcasting
  /// right now, so a device that has been re-flashed still reads correctly.
  String get pairedName =>
      pairedAdvertisement?.shortName ?? _settings.deviceName ?? kJotaLocalName;

  /// This phone's own id, shown in Settings so two people can see which phone a
  /// Jota belongs to.
  String get appId => _settings.appId;

  /// What the device said about itself on the last authenticated connection,
  /// or null when it never has — old firmware, or not connected yet.
  DeviceDiag? get deviceDiag => _sync.lastDiag;

  /// Erase the paired Jota over BLE: every note on it, its tags, the bond.
  ///
  /// Throws what the engine throws — [EraseUnsupported] on old firmware,
  /// [SyncException] when the device is unreachable. On success the device
  /// has already forgotten this phone, so the local record is cleared too.
  /// Wait for the paired Jota to advertise, then erase it. The wait is the
  /// point: a Jota sleeps two minutes after a wake, so "erase" and "the
  /// device is awake" almost never coincide unless the app does the
  /// waiting. Restarts the scan first — Android quietly downgrades a scan
  /// that has run for half an hour, and a dead scan looks exactly like an
  /// absent device.
  Future<bool> eraseWhenSeen({
    Duration timeout = const Duration(seconds: 90),
  }) async {
    await _scanner.stop();
    await _scanner.start(timeout: null);
    // waitFor lives on the concrete scanner, not the interface; do the
    // small wait here so the fakes need nothing new.
    final String? id = pairedId;
    JotaAdvertisement? seen;
    final Stopwatch clock = Stopwatch()..start();
    while (clock.elapsed < timeout) {
      for (final JotaAdvertisement ad in inRange) {
        if (id == null || ad.remoteId == id) {
          seen = ad;
          break;
        }
      }
      if (seen != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (seen == null) return false;
    await eraseDevice();
    return true;
  }

  Future<void> eraseDevice() async {
    final String? id = pairedId;
    if (id == null) return;
    await _sync.eraseDevice(id);
    await _settings.setDevice(null);
    _lastError = null;
    notifyListeners();
  }

  /// Forget the paired Jota.
  ///
  /// By default this needs the device in range, because forgetting has to mean
  /// the same thing on both sides. This used to clear only the phone's own
  /// record — and since the app id minted at install never changes, the very
  /// next connection matched the stored owner and authenticated silently. A
  /// person who unpaired in order to hand the Jota on had changed nothing.
  ///
  /// [force] is the way out when the device is lost, flat, broken or already
  /// given away. It clears this side only and returns false, so the caller can
  /// say plainly what is left behind: that Jota keeps trusting this phone until
  /// it is erased on the device itself.
  ///
  /// Returns true when both sides were cleared.
  Future<bool> forgetDevice({bool force = false}) async {
    final String? id = pairedId;
    if (id == null) return true;

    bool onDevice = false;
    try {
      await _sync.forgetOnDevice(id);
      onDevice = true;
    } on Exception catch (e) {
      if (!force) {
        _lastError = e is SyncException ? e.message : e.toString();
        notifyListeners();
        rethrow;
      }
    }

    await _settings.setDevice(null);
    _lastError = null;
    notifyListeners();
    return onDevice;
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
    // `_sync.isRunning` is not enough on its own. Between this check and the
    // `_sync.run()` below there is an `await` — stopping the scanner — and an
    // advertisement arriving inside that window lets _maybeAutoSync pass the
    // very same check and start a SECOND run. Two runs means two connects to
    // one device, and flutter_blue_plus answers a second connection by tearing
    // the whole link down ("unexpected connection, disconnecting now").
    //
    // On real hardware that looked like a device that read its index and then
    // hung up without fetching anything — with nothing in either log saying
    // why. A synchronous flag closes the window the await opens.
    if (_sync.isRunning || _syncStarting) {
      return null;
    }
    _syncStarting = true;

    _lastError = null;
    // Scanning while connecting is slow and pointless — but it has to come
    // BACK afterwards, or the screen that was watching for this device goes
    // dark the moment it succeeds and reports it as out of range.
    final bool wasScanning = _scanner.isScanning;
    final SyncResult result;
    try {
      await _scanner.stop();
      notifyListeners();
      result = await _sync.run(
        id,
        onPairCodeNeeded: interactive ? _requestPairCode : _neverPrompt,
      );
    } finally {
      // Held for the WHOLE attempt and released in a finally: cleared any
      // earlier and the window reopens; not cleared on a throw and every
      // later sync is blocked by a run that already died.
      _syncStarting = false;
    }

    // Tags are NOT pushed here any more. This ran only when result.ok, and it
    // opened a SECOND connection to do it — so while transfers were failing
    // the device never received the list at all, and when they succeeded it
    // paid for another connect. The push now happens inside the sync itself,
    // on the connection that is already open and already authenticated.
    //
    // It also sent the whole list, without the kDeviceTagSlots cap that the
    // manual path applies, leaving the two routes disagreeing about what the
    // device should hold.

    if (!result.ok) _lastError = result.error;
    if (result.notesAdded > 0) {
      await _notes.refresh();
      if (!_disposed) _syncedNotes.add(result.notesAdded);
    }
    // Put the scan back whenever the app is on screen, not only when one
    // happened to be running. A sync stops the scan, and if the scan had
    // already timed out by then nothing ever restarted it — so the app went
    // permanently blind to a device it had JUST finished talking to, and the
    // chip settled on NOT IN RANGE.
    if (wasScanning || _foreground) await _scanner.start(timeout: null);
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
    if (_sync.isRunning || _syncStarting) return;
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
    //
    // "A sync that moved nothing" counts as a failure here, even though it
    // raised no exception. A run where every transfer fails ends with ok=true
    // and notesRemaining=3 — so this guard never engaged, and the app
    // reconnected on every advertisement, a few seconds apart, for ever. Each
    // attempt then held the radio for the better part of a minute, which is
    // what made the app feel slow AND kept the device connected, so it stopped
    // advertising and the chip flipped to NOT IN RANGE while the panel still
    // said LINKED.
    final bool movedNothing =
        r != null && r.notesAdded == 0 && r.notesRemaining > 0;
    if (r != null && (!r.ok || movedNothing)) _autoSyncBlocked = true;
  }

  /// True while the app is on screen. Set by the shell.
  bool _foreground = true;
  bool _autoSyncBlocked = false;

  /// Called when the Sync surface is shown or the app resumes: try again, and
  /// keep watching rather than giving up after one scan window.
  void resumeAutoSync({bool foreground = true}) {
    _foreground = foreground;
    _autoSyncBlocked = false;
    if (!foreground) {
      // A continuous scan is the right thing while someone is looking at the
      // app and the wrong thing in their pocket. Backgrounded, the device
      // wakes us by advertising instead — see the app README on why a timer
      // does not work on either phone OS.
      unawaited(_scanner.stop());
      return;
    }
    unawaited(startScan(timeout: null));
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
      // Only the top few travel. The device offers them one button-press at a
      // time on a panel that takes two seconds to redraw, so the list it holds
      // is deliberately shorter than the list the app holds — see
      // kDeviceTagSlots.
      await _sync.writeTags(
        id,
        tags.take(kDeviceTagSlots).toList(),
        onPairCodeNeeded: _neverPrompt,
      );
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
    _scanRefresh?.cancel();
    _progressSub?.cancel();
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _syncedNotes.close();
    super.dispose();
  }
}
