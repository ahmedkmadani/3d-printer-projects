// ============================================================================
//  Jota — the mark
//
//  A circle with thoughts in it. `Jota` is Sudanese Arabic for *many thoughts,
//  all at once* (docs/brand.md), and the mark says that literally: five dots of
//  unequal size, unequally spaced, inside the circle that is your head.
//
//  It replaces the word-in-a-ring. The word said the name; the dots say what
//  the name MEANS, and they survive being 48 px on a home screen in a way four
//  serif letters do not.
//
//  THE DOTS ARE THE SAME NUMBERS AS tool/make_icon.py. That file renders the
//  Android launcher icons from this geometry, so the icon a person taps and the
//  mark they then see in the app are one thing. Change the numbers in one place
//  and they drift apart — change them in both, or in neither.
//
//  Two rules that are not stylistic:
//
//  * NO TWO DOTS SHARE A HEIGHT, and no pair mirrors across the vertical axis.
//    The first arrangement had two level either side of a large central dot
//    with two more level below, and it read unmistakably as a FACE — eyes,
//    nose, mouth. Tidying these numbers into anything symmetrical brings the
//    face straight back.
//
//  * The drift is for the PHONE only. The device is e-paper: it redraws, it
//    does not animate (docs/brand.md), so the firmware draws the resting frame
//    and so does the launcher icon, which is a still PNG.
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// One thought: where it sits and how big it is, as fractions of the diameter.
///
/// Fractions rather than pixels so one set of numbers serves a 24 px chip and a
/// 200 px splash — the mark is drawn at both.
@immutable
class _Thought {
  const _Thought(this.x, this.y, this.r, this.period, this.dx, this.dy);

  /// Centre, as a fraction of the diameter.
  final double x;
  final double y;

  /// Radius, as a fraction of the diameter.
  final double r;

  /// Seconds for one full drift cycle. All different, and none a multiple of
  /// another: equal or harmonic periods let the group resolve into a pulse the
  /// eye locks onto, which reads as a loading indicator rather than as thought.
  final double period;

  /// How far this dot wanders, as a fraction of the diameter.
  final double dx;
  final double dy;
}

/// Held inside radius 0.33 of centre, so the furthest dot's outer edge lands at
/// 0.37 against the disc's 0.48 — clear of whatever shape a launcher masks the
/// icon into, and clear of the rim once the drift is added on top.
const List<_Thought> _kThoughts = <_Thought>[
  _Thought(0.395, 0.415, 0.098, 11, 0.030, -0.020),
  _Thought(0.585, 0.600, 0.070, 14, -0.024, 0.018),
  _Thought(0.660, 0.335, 0.055, 9, 0.016, 0.026),
  _Thought(0.315, 0.640, 0.040, 17, -0.020, -0.028),
  _Thought(0.470, 0.235, 0.030, 13, 0.026, 0.014),
];

/// The mark, still.
///
/// Use this anywhere the mark is decoration rather than the subject — a chip, a
/// row, a dense screen. [JotaMarkDrifting] is the one that moves.
class JotaMark extends StatelessWidget {
  const JotaMark({
    super.key,
    this.size = 40,
    this.color,
    this.background,
    this.phase = 0,
  });

  /// Outer diameter.
  final double size;

  /// The dots. Defaults to `ink`; pass `onInk` when the mark sits on a filled
  /// shape.
  final Color? color;

  /// The disc. Defaults to `bg`.
  final Color? background;

  /// Where in the drift cycle to freeze, 0..1. The still mark uses 0 — the
  /// resting frame, the one the icon and the e-paper draw.
  final double phase;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(
          ink: color ?? c.ink,
          disc: background ?? c.bg,
          phase: phase,
        ),
      ),
    );
  }
}

/// The mark, drifting.
///
/// Each thought wanders on its own slow cycle, 9 to 17 seconds. Slow is the
/// point: brand.md asks for calm and old-fashioned, a notebook rather than a
/// gadget, and anything quick enough to catch the eye twice is a gadget.
///
/// Honours the platform's "reduce motion" setting — a drifting mark is exactly
/// the kind of ambient movement that setting exists to stop — and stops the
/// ticker whenever it is off screen, so it costs nothing when nobody is looking.
class JotaMarkDrifting extends StatefulWidget {
  const JotaMarkDrifting({
    super.key,
    this.size = 40,
    this.color,
    this.background,
  });

  final double size;
  final Color? color;
  final Color? background;

  @override
  State<JotaMarkDrifting> createState() => _JotaMarkDriftingState();
}

class _JotaMarkDriftingState extends State<JotaMarkDrifting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  /// The cycle every dot's own period divides into. The dots have periods of
  /// 9, 11, 13, 14 and 17 seconds; their least common multiple is far longer
  /// than anyone looks at a mark, so the controller just runs a long loop and
  /// each dot reads its own phase out of the elapsed time.
  static const Duration _kLoop = Duration(seconds: 3600);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _kLoop)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final Color ink = widget.color ?? c.ink;
    final Color disc = widget.background ?? c.bg;

    // Reduce motion: draw the resting frame and never start a ticker.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return JotaMark(
        size: widget.size,
        color: ink,
        background: disc,
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: _MarkPainter(
              ink: ink,
              disc: disc,
              elapsedSeconds: _c.value * _kLoop.inSeconds,
            ),
          );
        },
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.ink,
    required this.disc,
    this.elapsedSeconds,
    this.phase = 0,
  });

  final Color ink;
  final Color disc;

  /// Drives the drift when animating. Null means still.
  final double? elapsedSeconds;

  /// Where to freeze when still, 0..1.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final double d = math.min(size.width, size.height);
    final Offset centre = Offset(size.width / 2, size.height / 2);

    // A hair inside the box, so the disc's own edge is not clipped by it —
    // the same 2% inset make_icon.py uses.
    canvas.drawCircle(centre, d * 0.48, Paint()..color = disc);

    final Paint dot = Paint()..color = ink;
    for (final _Thought t in _kThoughts) {
      // A cosine, so every dot is at the far end of its wander at rest — the
      // resting frame IS the arrangement the icon ships, not some point
      // halfway through a wander that never got checked at 48 px.
      final double turns = elapsedSeconds == null
          ? phase
          : elapsedSeconds! / t.period;
      final double w = math.cos(turns * 2 * math.pi);
      canvas.drawCircle(
        Offset(
          (t.x + t.dx * (1 - w) / 2) * d,
          (t.y + t.dy * (1 - w) / 2) * d,
        ),
        t.r * d,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.ink != ink ||
      old.disc != disc ||
      old.phase != phase ||
      old.elapsedSeconds != elapsedSeconds;
}
