// ============================================================================
//  Jota — the real DeviceScanner, over flutter_blue_plus
//
//  Filtering by service UUID is not an optimisation here, it is a requirement:
//  iOS only delivers scan results to a backgrounded app for scans that name an
//  explicit service UUID.
// ============================================================================
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'device_scanner.dart';
import 'jota_protocol.dart';

class JotaScanner implements DeviceScanner {
  JotaScanner() {
    _adapterSub = FlutterBluePlus.adapterState.listen((
      BluetoothAdapterState s,
    ) {
      _adapterNow = _map(s);
      if (!_adapterStatus.isClosed) _adapterStatus.add(_adapterNow);
    });
  }

  final StreamController<List<JotaAdvertisement>> _found =
      StreamController<List<JotaAdvertisement>>.broadcast();
  final StreamController<AdapterStatus> _adapterStatus =
      StreamController<AdapterStatus>.broadcast();

  StreamSubscription<List<ScanResult>>? _sub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  AdapterStatus _adapterNow = AdapterStatus.unavailable;

  @override
  Stream<List<JotaAdvertisement>> get devices => _found.stream;

  @override
  Stream<AdapterStatus> get adapterState => _adapterStatus.stream;

  @override
  AdapterStatus get adapterNow => _adapterNow;

  @override
  bool get isScanning => FlutterBluePlus.isScanningNow;

  static AdapterStatus _map(BluetoothAdapterState s) {
    switch (s) {
      case BluetoothAdapterState.on:
        return AdapterStatus.on;
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
      case BluetoothAdapterState.turningOn:
        return AdapterStatus.off;
      case BluetoothAdapterState.unauthorized:
        return AdapterStatus.unauthorized;
      case BluetoothAdapterState.unavailable:
      case BluetoothAdapterState.unknown:
        return AdapterStatus.unavailable;
    }
  }

  static Future<bool> get isSupported => FlutterBluePlus.isSupported;

  /// Ask iOS to hand the app back its central manager after the system has
  /// killed and relaunched it — `CBCentralManagerOptionRestoreIdentifierKey`.
  ///
  /// Must be called before ANY other flutter_blue_plus call, which is why
  /// Services.boot() does it first. No effect on Android.
  static Future<void> configureForBackground() async {
    if (Platform.isIOS) {
      // showPowerAlert lets iOS raise its own "Turn On Bluetooth" system alert
      // when we try to use the radio while it is off — the closest iOS allows to
      // enabling it from the app.
      await FlutterBluePlus.setOptions(restoreState: true, showPowerAlert: true);
    }
  }

  @override
  Future<bool> turnOn() async {
    // Only Android permits an app to turn the radio on (via a system dialog).
    if (!Platform.isAndroid) return false;
    try {
      await FlutterBluePlus.turnOn();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// [continuousUpdates] keeps re-reporting a device that stays in range so
  /// `pending` stays fresh — without it, the count is whatever it was in the
  /// first advertisement seen and never changes.
  @override
  Future<void> start({
    Duration? timeout = const Duration(seconds: 15),
    bool continuousUpdates = true,
  }) async {
    await stop();

    _sub = FlutterBluePlus.onScanResults.listen((List<ScanResult> results) {
      final List<JotaAdvertisement> ads = <JotaAdvertisement>[];
      for (final ScanResult r in results) {
        final JotaAdvertisement? ad = JotaAdvertisement.from(r);
        if (ad != null) {
          ads.add(ad);
        } else if (r.advertisementData.advName == kJotaLocalName) {
          // A Jota whose manufacturer data we could not parse is still a Jota.
          // Report it with pending unknown rather than hiding it, so the user
          // can at least connect by hand.
          ads.add(
            JotaAdvertisement(
              remoteId: r.device.remoteId.str,
              name: kJotaLocalName,
              pending: 0,
              paired: false,
              rssi: r.rssi,
            ),
          );
        }
      }
      ads.sort(
        (JotaAdvertisement a, JotaAdvertisement b) => b.rssi.compareTo(a.rssi),
      );
      if (!_found.isClosed) _found.add(ads);
    });

    await FlutterBluePlus.startScan(
      withServices: <Guid>[JotaUuid.service],
      timeout: timeout,
      continuousUpdates: continuousUpdates,
      // Report a device as gone if it has not advertised for a while, so the
      // list does not accumulate ghosts.
      removeIfGone: continuousUpdates ? const Duration(seconds: 20) : null,
      androidScanMode: AndroidScanMode.balanced,
    );
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  /// Wait for a specific Jota to show up, or give up.
  ///
  /// [requireWork] is the battery rule: only resolve for a device that says it
  /// actually has notes waiting, so a Jota sitting empty on a desk never causes
  /// a connection.
  Future<JotaAdvertisement?> waitFor({
    String? remoteId,
    bool requireWork = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final Completer<JotaAdvertisement?> c = Completer<JotaAdvertisement?>();
    late final StreamSubscription<List<JotaAdvertisement>> sub;

    sub = devices.listen((List<JotaAdvertisement> ads) {
      for (final JotaAdvertisement ad in ads) {
        if (remoteId != null && ad.remoteId != remoteId) continue;
        if (requireWork && !ad.hasWork) continue;
        if (!c.isCompleted) c.complete(ad);
        return;
      }
    });

    final Timer t = Timer(timeout, () {
      if (!c.isCompleted) c.complete(null);
    });

    try {
      await start(timeout: timeout);
      return await c.future;
    } finally {
      t.cancel();
      await sub.cancel();
      await stop();
    }
  }

  /// A handle to a device we already know the id of — no scan required. This is
  /// how the app reconnects to the paired Jota.
  static BluetoothDevice deviceFor(String remoteId) =>
      BluetoothDevice.fromId(remoteId);

  @override
  Future<void> dispose() async {
    await stop();
    await _adapterSub?.cancel();
    await _found.close();
    await _adapterStatus.close();
  }
}
