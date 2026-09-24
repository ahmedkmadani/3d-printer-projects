// ============================================================================
//  Jota — device diagnostics
//
//  The `diag` characteristic's payload: which firmware the device runs, why
//  it last rebooted, and its lifetime counters. Pure data plus a parser — no
//  I/O, no plugin imports — so the sync interface and the fakes can carry it
//  without dragging the radio into either.
//
//  Old firmware has no `diag` characteristic at all. Everywhere in the app a
//  DeviceDiag is therefore nullable, and null means "this device cannot say",
//  never an error: a device without diagnostics still syncs notes, and that
//  is the part that cannot wait.
// ============================================================================
import 'dart:convert';

class DeviceDiag {
  const DeviceDiag({
    required this.fw,
    required this.built,
    required this.reset,
    required this.boots,
    required this.crashes,
    required this.notes,
    required this.syncs,
    required this.upSeconds,
    required this.freeHeap,
  });

  /// Git short sha the firmware was built from. A trailing `+` means the
  /// tree was dirty, so the binary only resembles that commit.
  final String fw;

  /// Build date, `2026-09-24`.
  final String built;

  /// Why the current boot happened: `poweron` / `sw` / `panic` / `wdt` /
  /// `brownout` / `sleep` / `other`.
  final String reset;

  /// Lifetime counters, kept on the device in NVS. A crash is a panic,
  /// watchdog or brownout reset.
  final int boots;
  final int crashes;

  /// Notes recorded (recovered orphans do not count) and syncs served.
  final int notes;
  final int syncs;

  /// Seconds since this boot, and free heap bytes at the moment of the read.
  final int upSeconds;
  final int freeHeap;

  /// Null on anything that is not a diag payload — including the `{}` the
  /// device answers an unauthenticated read with.
  static DeviceDiag? parse(List<int> raw) {
    try {
      final Object? j = jsonDecode(utf8.decode(raw, allowMalformed: true));
      if (j is! Map<String, dynamic>) return null;
      final String? fw = j['fw'] is String ? j['fw'] as String : null;
      if (fw == null || fw.isEmpty) return null;
      return DeviceDiag(
        fw: fw,
        built: j['built'] is String ? j['built'] as String : '',
        reset: j['reset'] is String ? j['reset'] as String : '',
        boots: _int(j['boots']),
        crashes: _int(j['crashes']),
        notes: _int(j['notes']),
        syncs: _int(j['syncs']),
        upSeconds: _int(j['up']),
        freeHeap: _int(j['heap']),
      );
    } on FormatException {
      return null;
    }
  }

  static int _int(Object? v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  String toString() => 'DeviceDiag(fw: $fw, built: $built, reset: $reset, '
      'boots: $boots, crashes: $crashes, notes: $notes, syncs: $syncs, '
      'up: ${upSeconds}s, heap: $freeHeap)';
}
