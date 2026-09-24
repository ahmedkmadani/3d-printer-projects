// ============================================================================
//  Jota — the marks
//
//  One source for every drawn mark in the product: the launcher icon, the
//  splash, and the small marks that stand in for an empty screen. The
//  numbers here are the numbers tool/make_icon.py renders the icon from, so
//  the thing a person taps and the thing they then see are one thing.
//
//  THE MARK is a ring with thoughts in it. `Jota` is Sudanese Arabic for
//  *many thoughts, all at once* (docs/brand.md): the ring is your head, the
//  same hairline ring the device draws round its wordmark when it sleeps,
//  and the five dots of unequal size, unequally placed, are what is in it.
//  It was a paper disc with the dots and no ring, and on a pale wallpaper
//  the disc's edge vanished and the dots floated; the ring gives the head
//  an edge on any background, in either theme, and ties the phone to the
//  panel.
//
//  Two rules that are not stylistic:
//
//  * NO TWO DOTS SHARE A HEIGHT, and no pair mirrors across the vertical
//    axis. Two level dots either side of a large one read as a FACE. Tidying
//    these numbers into anything symmetrical brings the face straight back.
//
//  * The mark is STILL wherever it is decoration. It draws itself in once, on
//    the splash, and that is the only motion it has: brand.md asks for a
//    notebook, not a gadget.
// ============================================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// One thought: centre and radius as fractions of the mark's diameter.
@immutable
class Thought {
  const Thought(this.x, this.y, this.r);

  final double x;
  final double y;
  final double r;
}

/// The five thoughts, largest first. Held inside radius 0.33 of centre so the
/// furthest edge (0.37) clears the ring at [kMarkRing] with its stroke.
/// SAME NUMBERS AS tool/make_icon.py — change both or neither.
const List<Thought> kThoughts = <Thought>[
  Thought(0.395, 0.415, 0.098),
  Thought(0.585, 0.600, 0.070),
  Thought(0.660, 0.335, 0.055),
  Thought(0.315, 0.640, 0.040),
  Thought(0.470, 0.235, 0.030),
];

/// The ring's radius and stroke, as fractions of the diameter. The stroke is
/// a hairline at chip size and a confident line at splash size — it scales,
/// which is what keeps the mark one drawing rather than two.
const double kMarkRing = 0.44;
const double kMarkStroke = 0.032;

/// The mark, still or part-drawn.
///
/// [progress] is how much of it exists: 0 is nothing, 1 is the whole mark.
/// The ring sweeps clockwise from 12 o'clock over the first three fifths, the
/// way the device's charge arc is read, and the thoughts arrive one by one,
/// largest first, over the rest.
class JotaMark extends StatelessWidget {
  const JotaMark({
    super.key,
    this.size = 40,
    this.color,
    this.progress = 1,
  });

  final double size;

  /// Defaults to `ink`; pass `onInk` on a filled shape.
  final Color? color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: MarkPainter(
          ink: color ?? context.ink.ink,
          progress: progress.clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

/// The mark drawing itself in once, then holding. The splash's only motion.
class JotaMarkDrawing extends StatefulWidget {
  const JotaMarkDrawing({
    super.key,
    this.size = 132,
    this.duration = const Duration(milliseconds: 600),
    this.onDone,
  });

  final double size;
  final Duration duration;
  final VoidCallback? onDone;

  @override
  State<JotaMarkDrawing> createState() => _JotaMarkDrawingState();
}

class _JotaMarkDrawingState extends State<JotaMarkDrawing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    // Reduce motion: the finished mark, at once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (still) {
        _c.value = 1;
        widget.onDone?.call();
      } else {
        _c.forward().whenComplete(() => widget.onDone?.call());
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = context.ink.ink;
    final CurvedAnimation a =
        CurvedAnimation(parent: _c, curve: JotaMotion.curve);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: a,
        builder: (BuildContext context, _) => CustomPaint(
          painter: MarkPainter(ink: ink, progress: a.value),
        ),
      ),
    );
  }
}

class MarkPainter extends CustomPainter {
  const MarkPainter({required this.ink, this.progress = 1});

  final Color ink;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double d = math.min(size.width, size.height);
    final Offset c = Offset(size.width / 2, size.height / 2);

    // The ring: a sweep from 12 o'clock, clockwise.
    final double ringPart = (progress / 0.6).clamp(0.0, 1.0);
    if (ringPart > 0) {
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kMarkStroke * d
        ..strokeCap = StrokeCap.round
        ..color = ink;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: kMarkRing * d),
        -math.pi / 2,
        2 * math.pi * ringPart,
        false,
        ring,
      );
    }

    // The thoughts: one after another, each growing from nothing.
    final Paint dot = Paint()..color = ink;
    for (int i = 0; i < kThoughts.length; i++) {
      final double start = 0.5 + i * 0.1;
      final double k = ((progress - start) / 0.12).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final Thought t = kThoughts[i];
      canvas.drawCircle(
        Offset(c.dx + (t.x - 0.5) * d, c.dy + (t.y - 0.5) * d),
        t.r * d * k,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(MarkPainter old) =>
      old.ink != ink || old.progress != progress;
}

// ---- Empty-state marks -----------------------------------------------------

/// What an empty screen is empty of. One family: the head, with one thought
/// in a different place — or none.
enum EmptyMark {
  /// Nothing recorded: the ring alone.
  nothing,

  /// Nothing matches: the thought is there, off to one side of where you
  /// looked.
  noMatch,

  /// No tags: the thought sits low, unfiled.
  noTags,

  /// No patterns: a thought at the top, on its own, not yet a pattern.
  noPatterns,
}

/// A small hairline ring, 28pt, with at most one thought in it. Drawn in the
/// muted ink, because an empty screen is quiet by definition.
class JotaEmptyMarkView extends StatelessWidget {
  const JotaEmptyMarkView(this.kind, {super.key, this.size = 28});

  final EmptyMark kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EmptyMarkPainter(ink: context.ink.inkMuted, kind: kind),
      ),
    );
  }
}

class _EmptyMarkPainter extends CustomPainter {
  const _EmptyMarkPainter({required this.ink, required this.kind});

  final Color ink;
  final EmptyMark kind;

  @override
  void paint(Canvas canvas, Size size) {
    final double d = math.min(size.width, size.height);
    final Offset c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      c,
      d * 0.44,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = JotaGrid.hairline
        ..color = ink,
    );
    final Offset? at = switch (kind) {
      EmptyMark.nothing => null,
      EmptyMark.noMatch => const Offset(0.20, 0.06),
      EmptyMark.noTags => const Offset(-0.12, 0.20),
      EmptyMark.noPatterns => const Offset(0.02, -0.22),
    };
    if (at != null) {
      canvas.drawCircle(
        Offset(c.dx + at.dx * d, c.dy + at.dy * d),
        d * 0.075,
        Paint()..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(_EmptyMarkPainter old) =>
      old.ink != ink || old.kind != kind;
}
