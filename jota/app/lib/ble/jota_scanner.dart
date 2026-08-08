// ============================================================================
//  Jota — scanning
//
//  The advertisement is the whole handshake before a handshake. Because the
//  manufacturer data carries `pending`, the phone learns HOW MANY NOTES ARE
//  WAITING WITHOUT CONNECTING — and if that number is zero, it goes back to
//  sleep without ever opening a link. That is the difference between a device
//  that lasts weeks on a charge and one that does not.
// ============================================================================
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'jota_protocol.dart';

class JotaScanner {
  JotaScanner();

  final StreamController<List<JotaAdvertisement>> _found =
      StreamController<List<JotaAdvertisement>>.broadcast();
  StreamSubscription<List<ScanResult>>? _sub;

  /// Every Jota currently in range, strongest signal first.
  Stream<List<JotaAdvertisement>> get devices => _found.stream;

  bool get isScanning => FlutterBluePlus.isScanningNow;

  static Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  static Future<bool> get isSupported => FlutterBluePlus.isSupported;

  /// Ask iOS to hand the app back its central manager after the system has
  /// killed and relaunched it — `CBCentralManagerOptionRestoreIdentifierKey`.
  ///
  /// Must be called before ANY other flutter_blue_plus call, which is why
  /// main() does it first. No effect on Android.
  static Future<void> configureForBackground() async {
    if (Platform.isIOS) {
      await FlutterBluePlus.setOptions(restoreState: true);
    }
  }

  /// Start scanning for Jota.
  ///
  /// Filtering by service UUID is not an optimisation here, it is a
  /// requirement: iOS only delivers scan results to a backgrounded app for
  /// scans that name an explicit service UUID.
  ///
  /// [continuousUpdates] keeps re-reporting a device that stays in range so
  /// `pending` stays fresh — without it, the count is whatever it was in the
  /// first advertisement seen and never changes.
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
          // Report it with pending unknown (0) rather than hiding it, so the
          // user can at least connect by hand.
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
  /// actually has notes waiting. Background sync uses it so a Jota sitting
  /// empty on a desk never causes a connection.
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

  /// A handle to a device we already know the id of — no scan required.
  ///
  /// This is how the app reconnects to the paired Jota: the id is in settings,
  /// and on both platforms the OS can connect to a known peripheral directly.
  static BluetoothDevice deviceFor(String remoteId) =>
      BluetoothDevice.fromId(remoteId);

  Future<void> dispose() async {
    await stop();
    await _found.close();
  }
}
