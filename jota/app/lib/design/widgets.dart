// ============================================================================
//  Jota — widget primitives (phone)
//
//  The sibling of firmware/src/ui/widgets.h. Same component set, same names,
//  so a screen written against one reads like a screen written against the
//  other: rule, statusBar, bigFigure, row, list, ring, progressBar, dots.
//
//  Every one of these draws from lib/design/theme.dart and holds no colours,
//  sizes or radii of its own.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'theme.dart';

// ---- rule ------------------------------------------------------------------
// widgets.h: rule(). One hairline. It is the only divider in the app and it is
// always this weight and this colour.
class JotaRule extends StatelessWidget {
  const JotaRule({super.key, this.indent = 0, this.color});

  final double indent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: indent),
      child: Container(
        height: JotaGrid.hairline,
        color: color ?? context.ink.rule,
      ),
    );
  }
}

/// The heavier rule under a status bar and under a big figure. The device
/// draws this at full ink; so do we.
class JotaRuleStrong extends StatelessWidget {
  const JotaRuleStrong({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: JotaGrid.hairline, color: context.ink.ink);
  }
}

// ---- statusBar -------------------------------------------------------------
// widgets.h: statusBar(left, right).
//
// STATUS RIGHT SLOT RULE, inherited verbatim from screens.cpp: the right slot
// always holds the screen's ONE defining figure. A count on the note list, a
// ratio while syncing, a position in a note. Never decoration, never two
// things. If a screen has no defining figure, the slot is empty.
//
// WHICH EDGE. The device owns its whole panel, so its status line runs label
// left, figure right. The phone does not: the OS has already written the time,
// the battery and the carrier across the top, and that band sits directly above
// this row. The app used to answer it by planting its own label hard left,
// where it lined up under the clock and read as a second, competing system
// line. So the whole app group — label, dot, figure — is set to the RIGHT edge,
// as drawn, and the left is left to the phone. The one exception is the back
// chevron: a way back belongs under the thumb on the left, and it is an
// affordance rather than a piece of the status text.
class JotaStatusBar extends StatelessWidget {
  const JotaStatusBar({
    super.key,
    required this.label,
    this.value,
    this.onBack,
    this.trailing,
    this.showSignalDot = false,
    this.upcase = true,
    this.rule = true,
  });

  /// What this screen is. `label` role, uppercased unless a screen in the
  /// handwriting voice opts out. Empty on screens that title themselves in the
  /// body, and then nothing is drawn — not an empty box holding a gap open.
  final String label;

  /// See [JotaButton.upcase]. Defaults true so existing screens are untouched.
  final bool upcase;

  /// The one defining figure, drawn last in the right-hand group. `reading`
  /// role — lighter than the label, because it is data and the label is chrome.
  final String? value;

  /// Back affordance. The device uses a long-press; the phone gets a chevron.
  final VoidCallback? onBack;

  /// Replaces the value slot entirely when a screen needs an action there.
  final Widget? trailing;

  /// The signal dot — "the device is holding notes for you". One of exactly
  /// two places the accent colour is allowed to appear.
  final bool showSignalDot;

  /// Draw the strong hairline beneath the status line. False on screens whose
  /// heading lives in the body and is ruled there instead — one hairline is
  /// the whole chrome, and the only question is which one.
  final bool rule;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;

    // Nothing to say and no line to draw: take no room at all. On the mock the
    // strip is never truly empty because the phone's own clock is drawn inside
    // it; on a real phone that clock lives above the safe area, so an empty
    // strip is 40pt of blank paper fenced off above the actual heading.
    if (label.isEmpty &&
        value == null &&
        trailing == null &&
        onBack == null &&
        !showSignalDot &&
        !rule) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: JotaGrid.statusHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (onBack != null)
                _StatusIconButton(
                  icon: LucideIcons.arrowLeft,
                  onTap: onBack!,
                  semanticLabel: 'Back',
                ),
              // Expanded, then aligned to its end: the group hugs the right
              // edge whatever it contains, and the label — the only part that
              // can run long — is the only part allowed to give up width.
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: JotaGrid.gapS,
                  children: <Widget>[
                    if (label.isNotEmpty)
                      Flexible(
                        child: Text(
                          upcase ? label.toUpperCase() : label,
                          // Mono and muted, like every other word in this
                          // strip. Right-aligning the group put these labels
                          // in the slot the design fills with 9px mono muted,
                          // beside figures like `4 WEEKS` and `N-012` — in
                          // sans ink they read as a different system's
                          // heading. `JOTA` is an identifier besides, and
                          // brand.md puts every identifier in mono.
                          style: t.reading.copyWith(
                            color: c.inkMuted,
                            letterSpacing: 0.8,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (showSignalDot)
                      Container(
                        width: JotaIndicators.signalDot,
                        height: JotaIndicators.signalDot,
                        decoration: BoxDecoration(
                          color: c.signal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (trailing != null)
                      trailing!
                    else if (value != null)
                      Text(
                        value!,
                        style: t.reading.copyWith(color: c.inkMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Screens whose title lives in the BODY draw their own hairline under
        // it, and a second rule up here would fence off a status line that is
        // only holding the app's name. One hairline is the whole chrome — the
        // question is only which one.
        if (rule) ...<Widget>[
          const SizedBox(height: JotaGrid.statusRuleGap),
          const JotaRuleStrong(),
        ],
      ],
    );
  }
}

class _StatusIconButton extends StatelessWidget {
  const _StatusIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: JotaGrid.gapM),
          child: Icon(icon, size: 18, color: context.ink.ink),
        ),
      ),
    );
  }
}

// ---- scaffold --------------------------------------------------------------
// Every screen is a status bar, a hairline, and then one idea. The device has
// exactly this much chrome and nothing else; the app does not get a bottom nav
// bar, a tab strip or a floating button.
class JotaScreen extends StatelessWidget {
  const JotaScreen({
    super.key,
    required this.label,
    this.value,
    this.onBack,
    this.trailing,
    this.showSignalDot = false,
    required this.child,
    this.footer,
    this.padded = true,
    this.upcase = true,
    this.rule = true,
  });

  final String label;
  final String? value;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showSignalDot;

  /// Draw the strong hairline under the status line. False on screens that
  /// carry their heading in the body and rule it there instead.
  final bool rule;

  final Widget child;

  /// See [JotaButton.upcase]. Forwarded to the status bar's label.
  final bool upcase;

  /// Pinned to the bottom, above the safe area. Used for the primary action.
  final Widget? footer;

  /// Set false when the child manages its own horizontal insets (a ListView
  /// that must bleed its dividers to the full width).
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ink.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                JotaGrid.margin,
                JotaGrid.gapS,
                JotaGrid.margin,
                0,
              ),
              child: JotaStatusBar(
                label: label,
                value: value,
                onBack: onBack,
                trailing: trailing,
                showSignalDot: showSignalDot,
                upcase: upcase,
                rule: rule,
              ),
            ),
            Expanded(
              child: padded
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: JotaGrid.margin,
                      ),
                      child: child,
                    )
                  : child,
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  JotaGrid.margin,
                  JotaGrid.gapM,
                  JotaGrid.margin,
                  JotaGrid.gapM,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

// ---- row / list ------------------------------------------------------------
// widgets.h: row(), list().
//
// The one list component. Radius is always height/2, so every row is a
// stadium. SELECTION IS SHOWN BY INVERSION — filled ink with a knocked-out
// label — never by a tint, a border weight or a leading checkmark. This is the
// single most recognisable thing the device does and it transfers unchanged.
class JotaRow extends StatelessWidget {
  const JotaRow({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.height = JotaRows.height,
    this.enabled = true,
    this.leading,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double height;
  final bool enabled;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;

    final Color fg = selected
        ? c.onInk
        : enabled
            ? c.ink
            : c.inkMuted;

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: JotaPressable(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: JotaMotion.fast,
          curve: JotaMotion.curve,
          height: height,
          decoration: BoxDecoration(
            color: selected ? c.ink : Colors.transparent,
            borderRadius: JotaRows.borderRadiusOf(height),
            border: Border.all(
              color: selected ? c.ink : (enabled ? c.ink : c.rule),
              width: JotaGrid.hairline,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: JotaGrid.gapM),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: JotaGrid.gapS),
              ],
              Expanded(
                child: Text(
                  label,
                  textAlign: leading == null && trailing == null
                      ? TextAlign.center
                      : TextAlign.left,
                  style: t.label.copyWith(color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: JotaGrid.gapS),
                DefaultTextStyle(
                  style: t.reading.copyWith(color: fg),
                  child: IconTheme(
                    data: IconThemeData(color: fg, size: 16),
                    child: trailing!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// widgets.h: list(). A column of stadium rows with exactly one selected.
class JotaList extends StatelessWidget {
  const JotaList({
    super.key,
    required this.items,
    this.selected,
    this.onSelect,
    this.height = JotaRows.height,
  });

  final List<String> items;
  final int? selected;
  final ValueChanged<int>? onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: JotaRows.gap),
          JotaRow(
            label: items[i],
            selected: selected == i,
            height: height,
            onTap: onSelect == null ? null : () => onSelect!(i),
          ),
        ],
      ],
    );
  }
}

// ---- button ----------------------------------------------------------------
// A row with a job. Primary is the inverted form (filled ink), which is the
// same visual as a selected row — deliberately, because "the thing you are
// about to do" and "the thing that is chosen" are the same idea.
class JotaButton extends StatelessWidget {
  const JotaButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = false,
    this.height = JotaRows.height,
    this.busy = false,
    this.danger = false,
    this.upcase = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double height;
  final bool busy;

  /// The device shouts in caps because a 1-bit panel has no case contrast to
  /// spare. The phone's handwriting face reads far better in Title case, so
  /// screens set in that voice (onboarding, pair) pass `upcase: false`. Defaults
  /// true so every existing screen is untouched.
  final bool upcase;

  /// Destructive actions get the signal colour for their *label only* — never
  /// a red fill. The app does not shout.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    final bool enabled = onTap != null && !busy;

    // A primary CTA always reads as a solid pill — filled ink when live, a soft
    // filled `field` when not — never a thin hollow outline, which looks flimsy
    // for the one action a screen is asking for. Secondary buttons stay outline.
    final Color fill = enabled
        ? (primary ? c.ink : Colors.transparent)
        : (primary ? c.field : Colors.transparent);
    // A danger control's OUTLINE carries the warning too, not just its label.
    // The border used to stay ink while the text went to signal, so at a
    // glance the one destructive button on a screen looked like every other
    // outlined button — and glance is all anyone gives a button they are about
    // to press by accident.
    final Color border = !enabled
        ? (primary ? c.field : c.rule)
        : (danger && !primary ? c.signal : c.ink);
    Color fg = enabled ? (primary ? c.onInk : c.ink) : c.inkMuted;
    if (danger && enabled && !primary) fg = c.signal;

    return Semantics(
      button: true,
      enabled: enabled,
      child: JotaPressable(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: JotaMotion.fast,
          curve: JotaMotion.curve,
          height: height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: JotaRows.borderRadiusOf(height),
            border: Border.all(color: border, width: JotaGrid.hairline),
          ),
          alignment: Alignment.center,
          child: busy
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    // busy implies not-enabled, so a primary is on the soft
                    // `field` fill now — a dark spinner reads on both.
                    valueColor: AlwaysStoppedAnimation<Color>(c.ink),
                  ),
                )
              : Text(
                  upcase ? label.toUpperCase() : label,
                  style: t.label.copyWith(color: fg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}

// ---- bigFigure -------------------------------------------------------------
// widgets.h: bigFigure(). The SAVED and PAIR pattern: one large monospace
// figure, a rule, and a caption under it. A code is a figure, so it gets the
// display face and the same rhythm as a duration.
class JotaBigFigure extends StatelessWidget {
  const JotaBigFigure({
    super.key,
    required this.figure,
    this.caption,
    this.captionStyleIsLabel = false,
  });

  final String figure;
  final String? caption;
  final bool captionStyleIsLabel;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(figure, style: t.display, textAlign: TextAlign.center),
        ),
        const SizedBox(height: JotaGrid.gapM),
        const JotaRuleStrong(),
        if (caption != null) ...<Widget>[
          const SizedBox(height: JotaGrid.gapM),
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: captionStyleIsLabel
                ? t.label.copyWith(color: c.inkMuted)
                : t.reading.copyWith(color: c.inkMuted),
          ),
        ],
      ],
    );
  }
}

// ---- ring ------------------------------------------------------------------
// widgets.h: ring(). Drawn so the OUTER EDGE NEVER MOVES between idle and
// active — only the annulus thickens inward. On e-paper that keeps the
// transition additive and safe for a partial refresh; on the phone it keeps
// the transition from reading as a size change, which is the point.
class JotaRing extends StatelessWidget {
  const JotaRing({
    super.key,
    this.active = false,
    this.radius = JotaIndicators.ringRadius,
    this.child,
    this.progress,
  });

  final bool active;
  final double radius;
  final Widget? child;

  /// 0..1. When set, the ring is drawn as an arc gauge instead of a full
  /// annulus — used by the transfer view.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CustomPaint(
        painter: _RingPainter(
          ink: c.ink,
          track: c.rule,
          stroke: active
              ? JotaIndicators.ringStrokeActive
              : JotaIndicators.ringStroke,
          progress: progress,
        ),
        child: Center(
          child: child ??
              (active
                  ? null
                  : Container(
                      width: JotaIndicators.dotRadius * 2,
                      height: JotaIndicators.dotRadius * 2,
                      decoration: BoxDecoration(
                        color: c.ink,
                        shape: BoxShape.circle,
                      ),
                    )),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ink,
    required this.track,
    required this.stroke,
    this.progress,
  });

  final Color ink;
  final Color track;
  final double stroke;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    // Inset by half the stroke so the OUTER edge sits exactly on the bounds,
    // no matter how thick the annulus is. This is what pins the outer edge.
    final double r = size.width / 2 - stroke / 2;

    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    if (progress == null) {
      canvas.drawCircle(centre, r, p..color = ink);
      return;
    }

    canvas.drawCircle(centre, r, p..color = track);
    final double sweep = 6.283185307179586 * progress!.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r),
      -1.5707963267948966, // 12 o'clock
      sweep,
      false,
      p..color = ink,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ink != ink ||
      old.track != track ||
      old.stroke != stroke ||
      old.progress != progress;
}

// ---- progressBar -----------------------------------------------------------
// widgets.h: progressBar(). An outlined stadium with a filled stadium inside
// it. Not a Material LinearProgressIndicator — those have square ends and a
// tinted track, and both would break the shape rule.
class JotaProgressBar extends StatelessWidget {
  const JotaProgressBar({
    super.key,
    required this.fraction,
    this.height = JotaIndicators.progressHeight,
    this.indeterminate = false,
  });

  final double fraction;
  final double height;

  /// Used before a transfer reports its first chunk, when a filled bar at 0%
  /// would be a lie.
  final bool indeterminate;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final double f = fraction.clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(height / 2)),
        border: Border.all(color: c.ink, width: JotaGrid.hairline),
      ),
      padding: const EdgeInsets.all(2),
      child: indeterminate
          ? _IndeterminateFill(height: height - 6, color: c.ink)
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: JotaMotion.normal,
                    curve: JotaMotion.curve,
                    width: box.maxWidth * f,
                    decoration: BoxDecoration(
                      color: c.ink,
                      borderRadius: BorderRadius.all(
                        Radius.circular((height - 4) / 2),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _IndeterminateFill extends StatefulWidget {
  const _IndeterminateFill({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  State<_IndeterminateFill> createState() => _IndeterminateFillState();
}

class _IndeterminateFillState extends State<_IndeterminateFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, Widget? _) {
            const double frac = 0.3;
            final double w = box.maxWidth * frac;
            final double x = (box.maxWidth + w) * _c.value - w;
            return Stack(
              children: <Widget>[
                Positioned(
                  left: x.clamp(0.0, box.maxWidth),
                  width: w.clamp(0.0, box.maxWidth),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.all(
                        Radius.circular(widget.height / 2),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---- dots ------------------------------------------------------------------
// widgets.h: dots(). Position within a short sequence — no colour, no size
// change, only ink against rule.
//
// EXACTLY ONE dot is inked: the one you are on. The old test was `i <= active`,
// which inked every dot up to the current one, so page 2 of 3 drew ● ● ○ and
// read as a progress bar filling up rather than as a position within a set.
// Onboarding is not a download; it is three things to look at, and the reader
// is at one of them. The others are drawn flat in `rule` — present, unvisited,
// not "done".
class JotaDots extends StatelessWidget {
  const JotaDots({super.key, required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // A flat disc either way, so the only difference between here
                // and elsewhere is weight of colour. An ink ring around an
                // unvisited dot would give it a second, louder reading.
                color: i == active ? c.ink : c.rule,
              ),
            ),
          ),
      ],
    );
  }
}

// ---- hero card -------------------------------------------------------------
// The single sanctioned rounded rectangle in the app (JotaCards.radius),
// reserved for the onboarding / splash hero that holds a device render. It is
// still flat — a field-tinted fill and a hairline, no shadow — because the
// device is a flat panel and so is this. Everywhere else, the shape is a
// stadium.
class JotaHeroCard extends StatelessWidget {
  const JotaHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(JotaGrid.gapL),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return Container(
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(JotaCards.radius),
        border: Border.all(color: c.rule, width: JotaGrid.hairline),
      ),
      padding: padding,
      child: child,
    );
  }
}

// ---- meta line -------------------------------------------------------------
// screens.cpp screenNoteView(): the note's own timestamp on the left and its
// duration on the right, in `reading`, above the prose. Explicitly NOT in the
// status slot, where they would masquerade as the live clock.
class JotaMetaLine extends StatelessWidget {
  const JotaMetaLine({super.key, required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final TextStyle s = t.reading.copyWith(color: c.inkMuted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[Text(left, style: s), Text(right, style: s)],
    );
  }
}

/// A `key   value` line in mono, the two columns aligned by the monospace
/// grid alone — the same trick the device's GUIDE card uses to lay out two
/// columns without a layout pass.
class JotaKeyValue extends StatelessWidget {
  const JotaKeyValue({
    super.key,
    required this.name,
    required this.value,
    this.emphasis = false,
  });

  final String name;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: JotaGrid.gapS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(name, style: t.label.copyWith(color: c.inkMuted)),
          const SizedBox(width: JotaGrid.gapM),
          Flexible(
            child: Text(
              value,
              style: emphasis
                  ? t.reading
                      .copyWith(color: c.ink, fontWeight: FontWeight.w700)
                  : t.reading,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- empty state -----------------------------------------------------------
// The device says NO TRANSCRIPT in `reading`, centred, and nothing else. No
// illustration, no call to action, no exclamation mark.
class JotaEmpty extends StatelessWidget {
  const JotaEmpty({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            textAlign: TextAlign.center,
            style: t.prose.copyWith(color: c.inkMuted),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: JotaGrid.gapL),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A search field as one stadium, in the product's own vocabulary rather than
/// Material's: a hairline that turns to ink while it has focus, the glyph on
/// the left in the same muted ink as the hint, and — only while there is
/// something to clear — a small ink circle with a cross on the right, the same
/// shape as the player's transport circle. No fill, no elevation, no label
/// that floats: the field is a place to type, and reads as one.
class JotaSearchField extends StatefulWidget {
  const JotaSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
    this.height = JotaRows.heightCompact,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final double height;

  @override
  State<JotaSearchField> createState() => _JotaSearchFieldState();
}

class _JotaSearchFieldState extends State<JotaSearchField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
    // Clearing is usually "I'm done", not "let me try another word".
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final bool focused = _focus.hasFocus;
    const double glyph = 16;

    return AnimatedContainer(
      duration: JotaMotion.fast,
      curve: JotaMotion.curve,
      height: widget.height,
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(
        borderRadius: JotaRows.borderRadiusOf(widget.height),
        border: Border.all(
          color: focused ? c.ink : c.rule,
          width: JotaGrid.hairline,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            LucideIcons.search,
            size: glyph,
            color: focused ? c.ink : c.inkMuted,
          ),
          const SizedBox(width: JotaGrid.gapS + 2),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: t.prose.copyWith(fontSize: 15, color: c.ink),
              cursorColor: c.ink,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                isCollapsed: true,
                // The app's field theme fills and outlines every TextField;
                // inside a stadium that is a second, darker stadium.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.hint,
                hintStyle: t.prose.copyWith(color: c.inkMuted, fontSize: 15),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (BuildContext context, TextEditingValue v, _) {
              final bool has = v.text.isNotEmpty;
              // Scales in from nothing rather than popping: the circle is
              // the only filled shape on the row, so its arrival is felt.
              return AnimatedScale(
                scale: has ? 1 : 0,
                duration: JotaMotion.fast,
                curve: JotaMotion.curve,
                child: Semantics(
                  button: true,
                  label: 'Clear search',
                  child: GestureDetector(
                    onTap: has ? _clear : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.ink,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.x, size: 12, color: c.onInk),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Press feedback for every tappable shape: the shape sinks a hair under the
/// finger and springs back on release. Without it a stadium is a drawing of
/// a button; with it, it is one. Scale, not colour, because colour is spent
/// on selection everywhere in this product.
class JotaPressable extends StatefulWidget {
  const JotaPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<JotaPressable> createState() => _JotaPressableState();
}

class _JotaPressableState extends State<JotaPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: JotaMotion.fast,
        curve: JotaMotion.curve,
        child: widget.child,
      ),
    );
  }
}

/// A choice on a sheet — a tag to file under, a language — as a stadium a
/// finger can read and hit: the `choice` role inside JotaRows.choicePadding,
/// outlined in ink, inverted when it is the chosen one. A step up from the
/// tag pill on a note, which is a label on something already chosen.
class JotaTagChoice extends StatelessWidget {
  const JotaTagChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    return Semantics(
      button: true,
      selected: selected,
      child: JotaPressable(
        onTap: onTap,
        scale: 0.94,
        child: AnimatedContainer(
          duration: JotaMotion.fast,
          curve: JotaMotion.curve,
          padding: JotaRows.choicePadding,
          decoration: BoxDecoration(
            color: selected ? c.ink : Colors.transparent,
            border: Border.all(color: c.ink, width: JotaGrid.hairline),
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          child: Text(
            label.toUpperCase(),
            style: t.choice.copyWith(color: selected ? c.onInk : c.ink),
          ),
        ),
      ),
    );
  }
}

/// A tag, as a stadium. Outlined when it is simply a label, filled with ink and
/// knocked out when it is selected — the one selection signal this product has,
/// on the phone exactly as on the panel.
class JotaTagPill extends StatelessWidget {
  const JotaTagPill({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    // The same size as the stamp it sits beside, with room around the word:
    // at 10pt over 2pt of padding it read as a tiny ring, out of scale with
    // every other stadium on the screen. Outlined in the ink of its label,
    // not the rule colour, so the shape is as present as the word inside it.
    return AnimatedContainer(
      duration: JotaMotion.fast,
      curve: JotaMotion.curve,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? c.ink : Colors.transparent,
        border: Border.all(
          color: selected ? c.ink : c.inkMuted,
          width: JotaGrid.hairline,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label.toUpperCase(),
        style: t.reading.copyWith(
          fontSize: 11,
          letterSpacing: 1.0,
          height: 1.1,
          color: selected ? c.onInk : c.ink,
        ),
      ),
    );
  }
}

/// The pairing code as one box per digit, filled left to right.
///
/// Boxes rather than a run of dashes because the count is the instruction: six
/// slots say "six digits" without a word of copy, and the outlined box you are
/// about to fill says where you are in it. The digits are mono, like every
/// other figure in the product.
///
/// It draws only — the caller owns the controller and the keyboard, so the
/// same boxes serve first-run pairing and re-pairing from Settings without
/// either screen inheriting the other's plumbing.
class JotaCodeBoxes extends StatelessWidget {
  const JotaCodeBoxes({
    super.key,
    required this.digits,
    required this.length,
    this.focused = true,
  });

  final String digits;
  final int length;

  /// Marks the next empty box, so there is a cursor even though the real
  /// TextField behind this is invisible.
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    final int cursor = digits.length.clamp(0, length - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 7),
          // A stadium like every other shape in the product: the radius is
          // half the height, so a box taller than it is wide becomes a
          // standing pill. It was a radius-8 rectangle, the one rounded
          // rectangle the app had.
          Container(
            width: 32,
            height: JotaRows.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.field,
              borderRadius: JotaRows.borderRadiusOf(JotaRows.height),
              border: Border.all(
                color: (focused && i == cursor && digits.length < length)
                    ? c.ink
                    : c.rule,
                width: (focused && i == cursor && digits.length < length)
                    ? 1.6
                    : JotaGrid.hairline,
              ),
            ),
            child: Text(
              i < digits.length ? digits[i] : '',
              style: t.figure.copyWith(fontSize: 20),
            ),
          ),
        ],
      ],
    );
  }
}
