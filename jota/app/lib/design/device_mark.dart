// ============================================================================
//  Jota — the device, drawn
//
//  The Jota itself in hairline ink, for the moment it is found: a rounded
//  square case in Pala Note V1.0's measured proportions, the e-paper window
//  centred as an inner rounded square on the field colour with the word
//  inside, and the two side buttons as short stadiums on the right edge.
//  On success the window fills with ink and a check is drawn across it.
// ============================================================================
import 'package:flutter/material.dart';

import 'theme.dart';

class JotaDeviceMark extends StatelessWidget {
  const JotaDeviceMark({
    super.key,
    this.height = 140,
    this.done = false,
    this.checkProgress = 0,
  });

  final double height;

  /// Window filled with ink, the check drawn to [checkProgress].
  final bool done;
  final double checkProgress;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    return CustomPaint(
      size: Size(height * (44.9 + 1.2) / 58.4, height),
      painter: _DevicePainter(
        ink: c.ink,
        field: c.field,
        paper: c.bg,
        onInk: c.onInk,
        word: t.reading.copyWith(color: done ? c.onInk : c.ink),
        done: done,
        check: checkProgress,
      ),
    );
  }
}

class _DevicePainter extends CustomPainter {
  const _DevicePainter({
    required this.ink,
    required this.field,
    required this.paper,
    required this.onInk,
    required this.word,
    required this.done,
    required this.check,
  });

  final Color ink, field, paper, onInk;
  final TextStyle word;
  final bool done;
  final double check;

  // The case the user actually holds: Pala Note V1.0, measured from its
  // STEP in mm and scaled to fit. 44.9 x 58.4, corners ~10.5; the 29 x 30
  // window horizontally centred with its centre 2.5 above the case's, so
  // the bottom margin is the bigger one; two 7 mm buttons on the right
  // edge, in the lower half, standing 1.2 proud. Nothing on the left; the
  // USB is on the bottom edge and is not drawn.
  static const double _caseW = 44.9, _caseH = 58.4, _corner = 10.5;
  static const double _winW = 29, _winH = 30, _winLift = 2.5, _winR = 2;
  static const double _btnL = 7, _btnProud = 1.2, _btnT = 2.2;
  static const List<double> _btnUp = <double>[14.7, 25.7];

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.height / _caseH; // mm -> px
    final double bw = _caseW * k, bh = _caseH * k;
    final Paint line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = JotaGrid.hairline * 1.5;

    // The case: filled with the paper so the outline reads on both themes.
    final RRect caseR = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bw, bh),
      Radius.circular(_corner * k),
    );
    canvas.drawRRect(caseR, Paint()..color = paper);
    canvas.drawRRect(caseR, line);

    // The window.
    final Rect winRect = Rect.fromCenter(
      center: Offset(bw / 2, bh / 2 - _winLift * k),
      width: _winW * k,
      height: _winH * k,
    );
    final RRect winR =
        RRect.fromRectAndRadius(winRect, Radius.circular(_winR * k));
    canvas.drawRRect(winR, Paint()..color = done ? ink : field);
    canvas.drawRRect(winR, line);

    // The two side buttons, on the right edge, lower half.
    for (final double up in _btnUp) {
      final double cy = bh - up * k;
      final RRect b = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bw - (_btnT - _btnProud) * k,
          cy - _btnL * k / 2,
          _btnT * k,
          _btnL * k,
        ),
        Radius.circular(_btnT * k / 2),
      );
      canvas.drawRRect(b, Paint()..color = paper);
      canvas.drawRRect(b, line);
    }

    if (done) {
      final double win = winRect.width;
      final Path path = Path()
        ..moveTo(winRect.left + win * 0.26, winRect.top + win * 0.53)
        ..lineTo(winRect.left + win * 0.44, winRect.top + win * 0.70)
        ..lineTo(winRect.left + win * 0.76, winRect.top + win * 0.32);
      final Paint p = Paint()
        ..color = onInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * check), p);
      }
      return;
    }

    // The word on the panel, mono and small, as the splash draws it.
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: 'Jota',
        style: word.copyWith(fontSize: winRect.width * 0.2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        winRect.center.dx - tp.width / 2,
        winRect.center.dy - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_DevicePainter old) =>
      old.done != done || old.check != check || old.ink != ink;
}
