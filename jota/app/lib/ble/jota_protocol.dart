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

/// `JOTA-91C4` from a device id — the last four characters, uppercased, which
/// is exactly what the device prints in its own status strip. One helper so the
/// two sides cannot drift into showing different things.
String jotaShortName(String deviceId) {
  if (deviceId.isEmpty) return kJotaLocalName;
  final String tail =
      deviceId.length > 4 ? deviceId.substring(deviceId.length - 4) : deviceId;
  return '$kJotaLocalName-${tail.toUpperCase()}';
}

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
    this.owned = false,
    this.deviceId = 0,
    this.battery,
  });

  final String remoteId;
  final String name;

  /// Notes recorded but not yet handed to the phone.
  final int pending;

  /// `flags` bit 0.
  final bool paired;

  /// `flags` bit 1 — some phone holds the bond. Not necessarily this one.
  final bool owned;

  /// The low 16 bits of the device id, broadcast so two Jotas can be told
  /// apart in a scan list BEFORE connecting to either.
  final int deviceId;

  /// Charge, 0..100, or null when the device has no battery sense wired (it
  /// broadcasts 0xFF) or is on firmware that predates the field.
  ///
  /// Carried in the advertisement rather than only in `status` so the app can
  /// show it WITHOUT connecting — the whole point of the advertisement is that
  /// the common questions are answerable for free.
  final int? battery;

  final int rssi;

  bool get hasWork => pending > 0;

  /// `JOTA-91C4`, matching what the device prints in its own status strip.
  String get shortName =>
      jotaShortName(deviceId.toRadixString(16).padLeft(4, '0'));

  /// Manufacturer data is 7 bytes:
  /// `FF FF <pending> <flags> <id-hi> <id-lo> <battery>`.
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
      owned: (payload[1] & 0x02) != 0,
      // Absent from a device on older firmware, which simply has no id to give.
      deviceId: payload.length >= 4 ? (payload[2] << 8) | payload[3] : 0,
      // 0xFF is the device saying "no sense pin", which is not the same as 0%.
      battery: payload.length >= 5 && payload[4] != 0xFF ? payload[4] : null,
      rssi: r.rssi,
    );
  }

  /// The id bytes are optional throughout: a device on older firmware sends
  /// four bytes rather than six, and it is still a perfectly good Jota.
  static List<int>? _manufacturerPayload(AdvertisementData ad) {
    for (final List<int> raw in ad.msd) {
      // Raw form: FF FF <pending> <flags> [<id-hi> <id-lo> [<battery>]]
      if (raw.length >= 4 && raw[0] == 0xFF && raw[1] == 0xFF) {
        return raw.sublist(2);
      }
      // Already-stripped form, with or without the optional tail.
      if (raw.length == 2 || raw.length == 4 || raw.length == 5) return raw;
    }
    // Last resort: the map, keyed by the 0xFFFF "no company" id.
    final List<int>? v = ad.manufacturerData[0xFFFF];
    if (v != null && v.length >= 2) return v;
    return null;
  }

  @override
  String toString() => 'JotaAdvertisement($remoteId, pending: $pending, '
      'paired: $paired, id: $shortName)';
}

// ---- status ----------------------------------------------------------------

/// `{"pending":3,"paired":true,"authed":false,"owned":true,
/// "device":"7f3a91c4","battery":84,"clock":1786045054}`
///
/// Also the channel for transfer errors: "fetch with offset beyond the file
/// length, or for an unknown id, gets a status notify with {"error":"range"}".
class JotaStatus {
  const JotaStatus({
    required this.pending,
    required this.paired,
    required this.authed,
    required this.owned,
    required this.device,
    required this.battery,
    required this.clock,
    this.error,
  });

  final int pending;
  final bool paired;

  /// Whether THIS connection has authenticated.
  ///
  /// The one field that must never be inferred. `status` is readable
  /// unauthenticated — deliberately, so an unauthenticated phone can find out
  /// that it is unauthenticated — so "the read worked" says nothing at all. The
  /// app used to treat a successful read as proof of a bond, never sent a code,
  /// and then read an empty `index` and reported "all caught up" with notes
  /// still sitting on the device.
  final bool authed;

  /// A phone holds the bond. Not necessarily this one.
  final bool owned;

  /// The device's own id, `7f3a91c4`. [shortName] is what a person sees.
  final String device;

  /// Percent, 0..100 — or -1 when the device has no battery sense wired. Use
  /// [batteryPercent], which turns that into a null rather than a number that
  /// would render as "-1%".
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
      authed: j['authed'] == true,
      owned: j['owned'] == true,
      device: j['device'] is String ? j['device'] as String : '',
      // Absent means UNMEASURABLE, not empty. Defaulting to 0 here would have
      // shown a full pack as flat on any firmware that omits the field.
      battery: _int(j['battery']) ?? -1,
      clock: _int(j['clock']) ?? 0,
      error: j['error'] is String ? j['error'] as String : null,
    );
  }

  /// `JOTA-91C4` — the same four characters the device prints in its own status
  /// strip, so the two can be matched by eye.
  String get shortName => jotaShortName(device);

  /// Charge, or null when the device cannot measure it.
  int? get batteryPercent =>
      (battery < 0 || battery > 100) ? null : battery;

  static const JotaStatus unknown = JotaStatus(
    pending: 0,
    paired: false,
    authed: false,
    owned: false,
    device: '',
    battery: -1,
    clock: 0,
  );

  @override
  String toString() =>
      'JotaStatus(pending: $pending, paired: $paired, authed: $authed, '
      'device: $device, battery: $battery%'
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
    this.tag,
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

  /// The tag armed on the device when this note was recorded, or null.
  ///
  /// A string, not an index into the tag list: the phone can edit that list
  /// between the recording and the sync, and an index would then name whatever
  /// happened to move into that slot.
  final String? tag;

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
          // "" is the device saying "no tag armed", which is a null here, not
          // a tag whose name is the empty string.
          tag: (e['tag'] as String? ?? '').isEmpty
              ? null
              : e['tag'] as String,
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
  /// `auth` — who we are, and the six digits if we have them.
  ///
  ///     {"app":"9f2c…"}                   the owner reconnecting, no code
  ///     {"app":"9f2c…","code":"428913"}   a new phone claiming the device
  ///
  /// [appId] is the uuid this phone generated on first run and never changes.
  /// Presenting it is what makes "pair once" true: the device remembers it and
  /// lets this phone back in silently, so a sync never has to interrupt anyone
  /// for six digits off a device that may be in another room.
  ///
  /// "Wrong code three times -> Jota drops the connection and stops advertising
  /// for 30 s", so the caller must not retry in a loop.
  static Uint8List auth(String appId, {String? code}) {
    final Map<String, String> body = <String, String>{'app': appId};
    if (code != null) {
      final String d = code.trim().replaceAll(RegExp(r'\D'), '');
      if (d.length != kPairCodeLength) {
        throw ArgumentError('auth: expected exactly 6 digits, got "$code"');
      }
      body['code'] = d;
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(body)));
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
