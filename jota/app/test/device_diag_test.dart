// ============================================================================
//  Jota — the diag payload
//
//  The one rule under test: null means "this device cannot say", and every
//  malformed shape must land there rather than throwing mid-sync — a device
//  without diagnostics still hands over audio.
// ============================================================================
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jota/ble/device_diag.dart';

List<int> bytes(String s) => utf8.encode(s);

void main() {
  test('a full payload parses field for field', () {
    final DeviceDiag? d = DeviceDiag.parse(
      bytes(
        '{"fw":"c485eee","built":"2026-09-24","reset":"sleep","boots":41,'
        '"crashes":2,"notes":17,"syncs":29,"up":118,"heap":214520}',
      ),
    );
    expect(d, isNotNull);
    expect(d!.fw, 'c485eee');
    expect(d.built, '2026-09-24');
    expect(d.reset, 'sleep');
    expect(d.boots, 41);
    expect(d.crashes, 2);
    expect(d.notes, 17);
    expect(d.syncs, 29);
    expect(d.upSeconds, 118);
    expect(d.freeHeap, 214520);
  });

  test('the unauthenticated answer {} is null, not an error', () {
    expect(DeviceDiag.parse(bytes('{}')), isNull);
  });

  test('garbage is null, not an exception', () {
    expect(DeviceDiag.parse(bytes('not json')), isNull);
    expect(DeviceDiag.parse(bytes('[]')), isNull);
    expect(DeviceDiag.parse(bytes('')), isNull);
    expect(DeviceDiag.parse(bytes('{"fw":""}')), isNull);
  });

  test('numbers as strings are tolerated, missing counters are zero', () {
    final DeviceDiag? d = DeviceDiag.parse(bytes('{"fw":"dev","boots":"7"}'));
    expect(d, isNotNull);
    expect(d!.boots, 7);
    expect(d.crashes, 0);
    expect(d.built, '');
  });

  test('a dirty build keeps its + marker', () {
    final DeviceDiag? d = DeviceDiag.parse(bytes('{"fw":"c485eee+"}'));
    expect(d!.fw, 'c485eee+');
  });
}
