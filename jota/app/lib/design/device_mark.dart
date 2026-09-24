// ============================================================================
//  Jota — the device, rendered
//
//  The Jota the user holds — Pala Note V1.0, measured from its STEP in mm —
//  drawn as an object rather than an outline: fills with soft shading, a
//  faint highlight along the top-left edge, a soft shadow beneath, the
//  e-paper window slightly recessed in e-paper grey with "Jota" in mono,
//  and the two side buttons as small light stadiums. No lines, the way an
//  earbud case is drawn on a phone. On success the window inverts and a
//  check is drawn across it.
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

  /// Window inverted, the check drawn to [checkProgress].
  final bool done;
  final double checkProgress;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    return CustomPaint(
      // Room around the case for the buttons' overhang and the shadow.
      size: Size(height * (44.9 + 4) / 58.4, height + 12),
      painter: _DevicePainter(
        dark: c.brightnessIsDark,
        ink: c.ink,
        onInk: c.onInk,
        word: t.reading,
        done: done,
        check: checkProgress,
      ),
    );
  }
}

class _DevicePainter extends CustomPainter {
  const _DevicePainter({
    required this.dark,
    required this.ink,
    required this.onInk,
    required this.word,
    required this.done,
    required this.check,
  });

  final bool dark;
  final Color ink, onInk;
  final TextStyle word;
  final bool done;
  final double check;

  // Pala Note V1.0 in mm: 44.9 x 58.4, corners ~10.5; the 29 x 30 window
  // horizontally centred with its centre 2.5 above the case's; two 7 mm
  // buttons on the right edge, in the lower half, 1.2 proud. Nothing on
  // the left; the USB is on the bottom edge and is not drawn.
  static const double _caseW = 44.9, _caseH = 58.4, _corner = 10.5;
  static const double _winW = 29, _winH = 30, _winLift = 2.5, _winR = 2;
  static const double _btnL = 7, _btnProud = 1.2, _btnT = 2.4;
  static const List<double> _btnUp = <double>[14.7, 25.7];

  @override
  void paint(Canvas canvas, Size size) {
    final double k = (size.height - 12) / _caseH; // mm -> px
    final double bw = _caseW * k, bh = _caseH * k;
    final Rect body = Rect.fromLTWH(1.5 * k, 0, bw, bh);
    final RRect caseR =
        RRect.fromRectAndRadius(body, Radius.circular(_corner * k));

    // Plastic: paper-white in light, warm grey in dark; a whisper darker at
    // the bottom so it turns away from the light.
    final Color top = dark ? const Color(0xFF3A3733) : const Color(0xFFF7F3EC);
    final Color bottom =
        dark ? const Color(0xFF322F2B) : const Color(0xFFEDE8DF);
    final Color panel =
        dark ? const Color(0xFF8E8B85) : const Color(0xFFD9D6CF);
    final Color panelEdge =
        dark ? const Color(0xFF6C6963) : const Color(0xFFC3C0B8);
    final Color shadow = Colors.black.withValues(alpha: dark ? 0.35 : 0.14);
    final Color highlight = Colors.white.withValues(alpha: dark ? 0.10 : 0.6);

    // Soft shadow beneath, offset down.
    canvas.drawRRect(
      caseR.shift(const Offset(0, 6)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // The case.
    canvas.drawRRect(
      caseR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[top, bottom],
        ).createShader(body),
    );
    // A faint highlight along the top-left edge: the case's own outline in
    // light, clipped to a thin band inside the edge.
    canvas.save();
    canvas.clipRRect(caseR);
    canvas.drawRRect(
      caseR.deflate(0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[highlight, highlight.withValues(alpha: 0)],
          stops: const <double>[0, 0.55],
        ).createShader(body),
    );
    canvas.restore();

    // The two side buttons: small light stadiums with the same shading.
    for (final double up in _btnUp) {
      final double cy = bh - up * k;
      final Rect br = Rect.fromLTWH(
        body.right - (_btnT - _btnProud) * k,
        cy - _btnL * k / 2,
        _btnT * k,
        _btnL * k,
      );
      final RRect b =
          RRect.fromRectAndRadius(br, Radius.circular(_btnT * k / 2));
      canvas.drawRRect(
        b.shift(const Offset(1, 1.5)),
        Paint()
          ..color = shadow.withValues(alpha: shadow.a * 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawRRect(
        b,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[top, bottom],
          ).createShader(br),
      );
    }

    // The window, slightly recessed: a darker inset edge, then the panel.
    final Rect winRect = Rect.fromCenter(
      center: Offset(body.center.dx, body.center.dy - _winLift * k),
      width: _winW * k,
      height: _winH * k,
    );
    final RRect winR =
        RRect.fromRectAndRadius(winRect, Radius.circular(_winR * k));
    canvas.drawRRect(winR, Paint()..color = done ? ink : panelEdge);
    if (!done) {
      canvas.drawRRect(winR.deflate(1), Paint()..color = panel);
    }

    if (done) {
      final double win = winRect.width;
      final Path path = Path()
        ..moveTo(winRect.left + win * 0.26, winRect.top + win * 0.55)
        ..lineTo(winRect.left + win * 0.44, winRect.top + win * 0.72)
        ..lineTo(winRect.left + win * 0.76, winRect.top + win * 0.34);
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
        style: word.copyWith(
          fontSize: winRect.width * 0.2,
          color: dark ? const Color(0xFF2A2825) : const Color(0xFF3A3733),
        ),
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
      old.done != done || old.check != check || old.dark != dark;
}
