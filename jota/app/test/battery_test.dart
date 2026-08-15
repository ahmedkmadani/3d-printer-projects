// ============================================================================
//  Jota — battery
//
//  One rule under all of these: UNKNOWN is not ZERO. A board with no sense pin
//  wired, a device out of range, and firmware that predates the field all mean
//  "we cannot say" — and showing 0% for any of them sends someone looking for
//  a charger they do not need.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/ble/jota_protocol.dart';

void main() {
  group('the advertisement carries charge', () {
    test('a real percentage comes through', () {
      const JotaAdvertisement ad = JotaAdvertisement(
        remoteId: 'x',
        name: 'JOTA',
        pending: 0,
        paired: true,
        deviceId: 0x91c4,
        battery: 62,
        rssi: -50,
      );
      expect(ad.battery, 62);
    });

    test('a device with no sense pin reports nothing, not nothing left', () {
      const JotaAdvertisement ad = JotaAdvertisement(
        remoteId: 'x',
        name: 'JOTA',
        pending: 0,
        paired: true,
        rssi: -50,
      );
      expect(ad.battery, isNull);
    });
  });

  group('status', () {
    JotaStatus parse(String json) => JotaStatus.parse(json.codeUnits);

    test('reads charge alongside the rest', () {
      final JotaStatus s = parse(
        '{"pending":3,"paired":true,"authed":true,"owned":true,'
        '"device":"7f3a91c4","battery":84,"clock":1786045054}',
      );
      expect(s.batteryPercent, 84);
      expect(s.shortName, 'JOTA-91C4');
      expect(s.authed, isTrue);
    });

    test('-1 means unmeasurable, and never renders as a figure', () {
      final JotaStatus s = parse('{"pending":0,"battery":-1}');
      expect(s.batteryPercent, isNull);
    });

    test('a missing field is unknown too, not full', () {
      final JotaStatus s = parse('{"pending":0}');
      expect(s.batteryPercent, isNull, reason: 'absent must not read as 0%');
    });

    test('an out-of-range figure is refused rather than shown', () {
      expect(parse('{"battery":150}').batteryPercent, isNull);
    });
  });
}
