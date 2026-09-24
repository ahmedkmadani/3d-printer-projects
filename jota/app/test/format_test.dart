// The formatters that today's coherence pass corrected: day headings speak
// the stamp's language (never ISO), and bytes are unpadded measurements.
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/design/format.dart';

void main() {
  group('fmtDayHeading', () {
    final DateTime now = DateTime(2026, 9, 24, 14, 0);

    test('today and yesterday are words', () {
      expect(fmtDayHeading(DateTime(2026, 9, 24, 9), now: now), 'TODAY');
      expect(fmtDayHeading(DateTime(2026, 9, 23, 23), now: now), 'YESTERDAY');
    });

    test('older days read like the stamp, not ISO', () {
      // 2026-09-21 is a Monday. It used to print "2026-09-21".
      expect(fmtDayHeading(DateTime(2026, 9, 21), now: now), 'MON 21 SEP');
    });
  });

  group('fmtBytes', () {
    test('no zero padding — 000B read as broken', () {
      expect(fmtBytes(0), '0B');
      expect(fmtBytes(12 * 1024), '12K');
      expect(fmtBytes(899 * 1024), '899K');
      expect(fmtBytes((3.5 * 1024 * 1024).round()), '3.5M');
    });
  });
}
