// ============================================================================
//  Jota — the real DeviceScanner, over flutter_blue_plus
//
//  Filtering by service UUID is not an optimisation here, it is a requirement:
//  iOS only delivers scan results to a backgrounded app for scans that name an
//  explicit service UUID.
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
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

  // The last list actually delivered, as a signature, plus when. Android in
  // low-latency mode hands the results list back on EVERY advertisement
  // packet — 20 to 50 times a second with one Jota nearby — and every
  // delivery used to fan out through the controller as a notifyListeners,
  // rebuilding Home, the archive and the connect sheet at packet rate. That
  // was the app's felt lag. Nothing on screen changes packet-to-packet
  // except rssi jitter, so: deliver immediately when the list MEANS
  // something new (devices, pending, flags, battery), and otherwise at most
  // twice a second so rssi ordering still drifts through.
  String _lastSig = '';
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
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
      await FlutterBluePlus.setOptions(
        restoreState: true,
        showPowerAlert: true,
      );
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
      final String sig = ads
          .map(
            (JotaAdvertisement a) => '${a.remoteId}:${a.pending}:'
                '${a.paired}:${a.owned}:${a.battery}',
          )
          .join('|');
      final DateTime now = DateTime.now();
      final bool changed = sig != _lastSig;
      if (!changed &&
          now.difference(_lastEmit) < const Duration(milliseconds: 500)) {
        return;
      }
      _lastEmit = now;
      if (changed) {
        _lastSig = sig;
        // "Jota is not in range" is a claim about the radio, and it was
        // being made with nothing written down. Log what the scan actually
        // saw — once per change, not once per packet.
        if (ads.isEmpty) {
          debugPrint(
            'jota/ble  scan  ${results.length} device(s), no Jota among them',
          );
        } else {
          final String seen = ads.map((JotaAdvertisement a) {
            return '${a.remoteId} rssi=${a.rssi} pending=${a.pending} '
                'paired=${a.paired}';
          }).join(' | ');
          debugPrint('jota/ble  scan  $seen');
        }
      }
      if (!_found.isClosed) _found.add(ads);
    });

    debugPrint('jota/ble  scan  starting (timeout=$timeout)');
    // NO withServices filter, and that is deliberate.
    //
    // The platform filter is applied by the Android BLE stack before anything
    // reaches Dart, so when it fails to match it fails SILENTLY: the scanner
    // registers, reports success, and simply never delivers a result. There is
    // no error to catch and nothing to log — which is exactly what "Jota is
    // not in range" looked like while the device sat there advertising at
    // rssi -44.
    //
    // Jota's UUID is 128-bit, which with the manufacturer data and flags puts
    // the advertisement within a couple of bytes of the 31-byte limit, so
    // whether the UUID survives into the advertising packet rather than the
    // scan response is not something the app should be betting on.
    //
    // Filtering in Dart costs a few more callbacks per second and removes the
    // whole class of failure. JotaAdvertisement.from() already ignores
    // anything that is not a Jota.
    await FlutterBluePlus.startScan(
      timeout: timeout,
      continuousUpdates: continuousUpdates,
      // Report a device as gone if it has not advertised for a while, so the
      // list does not accumulate ghosts.
      removeIfGone: continuousUpdates ? const Duration(seconds: 20) : null,
      androidScanMode: AndroidScanMode.lowLatency,
    );
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _lastSig = '';
    _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
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
