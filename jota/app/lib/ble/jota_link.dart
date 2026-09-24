// ============================================================================
//  Jota — the link
//
//  One connected session with the device: discover the service, hold the eight
//  characteristics, and expose each one as a method that speaks the types from
//  jota_protocol.dart. Nothing above this layer touches a Guid or a byte list.
//
//  Deliberately dumb. It knows how to *say* things, not when to say them —
//  ordering, resume and CRC policy all live in sync_engine.dart.
// ============================================================================
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'device_diag.dart';
import 'jota_protocol.dart';

/// Raised when the device is present but will not do what the contract says.
class JotaLinkException implements Exception {
  const JotaLinkException(this.message, {this.isAuthFailure = false});

  final String message;

  /// The device rejected our pair code. Callers must NOT retry blindly:
  /// "Wrong code three times -> Jota drops the connection and stops
  /// advertising for 30 s."
  final bool isAuthFailure;

  @override
  String toString() => 'JotaLinkException: $message';
}

class JotaLink {
  JotaLink._(this.device, this._chars);

  final BluetoothDevice device;
  final Map<Guid, BluetoothCharacteristic> _chars;

  final StreamController<JotaStatus> _statusController =
      StreamController<JotaStatus>.broadcast();
  StreamSubscription<List<int>>? _statusSub;

  /// `status` notifications. Carries both state updates and the `{"error":...}`
  /// reports that a bad `fetch` produces, so the sync engine watches this the
  /// whole time a transfer is running.
  Stream<JotaStatus> get statusStream => _statusController.stream;

  String get remoteId => device.remoteId.str;
  bool get isConnected => device.isConnected;
  int get mtu => device.mtuNow;

  /// Connect, negotiate an MTU, discover the service and subscribe to `status`.
  ///
  /// [autoConnect] is what makes background reconnection work: the OS holds a
  /// pending connection and completes it whenever the device comes back into
  /// range, without the app having to be scanning at that moment.
  static Future<JotaLink> open(
    BluetoothDevice device, {
    Duration timeout = const Duration(seconds: 25),
    bool autoConnect = false,
  }) async {
    // "Request the largest MTU you can (247 is typical); throughput scales
    // almost linearly with it." flutter_blue_plus applies this on Android and
    // ignores it on iOS, where the MTU is negotiated for us.
    //
    // autoConnect and an explicit MTU are mutually exclusive in the plugin, so
    // a background reconnect takes whatever MTU it is given.
    await device.connect(
      timeout: timeout,
      autoConnect: autoConnect,
      mtu: autoConnect ? null : kDesiredMtu,
    );

    if (autoConnect) {
      // With autoConnect the future above returns as soon as the request is
      // queued, not when the link is up. Wait for the real thing.
      await device.connectionState
          .where(
            (BluetoothConnectionState s) =>
                s == BluetoothConnectionState.connected,
          )
          .first
          .timeout(timeout);
    }

    final List<BluetoothService> services = await device.discoverServices();
    final BluetoothService? svc = _firstWhereOrNull(
      services,
      (BluetoothService s) => s.uuid == JotaUuid.service,
    );
    if (svc == null) {
      await device.disconnect();
      throw const JotaLinkException(
        'device does not advertise the Jota service',
      );
    }

    final Map<Guid, BluetoothCharacteristic> chars =
        <Guid, BluetoothCharacteristic>{
      for (final BluetoothCharacteristic c in svc.characteristics) c.uuid: c,
    };

    final JotaLink link = JotaLink._(device, chars);
    await link._subscribeStatus();
    return link;
  }

  BluetoothCharacteristic _require(Guid uuid, String name) {
    final BluetoothCharacteristic? c = _chars[uuid];
    if (c == null) {
      throw JotaLinkException('device is missing the `$name` characteristic');
    }
    return c;
  }

  Future<void> _subscribeStatus() async {
    final BluetoothCharacteristic c = _require(JotaUuid.status, 'status');
    await c.setNotifyValue(true);
    _statusSub = c.onValueReceived.listen((List<int> bytes) {
      if (bytes.isEmpty) return;
      try {
        _statusController.add(JotaStatus.parse(bytes));
      } on FormatException {
        // A malformed status notify is not worth tearing a transfer down for.
      }
    });
    device.cancelWhenDisconnected(_statusSub!);
  }

  // ---- auth ---------------------------------------------------------------

  /// Present this phone to the device: its uuid, and the 6 digits if we have
  /// them.
  ///
  /// Writing succeeds either way — the characteristic acks the bytes whatever
  /// the device decides — so this returns nothing useful and the caller MUST
  /// read `status.authed` to find out what happened.
  Future<void> authenticate(String appId, {String? code}) async {
    final BluetoothCharacteristic c = _require(JotaUuid.auth, 'auth');
    try {
      await c.write(JotaPayload.auth(appId, code: code));
    } on FlutterBluePlusException catch (e) {
      throw JotaLinkException(
        'device rejected the pair code (${e.description ?? e.code})',
        isAuthFailure: true,
      );
    }
  }

  // ---- clock --------------------------------------------------------------

  /// "Jota has no network, so it cannot learn the time by itself. The app
  /// writes Unix seconds on every connect." Called unconditionally by the sync
  /// engine — it is two dozen bytes and it is the only reason timestamps are
  /// real rather than counted from boot.
  Future<void> setClock([DateTime? at]) async {
    final BluetoothCharacteristic c = _require(JotaUuid.clock, 'clock');
    await c.write(JotaPayload.clock(at ?? DateTime.now()));
  }

  // ---- status / index -----------------------------------------------------

  Future<JotaStatus> readStatus() async {
    final BluetoothCharacteristic c = _require(JotaUuid.status, 'status');
    return JotaStatus.parse(await c.read());
  }

  Future<List<JotaNoteIndexEntry>> readIndex() async {
    final BluetoothCharacteristic c = _require(JotaUuid.index, 'index');
    return JotaNoteIndexEntry.parseList(await c.read());
  }

  // ---- diag ---------------------------------------------------------------

  /// The device's own health, or null when it cannot say — old firmware has
  /// no `diag` characteristic, and an unauthenticated read answers `{}`.
  /// Never throws for either: a device without diagnostics still syncs.
  Future<DeviceDiag?> readDiag() async {
    final BluetoothCharacteristic? c = _chars[JotaUuid.diag];
    if (c == null) return null;
    try {
      return DeviceDiag.parse(await c.read());
    } on Exception {
      return null;
    }
  }

  // ---- erase --------------------------------------------------------------

  /// Whether this firmware can be erased over BLE at all.
  bool get supportsErase => _chars.containsKey(JotaUuid.erase);

  /// Ask the device to wipe itself: every note, the tag list, the bond.
  ///
  /// [deviceIdHex] is the id from `status`, echoed back as the confirmation.
  /// The device answers with a `status` notify of `{"error":"erased"}` once
  /// the wipe is done — the caller watches [statusStream] for it.
  Future<void> writeErase(String deviceIdHex) async {
    final BluetoothCharacteristic c = _require(JotaUuid.erase, 'erase');
    await c.write(JotaPayload.erase(deviceIdHex));
  }

  // ---- tags ---------------------------------------------------------------

  Future<List<String>> readTags() async {
    final BluetoothCharacteristic c = _require(JotaUuid.tags, 'tags');
    return JotaPayload.parseTags(await c.read());
  }

  /// Replaces the whole list. Clamped to 8 tags of 12 characters by
  /// JotaPayload.tags before it reaches the wire.
  Future<void> writeTags(List<String> tags) async {
    final BluetoothCharacteristic c = _require(JotaUuid.tags, 'tags');
    await c.write(JotaPayload.tags(tags));
  }

  // ---- fetch / data / ack -------------------------------------------------

  /// Subscribe to `data` and return the raw chunk stream.
  ///
  /// "Subscribe to `data` BEFORE writing `fetch`, or you will miss the first
  /// chunks." The sync engine calls this once per session and keeps the
  /// subscription for every note, so there is no window where a chunk can
  /// arrive with nobody listening.
  Future<Stream<List<int>>> openDataStream() async {
    final BluetoothCharacteristic c = _require(JotaUuid.data, 'data');
    if (!c.isNotifying) {
      await c.setNotifyValue(true);
    }
    return c.onValueReceived;
  }

  /// Break the bond from this side. The caller must already be the owner.
  Future<void> forgetMe(String appId) async {
    final BluetoothCharacteristic c = _require(JotaUuid.auth, 'auth');
    await c.write(JotaPayload.forget(appId));
  }

  /// Ask for note [id] starting at [offset] bytes in.
  ///
  /// `offset` 0 is a fresh transfer; anything else is a resume and the device
  /// seeks into the file rather than starting over.
  Future<void> requestFetch(int id, int offset) async {
    final BluetoothCharacteristic c = _require(JotaUuid.fetch, 'fetch');
    await c.write(JotaPayload.fetch(id, offset));
  }

  /// Tell the device the note arrived intact. It marks the note synced and
  /// decrements `pending`; the note leaves the index and is not offered again.
  ///
  /// Callers must have verified the CRC over the WHOLE note first.
  Future<void> sendAck(int id, String crcHex) async {
    final BluetoothCharacteristic c = _require(JotaUuid.ack, 'ack');
    await c.write(JotaPayload.ack(id, crcHex));
  }

  // ---- teardown -----------------------------------------------------------

  Future<void> close() async {
    await _statusSub?.cancel();
    _statusSub = null;
    await _statusController.close();
    if (device.isConnected) {
      await device.disconnect();
    }
  }
}

/// package:collection would give us firstWhereOrNull, but it is not worth a
/// dependency for one call site.
T? _firstWhereOrNull<T>(List<T> items, bool Function(T) test) {
  for (final T item in items) {
    if (test(item)) return item;
  }
  return null;
}

/// A convenience view over a byte stream for tests and for the transfer loop.
typedef ChunkSink = void Function(Uint8List chunk);
