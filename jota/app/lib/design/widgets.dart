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
class JotaStatusBar extends StatelessWidget {
  const JotaStatusBar({
    super.key,
    required this.label,
    this.value,
    this.onBack,
    this.trailing,
    this.showSignalDot = false,
    this.upcase = true,
  });

  /// Left slot: what this screen is. `label` role, uppercased unless a screen
  /// in the handwriting voice opts out.
  final String label;

  /// See [JotaButton.upcase]. Defaults true so existing screens are untouched.
  final bool upcase;

  /// Right slot: the one defining figure. `reading` role — lighter than the
  /// label, because it is data and the label is chrome.
  final String? value;

  /// Back affordance. The device uses a long-press; the phone gets a chevron.
  final VoidCallback? onBack;

  /// Replaces the value slot entirely when a screen needs an action there.
  final Widget? trailing;

  /// The signal dot — "the device is holding notes for you". One of exactly
  /// two places the accent colour is allowed to appear.
  final bool showSignalDot;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;

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
              Expanded(
                child: Text(
                  upcase ? label.toUpperCase() : label,
                  style: t.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showSignalDot) ...<Widget>[
                Container(
                  width: JotaIndicators.signalDot,
                  height: JotaIndicators.signalDot,
                  decoration: BoxDecoration(
                    color: c.signal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: JotaGrid.gapS),
              ],
              if (trailing != null)
                trailing!
              else if (value != null)
                Text(value!, style: t.reading.copyWith(color: c.inkMuted)),
            ],
          ),
        ),
        const SizedBox(height: JotaGrid.statusRuleGap),
        const JotaRuleStrong(),
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
  });

  final String label;
  final String? value;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showSignalDot;
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
    final Color border = enabled ? c.ink : (primary ? c.field : c.rule);
    Color fg = enabled ? (primary ? c.onInk : c.ink) : c.inkMuted;
    if (danger && enabled && !primary) fg = c.signal;

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
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
// widgets.h: dots(). Position within a short sequence. Filled is here, hollow
// is elsewhere — no colour, no size change.
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
                color: i <= active ? c.ink : Colors.transparent,
                border: Border.all(color: c.ink, width: JotaGrid.hairline),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? c.ink : Colors.transparent,
        border: Border.all(
          color: selected ? c.ink : c.rule,
          width: JotaGrid.hairline,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label.toUpperCase(),
        style: t.reading.copyWith(
          fontSize: 10,
          letterSpacing: 0.8,
          color: selected ? c.onInk : c.inkMuted,
        ),
      ),
    );
  }
}
