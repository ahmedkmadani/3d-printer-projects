// ============================================================================
//  Jota — the mark
//
//  A circle with the word inside it. The circle is your head; the word is the
//  thoughts. That is the whole idea, and it is why the same mark serves as the
//  device's idle screen, the app icon, and the app's own header — see
//  docs/brand.md.
//
//  Drawn, not an asset. The device paints this ring from theme.h at 1-bit and
//  the phone paints it from theme.dart in ink; shipping a PNG would give the
//  two objects two marks that could drift apart, and the ring is three lines of
//  geometry.
//
//  Rules it holds to, so callers cannot get them wrong:
//    - lowercase-with-a-capital `Jota`, never all-caps (that is the mono
//      identifier form, as in JOTA-91C4)
//    - the serif face, always
//    - a hairline ring that scales with the mark rather than a fixed stroke,
//      so a small one does not look drawn in marker
// ============================================================================
import 'package:flutter/material.dart';

import 'theme.dart';

class JotaMark extends StatelessWidget {
  const JotaMark({super.key, this.size = 40, this.color, this.inverted = false});

  /// Outer diameter.
  final double size;

  /// Defaults to `ink`. Pass `onInk` when the mark sits on a filled shape.
  final Color? color;

  /// Filled circle with the word knocked out — the app-icon treatment, and the
  /// same inversion that means "selected" everywhere else in the product.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final Color ink = color ?? c.ink;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: inverted ? ink : Colors.transparent,
          border: Border.all(
            color: ink,
            // Proportional: the device's ring is 3px on a 200px panel, and a
            // fixed 1.5 here would read as a hairline at 96 and as a marker
            // line at 24.
            width: (size * 0.035).clamp(1.0, 3.0),
          ),
        ),
        child: Center(
          child: Text(
            'Jota',
            style: context.type.headline.copyWith(
              // The word fills a little under half the diameter. Any larger and
              // it touches the ring at the descender.
              fontSize: size * 0.30,
              height: 1,
              color: inverted ? c.bg : ink,
            ),
          ),
        ),
      ),
    );
  }
}
