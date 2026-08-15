// ============================================================================
//  Jota — onboarding illustrations
//
//  Three beats of the one idea, drawn with a single shape: an outline circle.
//
//    stage 0  the crowd — several circles overlapping, each drifting on its own
//             slow phase, none of them still, none of them the main one
//    stage 1  one of them leaves — it travels out of the ring and fades, and a
//             faint circle is already waiting where it lands
//    stage 2  what is left — one ring breathing, the rest drifting out of sight
//
//  Ink only. The previous version washed the head in `signal` and drew half the
//  waves, both dots and the travelling thought in it. `signal` means LIVE or
//  DANGEROUS (brand.md) — spending it on decoration is exactly what made it
//  read as random, and an onboarding page has nothing live or dangerous on it.
//  It also drew a head with waves inside, which is a diagram of a head; the
//  locked design says a crowd of plain circles, so that is what this draws.
//
//  Everything is laid out in the design's own 150x92 box and scaled to fit, so
//  the composition cannot drift from the artifact as the box changes; the 1.5
//  stroke scales with it and stays the one line weight.
//
//  They MOVE, slowly — a crowd is restless, a thought leaving travels, and what
//  remains breathes. The loops run 3.4-7 s per element and stop dead under
//  prefers-reduced-motion.
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/theme.dart';

class MindIllustration extends StatefulWidget {
  const MindIllustration({super.key, required this.stage});

  /// 0 = full, 1 = releasing, 2 = light.
  final int stage;

  @override
  State<MindIllustration> createState() => _MindIllustrationState();
}

class _MindIllustrationState extends State<MindIllustration>
    with SingleTickerProviderStateMixin {
  /// One turn of the whole page. Each element then runs at a whole number of
  /// turns inside it, which is what lets five circles keep five different
  /// periods (5.50, 5.92, 6.42, 7.00 s) and still meet exactly at the seam —
  /// no jump every time the controller wraps.
  static const List<Duration> _loop = <Duration>[
    Duration(seconds: 77),
    Duration(milliseconds: 3400),
    Duration(seconds: 10),
  ];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _loop[widget.stage],
  );

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    // Someone who has asked the OS for less motion has asked for less motion.
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      return CustomPaint(
        painter: _MindPainter(line: c.ink, stage: widget.stage, t: 0),
        child: const SizedBox.expand(),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) => CustomPaint(
        painter: _MindPainter(line: c.ink, stage: widget.stage, t: _c.value),
        child: child,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// A circle in the crowd: where it sits, how present it is, and how it drifts —
/// `turns` per loop, `delay` in fractions of its own turn, `by` the whole
/// distance it wanders and comes back from.
typedef _Drifter = ({
  double cx,
  double cy,
  double r,
  double alpha,
  int turns,
  double delay,
  Offset by,
});

class _MindPainter extends CustomPainter {
  _MindPainter({required this.line, required this.stage, required this.t});

  final Color line;
  final int stage;

  /// 0..1, wrapping. Every motion below is a function of this and nothing
  /// else, so the drawing is still pure and still testable at any frame.
  final double t;

  /// The box the locked design draws in. Held here rather than derived from
  /// the widget so the five stage-0 circles keep the spacing they were
  /// composed with instead of being re-invented per screen size.
  static const Size _design = Size(150, 92);

  static const Offset _drift = Offset(3, -4);
  static const Offset _drift2 = Offset(-4, 3);

  @override
  void paint(Canvas canvas, Size size) {
    final double k = math.min(
      size.width / _design.width,
      size.height / _design.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - _design.width * k) / 2,
      (size.height - _design.height * k) / 2,
    );
    canvas.scale(k);

    switch (stage) {
      case 0:
        _crowd(canvas);
      case 1:
        _release(canvas);
      default:
        _calm(canvas);
    }
    canvas.restore();
  }

  Paint _ink(double alpha) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = line.withValues(alpha: alpha);

  /// Out and back, 0 → 1 → 0, easing at both ends — the shape of every drift
  /// and breath here. Whole `turns` keep it continuous across the wrap.
  double _swing(int turns, double delay) =>
      (1 - math.cos(2 * math.pi * (t * turns - delay))) / 2;

  void _drifter(Canvas canvas, _Drifter d) {
    final double s = _swing(d.turns, d.delay);
    canvas.drawCircle(
      Offset(d.cx + d.by.dx * s, d.cy + d.by.dy * s),
      d.r,
      _ink(d.alpha),
    );
  }

  /// The moment: five circles, overlapping, no one of them in charge. They
  /// never drift together — that is the whole point of the picture.
  void _crowd(Canvas canvas) {
    const List<_Drifter> crowd = <_Drifter>[
      (cx: 58, cy: 38, r: 18, alpha: 1, turns: 14, delay: 0, by: _drift),
      (cx: 86, cy: 48, r: 22, alpha: 1, turns: 12, delay: 0.06, by: _drift2),
      (cx: 70, cy: 60, r: 13, alpha: .70, turns: 11, delay: 0.13, by: _drift),
      (cx: 98, cy: 32, r: 10, alpha: .55, turns: 13, delay: 0.22, by: _drift2),
      (cx: 46, cy: 58, r: 8, alpha: .40, turns: 12, delay: 0.06, by: _drift2),
    ];
    for (final _Drifter d in crowd) {
      _drifter(canvas, d);
    }
  }

  /// The answer: one circle leaves the ring, fades on the way, and something
  /// faint is already holding the place it is going to.
  void _release(Canvas canvas) {
    _breathe(canvas, const Offset(56, 46), 26, 1);

    // It travels for the first 70% of the loop and then simply is not there:
    // the pause is what makes it a departure rather than a shuttle.
    final double p = math.min(t / 0.7, 1.0);
    final double e = (1 - math.cos(math.pi * p)) / 2;
    canvas.drawCircle(Offset(56 + 26 * e, 46), 9, _ink(0.9 * (1 - e)));

    canvas.drawCircle(const Offset(112, 46), 12, _ink(0.35));
  }

  /// Coming back: one ring, calm, and two circles on their way out — still
  /// drifting, but down to almost nothing.
  void _calm(Canvas canvas) {
    _breathe(canvas, const Offset(75, 46), 27, 2);

    final double gone = 0.5 - 0.38 * _swing(1, 0);
    _drifter(
      canvas,
      (cx: 26, cy: 30, r: 7, alpha: gone, turns: 2, delay: 0, by: _drift),
    );
    _drifter(
      canvas,
      (cx: 128, cy: 58, r: 9, alpha: gone, turns: 1, delay: 0, by: _drift2),
    );
  }

  /// A ring that breathes: 6% wider and a shade lighter at the top of the
  /// breath. Small enough that you feel it rather than watch it.
  void _breathe(Canvas canvas, Offset at, double r, int turns) {
    final double s = _swing(turns, 0);
    canvas.drawCircle(at, r * (1 + 0.06 * s), _ink(1 - 0.15 * s));
  }

  @override
  bool shouldRepaint(_MindPainter old) =>
      old.stage != stage || old.line != line || old.t != t;
}
