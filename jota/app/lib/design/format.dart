// ============================================================================
//  Jota — figure formatting
//
//  Every number the user sees goes through here. The device zero-pads to a
//  fixed width so figures never reflow and columns stay aligned without a
//  layout pass; the app does the same, from the same helpers, so `N-012` on the
//  panel and `N-012` in the list are the same string produced the same way.
//
//  Mirrors the static helpers at the top of firmware/src/ui/screens.cpp.
// ============================================================================

/// `12` -> `N-012`. The canonical way a note is named anywhere in the product.
String fmtNoteId(int id) => 'N-${id.toString().padLeft(3, '0')}';

/// `47` -> `00:47`, `3671` -> `61:11`. Minutes are not clamped to two digits —
/// a long note should read as a long note, not wrap around.
String fmtDuration(int seconds) {
  final int s = seconds < 0 ? 0 : seconds;
  final String mm = (s ~/ 60).toString().padLeft(2, '0');
  final String ss = (s % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// `12` -> `012`. The status line's right slot when it holds a count.
String fmtCount(int value) => value.toString().padLeft(3, '0');

/// `4, 5` -> `004/005`. The status line's right slot when it holds a ratio or
/// a position — sync progress, note N of M.
String fmtRatio(int done, int total) => '${fmtCount(done)}/${fmtCount(total)}';

/// `14:32`. Wall-clock time, 24h, the same slot the device's live clock uses.
String fmtClock(DateTime t) {
  final String hh = t.hour.toString().padLeft(2, '0');
  final String mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// `TUE 12 AUG · 14:32`. The note-row stamp.
///
/// A weekday rather than a bare date, because that is how anyone actually
/// reaches for a note — "the one after Tuesday's session", never "the one from
/// 2026-08-12". Upper case and mono so it sits in the same figure vocabulary
/// as every other measurement.
String fmtNoteStamp(DateTime t) {
  const List<String> days = <String>[
    'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN',
  ];
  const List<String> months = <String>[
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  final String d = days[(t.weekday - 1) % 7];
  final String m = months[(t.month - 1) % 12];
  return '$d ${t.day} $m · ${fmtClock(t)}';
}

/// `2026-08-06`. Used as a list section heading.
String fmtDate(DateTime t) {
  final String y = t.year.toString().padLeft(4, '0');
  final String m = t.month.toString().padLeft(2, '0');
  final String d = t.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Relative day heading — `TODAY`, `YESTERDAY`, or the ISO date. Uppercase
/// because it goes in a `label` slot.
String fmtDayHeading(DateTime t, {DateTime? now}) {
  final DateTime n = now ?? DateTime.now();
  final DateTime a = DateTime(t.year, t.month, t.day);
  final DateTime b = DateTime(n.year, n.month, n.day);
  final int days = b.difference(a).inDays;
  if (days == 0) return 'TODAY';
  if (days == 1) return 'YESTERDAY';
  return fmtDate(t);
}

/// `389120` -> `380K`. Right-aligned in a mono column, so a fixed width
/// matters more than precision.
String fmtBytes(int bytes) {
  if (bytes < 1024) return '${bytes.toString().padLeft(3, '0')}B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).round().toString().padLeft(3, '0')}K';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}M';
}

/// `0.42` -> `042%`. Percentages are figures, so they are zero-padded too.
String fmtPercent(double fraction) {
  final int pct = (fraction.clamp(0.0, 1.0) * 100).round();
  return '${pct.toString().padLeft(3, '0')}%';
}

/// The six-digit pair code, split for legibility exactly as the e-paper shows
/// it: `428913` -> `428 913`.
String fmtPairCode(String digits) {
  if (digits.length != 6) return digits;
  return '${digits.substring(0, 3)} ${digits.substring(3)}';
}

/// CRC32 as the protocol writes it: eight lowercase hex digits, zero-padded.
String fmtCrc(int crc) => (crc & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
