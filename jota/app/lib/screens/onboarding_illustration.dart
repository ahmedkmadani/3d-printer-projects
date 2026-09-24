// ============================================================================
//  Jota — onboarding illustrations
//
//  Three beats of one idea, drawn with the product's one shape, the outline
//  circle, at the mark's own line weight:
//
//    stage 0  the head is full — the ring, crowded: seven thoughts inside it
//             and pressing at its edge, jostling, none of them in charge
//    stage 1  say it, let it out — the ring opens on the right, and one
//             thought is on its way out through the gap
//    stage 2  feel lighter — the ring alone, room around it, one thought
//             settled at rest inside and the others small and far away
//
//  Ink only, one stroke. Everything is composed in the design's 150x92 box and
//  scaled to fit, so the picture cannot drift with the screen.
//
//  Motion, two kinds, both quiet:
//  * an ENTRANCE when the page becomes the one on screen — the circles settle
//    into place from a little way off, 400 ms, staggered, easeOutCubic;
//  * the ambient LOOP the brand asks for on this one screen (docs/brand.md,
//    "Motion"): a slow drift, a breath, a thought travelling. 3–7 s.
//  Both stop dead under prefers-reduced-motion.
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/theme.dart';

class MindIllustration extends StatefulWidget {
  const MindIllustration({super.key, required this.stage, this.active = true});

  /// 0 = full, 1 = releasing, 2 = light.
  final int stage;

  /// True while this page is the one on screen. The entrance plays when it
  /// turns true, not when the page is built out of sight in a PageView.
  final bool active;

  @override
  State<MindIllustration> createState() => _MindIllustrationState();
}

class _MindIllustrationState extends State<MindIllustration>
    with TickerProviderStateMixin {
  static const List<Duration> _loop = <Duration>[
    Duration(seconds: 77),
    Duration(milliseconds: 4200),
    Duration(seconds: 10),
  ];

  late final AnimationController _loopC = AnimationController(
    vsync: this,
    duration: _loop[widget.stage],
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();
    _loopC.repeat();
    if (widget.active) _enter.forward();
  }

  @override
  void didUpdateWidget(MindIllustration old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _enter.forward(from: 0);
  }

  @override
  void dispose() {
    _loopC.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      return CustomPaint(
        painter: _MindPainter(line: c.ink, stage: widget.stage, t: 0, e: 1),
        child: const SizedBox.expand(),
      );
    }
    final CurvedAnimation e =
        CurvedAnimation(parent: _enter, curve: JotaMotion.curve);
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_loopC, e]),
      builder: (BuildContext context, Widget? child) => CustomPaint(
        painter: _MindPainter(
          line: c.ink,
          stage: widget.stage,
          t: _loopC.value,
          e: e.value,
        ),
        child: child,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// A circle in the picture: where it sits, its size, how present it is, how it
/// drifts (`turns` per loop, `delay` in fractions of a turn, `by` the whole
/// wander), and where it comes in from (`from`, an offset it settles from).
typedef _Circle = ({
  double cx,
  double cy,
  double r,
  double alpha,
  int turns,
  double delay,
  Offset by,
  Offset from,
  int order,
});

class _MindPainter extends CustomPainter {
  _MindPainter({
    required this.line,
    required this.stage,
    required this.t,
    required this.e,
  });

  final Color line;
  final int stage;

  /// Loop position, 0..1, wrapping.
  final double t;

  /// Entrance, 0..1, once.
  final double e;

  static const Size _design = Size(150, 92);
  static const Offset _drift = Offset(2.5, -3);
  static const Offset _drift2 = Offset(-3, 2.5);
  static const double _stroke = 1.5;

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
        _full(canvas);
      case 1:
        _release(canvas);
      default:
        _light(canvas);
    }
    canvas.restore();
  }

  Paint _ink(double alpha) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _stroke
    ..strokeCap = StrokeCap.round
    ..color = line.withValues(alpha: alpha.clamp(0.0, 1.0));

  double _swing(int turns, double delay) =>
      (1 - math.cos(2 * math.pi * (t * turns - delay))) / 2;

  /// The entrance for the n-th circle: staggered by 60 ms each, 0..1.
  double _arrive(int order) => ((e - order * 0.12) / 0.7).clamp(0.0, 1.0);

  void _circle(Canvas canvas, _Circle c) {
    final double a = _arrive(c.order);
    final double s = _swing(c.turns, c.delay);
    final Offset at =
        Offset(c.cx + c.by.dx * s, c.cy + c.by.dy * s) + c.from * (1 - a);
    canvas.drawCircle(at, c.r * (0.6 + 0.4 * a), _ink(c.alpha * a));
  }

  /// The head: the ring, at the mark's proportion.
  void _ring(
    Canvas canvas,
    Offset at,
    double r,
    double alpha, {
    double gapFrom = 0,
    double gapTo = 0,
  }) {
    final double a = _arrive(0);
    final double rr = r * (0.9 + 0.1 * a);
    if (gapTo <= gapFrom) {
      canvas.drawCircle(at, rr, _ink(alpha * a));
      return;
    }
    // A ring with an opening: drawn as one arc from the end of the gap round
    // to its start.
    canvas.drawArc(
      Rect.fromCircle(center: at, radius: rr),
      gapTo,
      2 * math.pi - (gapTo - gapFrom),
      false,
      _ink(alpha * a),
    );
  }

  /// When your head is full: the ring holds more than it can, thoughts
  /// pressing at its edge and over it, each jostling on its own time.
  void _full(Canvas canvas) {
    const Offset head = Offset(75, 46);
    _ring(canvas, head, 30, 1);
    const List<_Circle> crowd = <_Circle>[
      (
        cx: 68,
        cy: 40,
        r: 12,
        alpha: 1,
        turns: 14,
        delay: 0,
        by: _drift,
        from: Offset(-6, -4),
        order: 1
      ),
      (
        cx: 86,
        cy: 52,
        r: 9,
        alpha: 1,
        turns: 12,
        delay: .06,
        by: _drift2,
        from: Offset(6, 4),
        order: 2
      ),
      (
        cx: 60,
        cy: 58,
        r: 7,
        alpha: .8,
        turns: 11,
        delay: .13,
        by: _drift,
        from: Offset(-5, 5),
        order: 3
      ),
      (
        cx: 92,
        cy: 32,
        r: 6,
        alpha: .8,
        turns: 13,
        delay: .22,
        by: _drift2,
        from: Offset(5, -5),
        order: 4
      ),
      (
        cx: 78,
        cy: 24,
        r: 5,
        alpha: .7,
        turns: 12,
        delay: .3,
        by: _drift,
        from: Offset(0, -6),
        order: 5
      ),
      (
        cx: 102,
        cy: 58,
        r: 6,
        alpha: .6,
        turns: 11,
        delay: .4,
        by: _drift2,
        from: Offset(7, 2),
        order: 6
      ),
      (
        cx: 50,
        cy: 34,
        r: 5,
        alpha: .6,
        turns: 13,
        delay: .5,
        by: _drift,
        from: Offset(-7, 0),
        order: 7
      ),
    ];
    for (final _Circle c in crowd) {
      _circle(canvas, c);
    }
  }

  /// Say it, let it out: the ring opens on the right — the mouth of the head,
  /// if you like, though it is only a gap — and one thought goes out through
  /// it, fading as it goes. The rest stay, calmer than before.
  void _release(Canvas canvas) {
    const Offset head = Offset(62, 46);
    _ring(canvas, head, 30, 1, gapFrom: -0.45, gapTo: 0.45);
    const List<_Circle> left = <_Circle>[
      (
        cx: 56,
        cy: 38,
        r: 10,
        alpha: .9,
        turns: 1,
        delay: 0,
        by: _drift,
        from: Offset(-4, -3),
        order: 1
      ),
      (
        cx: 50,
        cy: 58,
        r: 6,
        alpha: .7,
        turns: 1,
        delay: .3,
        by: _drift2,
        from: Offset(-4, 3),
        order: 2
      ),
      (
        cx: 70,
        cy: 62,
        r: 5,
        alpha: .6,
        turns: 1,
        delay: .6,
        by: _drift,
        from: Offset(2, 4),
        order: 3
      ),
    ];
    for (final _Circle c in left) {
      _circle(canvas, c);
    }
    // The one leaving: out through the gap for the first 70% of the loop,
    // then simply not there — the pause is what makes it a departure.
    final double p = math.min(t / 0.7, 1.0);
    final double ease = (1 - math.cos(math.pi * p)) / 2;
    final double a = _arrive(2);
    canvas.drawCircle(
      Offset(78 + 46 * ease, 46 - 2 * ease),
      7 * a,
      _ink(0.95 * (1 - ease) * a),
    );
  }

  /// Feel lighter: the ring, alone, with room round it; one thought at rest
  /// inside, and what left now small and far off, still drifting away.
  void _light(Canvas canvas) {
    const Offset head = Offset(75, 46);
    final double breath = _swing(2, 0);
    _ring(canvas, head, 30 * (1 + 0.04 * breath), 1 - 0.12 * breath);
    canvas.drawCircle(
      const Offset(72, 44),
      8 * _arrive(1),
      _ink(0.9 * _arrive(1)),
    );
    final double gone = 0.45 - 0.3 * _swing(1, 0);
    const List<_Circle> far = <_Circle>[
      (
        cx: 20,
        cy: 26,
        r: 4,
        alpha: 1,
        turns: 2,
        delay: 0,
        by: _drift,
        from: Offset(6, 3),
        order: 2
      ),
      (
        cx: 134,
        cy: 66,
        r: 5,
        alpha: 1,
        turns: 1,
        delay: 0,
        by: _drift2,
        from: Offset(-6, -3),
        order: 3
      ),
    ];
    for (final _Circle c in far) {
      _circle(
        canvas,
        (
          cx: c.cx,
          cy: c.cy,
          r: c.r,
          alpha: gone,
          turns: c.turns,
          delay: c.delay,
          by: c.by,
          from: c.from,
          order: c.order,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_MindPainter old) =>
      old.stage != stage || old.line != line || old.t != t || old.e != e;
}
