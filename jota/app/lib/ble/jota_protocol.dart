// ============================================================================
//  Jota — BLE protocol
//
//  The Dart side of firmware/docs/ble-service.md. Every UUID, payload shape and
//  parse rule in the contract lives in THIS FILE and nowhere else, so there is
//  exactly one place to look when the firmware changes.
//
//  Nothing here does I/O. It is pure codec + value types, which is what makes
//  the reassembly and resume logic in sync_engine.dart testable without a
//  radio.
// ============================================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ---- UUIDs -----------------------------------------------------------------
// "All share the service base; only the last field changes." The service's last
// field is all zeroes, so characteristic N is that field set to N.
abstract final class JotaUuid {
  static const String _base = '4a6f7461-1e5f-4b2a-9c33-';

  static Guid _c(int n) => Guid('$_base${n.toString().padLeft(12, '0')}');

  /// The advertised service. Also the filter the OS uses to wake the app.
  static final Guid service = _c(0);

  /// write — 6 digits, e.g. `428913`
  static final Guid auth = _c(1);

  /// read, notify — JSON `{"pending":3,"paired":true,"battery":84,...}`
  static final Guid status = _c(2);

  /// read — JSON array of pending notes
  static final Guid index = _c(3);

  /// write — JSON `{"id":12,"offset":0}`
  static final Guid fetch = _c(4);

  /// notify — raw ADPCM chunks
  static final Guid data = _c(5);

  /// write — JSON `{"id":12,"crc":"a1b2c3d4"}`
  static final Guid ack = _c(6);

  /// read, write — JSON array of strings
  static final Guid tags = _c(7);

  /// write — Unix seconds, decimal string
  static final Guid clock = _c(8);
}

/// Advertised local name. Used as a secondary filter only — the service UUID is
/// the real one, because a name is not unique and iOS does not always give it
/// to us in the background.
const String kJotaLocalName = 'JOTA';

/// The contract's ceiling for the tag list: "Max 8 tags, 12 characters each".
const int kMaxTags = 8;
const int kMaxTagLength = 12;

/// The device shows a 6-digit code on its e-paper.
const int kPairCodeLength = 6;

/// "Request the largest MTU you can (247 bytes is typical); throughput scales
/// almost linearly with it."
const int kDesiredMtu = 247;

// ---- Advertisement ---------------------------------------------------------

/// What the phone can learn about Jota WITHOUT connecting.
///
/// This is the whole point of the manufacturer-data field: if `pending` is
/// zero the app never wakes and neither side spends battery.
class JotaAdvertisement {
  const JotaAdvertisement({
    required this.remoteId,
    required this.name,
    required this.pending,
    required this.paired,
    required this.rssi,
  });

  final String remoteId;
  final String name;

  /// Notes recorded but not yet handed to the phone.
  final int pending;

  /// `flags` bit 0.
  final bool paired;

  final int rssi;

  bool get hasWork => pending > 0;

  /// Manufacturer data is 4 bytes: `FF FF <pending> <flags>`.
  ///
  /// `FF FF` is the "no company assigned" identifier — Jota has no Bluetooth
  /// SIG company ID, and a manufacturer-data AD structure is required to start
  /// with one. flutter_blue_plus splits that prefix off and keys the map by it,
  /// so our two bytes arrive as the *value* under key 0xFFFF.
  ///
  /// We read `msd` (the raw form, prefix included) rather than the map, and
  /// accept both shapes: a stack that hands back the prefix and a stack that
  /// does not. Cheaper than debugging it on a phone that only reproduces it in
  /// the background.
  static JotaAdvertisement? from(ScanResult r) {
    final List<int>? payload = _manufacturerPayload(r.advertisementData);
    if (payload == null) return null;

    return JotaAdvertisement(
      remoteId: r.device.remoteId.str,
      name: r.advertisementData.advName.isEmpty
          ? kJotaLocalName
          : r.advertisementData.advName,
      pending: payload[0],
      paired: (payload[1] & 0x01) != 0,
      rssi: r.rssi,
    );
  }

  static List<int>? _manufacturerPayload(AdvertisementData ad) {
    for (final List<int> raw in ad.msd) {
      // Raw form: FF FF <pending> <flags>
      if (raw.length >= 4 && raw[0] == 0xFF && raw[1] == 0xFF) {
        return <int>[raw[2], raw[3]];
      }
      // Already-stripped form: <pending> <flags>
      if (raw.length == 2) return <int>[raw[0], raw[1]];
    }
    // Last resort: the map, keyed by the 0xFFFF "no company" id.
    final List<int>? v = ad.manufacturerData[0xFFFF];
    if (v != null && v.length >= 2) return <int>[v[0], v[1]];
    return null;
  }

  @override
  String toString() =>
      'JotaAdvertisement($remoteId, pending: $pending, paired: $paired)';
}

// ---- status ----------------------------------------------------------------

/// `{"pending":3,"paired":true,"battery":84,"clock":1786045054}`
///
/// Also the channel for transfer errors: "fetch with offset beyond the file
/// length, or for an unknown id, gets a status notify with {"error":"range"}".
class JotaStatus {
  const JotaStatus({
    required this.pending,
    required this.paired,
    required this.battery,
    required this.clock,
    this.error,
  });

  final int pending;
  final bool paired;

  /// Percent, 0..100.
  final int battery;

  /// The device's own idea of the time. Unix seconds; 0 before the app has
  /// written `clock` since the last power cycle.
  final int clock;

  /// Non-null when this notify is an error report rather than a state update.
  /// The only documented value is `range`.
  final String? error;

  bool get isError => error != null;

  /// True when the device's RTC has never been set or has drifted more than a
  /// couple of minutes from ours — the app writes `clock` on every connect
  /// regardless, so this only drives what the UI says.
  bool clockLooksUnset({DateTime? now}) {
    if (clock <= 0) return true;
    final int ours = ((now ?? DateTime.now()).millisecondsSinceEpoch) ~/ 1000;
    return (ours - clock).abs() > 120;
  }

  DateTime? get clockTime => clock <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(clock * 1000, isUtc: true)
          .toLocal();

  static JotaStatus parse(List<int> bytes) {
    final Object? j = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    if (j is! Map<String, dynamic>) {
      throw const FormatException('status: expected a JSON object');
    }
    return JotaStatus(
      pending: _int(j['pending']) ?? 0,
      paired: j['paired'] == true,
      battery: _int(j['battery']) ?? 0,
      clock: _int(j['clock']) ?? 0,
      error: j['error'] is String ? j['error'] as String : null,
    );
  }

  static const JotaStatus unknown = JotaStatus(
    pending: 0,
    paired: false,
    battery: 0,
    clock: 0,
  );

  @override
  String toString() =>
      'JotaStatus(pending: $pending, paired: $paired, battery: $battery%'
      '${error == null ? '' : ', error: $error'})';
}

// ---- index -----------------------------------------------------------------

/// One entry of `[{"id":12,"secs":47,"bytes":389120,"crc":"a1b2c3d4",
/// "time":1786045054}]`.
///
/// `bytes` and `crc` describe the ADPCM copy the phone receives — NOT the raw
/// WAV on the SD card. Checksum what arrives on the wire, nothing else.
class JotaNoteIndexEntry {
  const JotaNoteIndexEntry({
    required this.id,
    required this.secs,
    required this.bytes,
    required this.crc,
    required this.time,
  });

  final int id;
  final int secs;

  /// Total ADPCM length. The transfer is complete when we hold exactly this
  /// many bytes — and only then is the CRC meaningful.
  final int bytes;

  /// Eight lowercase hex digits.
  final String crc;

  /// Unix seconds, as recorded by the device's RTC.
  final int time;

  DateTime get recordedAt => time <= 0
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true).toLocal();

  static List<JotaNoteIndexEntry> parseList(List<int> raw) {
    final Object? j = jsonDecode(utf8.decode(raw, allowMalformed: true));
    if (j is! List) throw const FormatException('index: expected a JSON array');
    final List<JotaNoteIndexEntry> out = <JotaNoteIndexEntry>[];
    for (final Object? e in j) {
      if (e is! Map<String, dynamic>) continue;
      final int? id = _int(e['id']);
      final int? bytes = _int(e['bytes']);
      if (id == null || bytes == null) continue; // unusable without these
      out.add(
        JotaNoteIndexEntry(
          id: id,
          secs: _int(e['secs']) ?? 0,
          bytes: bytes,
          crc: (e['crc'] as String? ?? '').toLowerCase(),
          time: _int(e['time']) ?? 0,
        ),
      );
    }
    return out;
  }

  @override
  String toString() => 'JotaNoteIndexEntry(id: $id, bytes: $bytes, crc: $crc)';
}

// ---- write payloads --------------------------------------------------------

abstract final class JotaPayload {
  /// `auth` — the six digits shown on the e-paper, as ASCII.
  ///
  /// "Wrong code three times -> Jota drops the connection and stops advertising
  /// for 30 s", so the caller must not retry in a loop.
  static Uint8List auth(String sixDigits) {
    final String d = sixDigits.trim();
    if (d.length != kPairCodeLength || !RegExp(r'^\d{6}$').hasMatch(d)) {
      throw ArgumentError('auth: expected exactly 6 digits, got "$sixDigits"');
    }
    return Uint8List.fromList(utf8.encode(d));
  }

  /// `clock` — Unix seconds as a decimal string, not a binary integer.
  static Uint8List clock(DateTime at) {
    final int secs = at.millisecondsSinceEpoch ~/ 1000;
    return Uint8List.fromList(utf8.encode(secs.toString()));
  }

  /// `fetch` — `{"id":12,"offset":0}`.
  ///
  /// `offset` is how many bytes of this note the phone already holds. Zero
  /// starts from the beginning; anything else is a resume, and the device seeks
  /// into the file rather than re-sending what we have.
  static Uint8List fetch(int id, int offset) {
    return Uint8List.fromList(
      utf8.encode(jsonEncode(<String, int>{'id': id, 'offset': offset})),
    );
  }

  /// `ack` — `{"id":12,"crc":"a1b2c3d4"}`.
  ///
  /// Sending this is a promise: the device marks the note synced and decrements
  /// `pending`, and it is gone from the index forever. Never call it without a
  /// verified CRC over the complete note.
  static Uint8List ack(int id, String crcHex) {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object>{'id': id, 'crc': crcHex.toLowerCase()}),
      ),
    );
  }

  /// `tags` — a JSON array of strings that REPLACES the whole list.
  ///
  /// Clamped to the contract's limits here rather than in the UI, so no code
  /// path can push a list the device will reject or truncate silently.
  static Uint8List tags(List<String> tags) {
    final List<String> clean = tags
        .map((String t) => t.trim().toUpperCase())
        .where((String t) => t.isNotEmpty)
        .map(
          (String t) =>
              t.length > kMaxTagLength ? t.substring(0, kMaxTagLength) : t,
        )
        .take(kMaxTags)
        .toList();
    return Uint8List.fromList(utf8.encode(jsonEncode(clean)));
  }

  static List<String> parseTags(List<int> raw) {
    final Object? j = jsonDecode(utf8.decode(raw, allowMalformed: true));
    if (j is! List) throw const FormatException('tags: expected a JSON array');
    return j.whereType<String>().toList();
  }
}

// ---- shared helpers --------------------------------------------------------

/// JSON numbers arrive as int or double depending on how the firmware's
/// serialiser felt that day. Accept both, and strings, rather than crashing a
/// sync over a formatting detail.
int? _int(Object? v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}
