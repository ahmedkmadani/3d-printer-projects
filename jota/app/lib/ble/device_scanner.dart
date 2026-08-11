// ============================================================================
//  Jota — scanning interface
//
//  The advertisement is the handshake before the handshake. Because the
//  manufacturer data carries `pending`, the phone learns HOW MANY NOTES ARE
//  WAITING WITHOUT CONNECTING — and if that number is zero it goes back to sleep
//  without ever opening a link. That is the difference between a device that
//  lasts weeks on a charge and one that does not.
//
//  Nothing here mentions a flutter_blue_plus type, including the adapter state:
//  [AdapterStatus] is ours, so a fake scanner is a plain Dart object (see
//  lib/preview/) and the radio's vocabulary stops at the real implementation,
//  JotaScanner.
// ============================================================================
import 'jota_protocol.dart';

/// The phone's Bluetooth radio, in the four states the UI actually reacts to.
enum AdapterStatus {
  /// Ready.
  on,

  /// Present but switched off. The user can fix this.
  off,

  /// Permission denied. The user can fix this, somewhere else.
  unauthorized,

  /// No BLE on this hardware, or we have not been told yet.
  unavailable;

  bool get isReady => this == AdapterStatus.on;

  String get label {
    switch (this) {
      case AdapterStatus.on:
        return 'ON';
      case AdapterStatus.off:
        return 'OFF';
      case AdapterStatus.unauthorized:
        return 'DENIED';
      case AdapterStatus.unavailable:
        return 'UNAVAILABLE';
    }
  }
}

abstract class DeviceScanner {
  /// Every Jota currently in range, strongest signal first.
  Stream<List<JotaAdvertisement>> get devices;

  /// The radio's state, as a stream because the user can toggle it while a
  /// screen is open.
  Stream<AdapterStatus> get adapterState;

  AdapterStatus get adapterNow;

  bool get isScanning;

  /// Start scanning.
  ///
  /// Implementations MUST filter by the Jota service UUID: iOS only delivers
  /// scan results to a backgrounded app for scans that name an explicit service.
  /// A null [timeout] means scan until told to stop.
  Future<void> start({Duration? timeout});

  Future<void> stop();

  /// Ask the OS to turn Bluetooth on, so the user never has to leave the app to
  /// dig through Settings.
  ///
  /// Android shows a system "allow this app to turn on Bluetooth" dialog and
  /// this resolves `true` once it comes on. **iOS forbids turning the radio on
  /// from an app**, so there it returns `false` — the caller should then fall
  /// back to nudging the system's own prompt (start a scan) or guiding to
  /// Settings.
  Future<bool> turnOn();

  Future<void> dispose();
}
