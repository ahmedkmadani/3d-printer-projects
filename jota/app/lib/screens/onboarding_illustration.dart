// ============================================================================
//  Jota — onboarding illustrations
//
//  Three hand-drawn beats of the one idea Jota is about: a head too full, then
//  the thoughts streaming out, then a head that has cleared. Painted, not
//  imported — so they live in the same warm palette as everything else: an
//  espresso line, a soft clay wash for the thoughts, cream underneath. Soft and
//  human, never a spec drawing.
//
//    stage 0  a crowded mind — a tangle packed inside
//    stage 1  letting it out — one line streams out and settles below
//    stage 2  lighter — a clear head but for a calm curve; thoughts drift off
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/theme.dart';

class MindIllustration extends StatelessWidget {
  const MindIllustration({super.key, required this.stage});

  /// 0 = full, 1 = releasing, 2 = light.
  final int stage;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return CustomPaint(
      painter: _MindPainter(line: c.ink, accent: c.signal, stage: stage),
    );
  }
}

class _MindPainter extends CustomPainter {
  _MindPainter({required this.line, required this.accent, required this.stage});

  final Color line;
  final Color accent;
  final int stage;

  late final Paint _ink;
  late final Paint _clay;
  late final Paint _clayDot;

  Paint _stroke(Color color, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width, size.height);
    final Offset ctr = Offset(size.width / 2, size.height * 0.44);
    final double r = s * 0.28;
    final double w = s * 0.013;

    _ink = _stroke(line, w);
    _clay = _stroke(accent, w);
    _clayDot = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: 0.55);

    // The mind: one soft circle, warm-washed, espresso outline.
    final Paint wash = Paint()
      ..style = PaintingStyle.fill
      ..color = accent.withValues(alpha: 0.10);
    canvas.drawCircle(ctr, r, wash);
    canvas.drawCircle(ctr, r, _ink);

    switch (stage) {
      case 0:
        _full(canvas, ctr, r);
      case 1:
        _release(canvas, ctr, r);
      default:
        _light(canvas, ctr, r);
    }
  }

  void _clip(Canvas canvas, Offset ctr, double r) {
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: ctr, radius: r * 0.98)),
    );
  }

  /// A wavy line across the head, `freq` humps, `amp` fraction of r tall.
  Path _wave(Offset ctr, double r, double y, double freq, double amp) {
    final Path p = Path();
    for (double t = 0; t <= 1.0001; t += 0.04) {
      final double x = ctr.dx - r + 2 * r * t;
      final double yy = y + math.sin(t * math.pi * freq) * r * amp;
      if (t == 0) {
        p.moveTo(x, yy);
      } else {
        p.lineTo(x, yy);
      }
    }
    return p;
  }

  /// A crowded head: a tangle of wavy lines packed inside, a couple of knots.
  void _full(Canvas canvas, Offset ctr, double r) {
    canvas.save();
    _clip(canvas, ctr, r);
    for (int i = 0; i < 6; i++) {
      final double y = ctr.dy - r * 0.7 + (r * 1.4) * (i / 5);
      canvas.drawPath(_wave(ctr, r, y, 3.0 + i, 0.13), i.isEven ? _ink : _clay);
    }
    canvas.restore();
    canvas.drawCircle(ctr.translate(-r * 0.35, -r * 0.35), r * 0.08, _clayDot);
    canvas.drawCircle(ctr.translate(r * 0.4, r * 0.25), r * 0.06, _clayDot);
  }

  /// Letting it out: the head quiets, one line streams out and pools below.
  void _release(Canvas canvas, Offset ctr, double r) {
    canvas.save();
    _clip(canvas, ctr, r);
    canvas.drawPath(_wave(ctr, r, ctr.dy - r * 0.45, 3, 0.10), _ink);
    canvas.drawPath(_wave(ctr, r, ctr.dy + r * 0.05, 3, 0.10), _ink);
    canvas.restore();

    final Offset pooled = ctr.translate(r * 0.15, r * 2.15);
    final Path stream = Path()..moveTo(ctr.dx + r * 0.1, ctr.dy + r * 0.2);
    stream.cubicTo(
      ctr.dx + r * 0.9,
      ctr.dy + r * 0.9,
      ctr.dx - r * 0.7,
      ctr.dy + r * 1.6,
      pooled.dx,
      pooled.dy,
    );
    canvas.drawPath(stream, _clay);
    canvas.drawCircle(pooled, r * 0.10, _clayDot);
  }

  /// Lighter: a clear head but for a calm curve; a few marks drift up and fade.
  void _light(Canvas canvas, Offset ctr, double r) {
    final Path calm = Path()..moveTo(ctr.dx - r * 0.45, ctr.dy + r * 0.05);
    calm.quadraticBezierTo(
      ctr.dx,
      ctr.dy + r * 0.4,
      ctr.dx + r * 0.45,
      ctr.dy + r * 0.05,
    );
    canvas.drawPath(calm, _ink);

    for (int i = 0; i < 3; i++) {
      final double up = r * (1.25 + i * 0.55);
      final double rad = r * (0.10 - i * 0.02);
      final Paint fade = Paint()
        ..style = PaintingStyle.fill
        ..color = accent.withValues(alpha: 0.5 - i * 0.15);
      canvas.drawCircle(ctr.translate(r * 0.35 * (i - 1), -up), rad, fade);
    }
  }

  @override
  bool shouldRepaint(_MindPainter old) =>
      old.stage != stage || old.line != line || old.accent != accent;
}
