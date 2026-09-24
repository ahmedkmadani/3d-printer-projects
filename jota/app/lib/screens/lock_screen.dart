// ============================================================================
//  Jota — lock screen
//
//  The first thing the app shows, every time it opens. It is deliberately the
//  emptiest screen in the product: the logo — the circle with `Jota` in it —
//  one word saying why you are looking at it, and the way back in. NOTHING of
//  the archive is drawn behind it, not even a blurred list; a lock that leaks
//  the first line of your last note is not a lock.
//
//  Face or fingerprint, whichever the phone has, so both marks are shown and
//  neither is promised by name.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../l10n/l10n.dart';
import '../design/widgets.dart';
import '../state/lock_controller.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    final LockController lock = context.watch<LockController>();

    // No status bar and no rule: there is no screen to name and nowhere to go
    // back to, so the only chrome is the mark itself.
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: JotaGrid.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              const Center(child: _LockMark()),
              const SizedBox(height: JotaGrid.gapL),
              Text(
                // Mono, spaced and small: it is a state, not a sentence. The
                // wordmark carries the screen; this only labels it.
                'LOCKED',
                textAlign: TextAlign.center,
                style: t.cardLabel.copyWith(color: c.inkMuted),
              ),
              const Spacer(),
              const Center(child: _BiometricMarks()),
              const SizedBox(height: JotaGrid.gapM),
              Text(
                // Not "Use Face ID": the app does not know which of the two the
                // phone will offer, and naming the wrong one reads as a lie the
                // first time the other sheet comes up.
                context.l10n.useFaceOrFingerprint,
                textAlign: TextAlign.center,
                style: t.prose.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: JotaGrid.gapL),
              JotaButton(
                label: context.l10n.unlock,
                // Outlined, not filled. The prompt comes up by itself on open
                // and on every resume — this button is the second chance after
                // a cancelled sheet, so it should not shout over the mark.
                upcase: false,
                busy: lock.authenticating,
                onTap: lock.unlock,
              ),
              const SizedBox(height: JotaGrid.gapL),
            ],
          ),
        ),
      ),
    );
  }
}

/// The logo at rest: a thin ring with `Jota` inside it, the circle being the
/// head and the word the thoughts (docs/brand.md).
///
/// Drawn here rather than with [JotaRing] because that ring carries the
/// RECORDING weight — it is built to read as "on" from arm's length on a grey
/// panel. This mark is the quietest thing on the quietest screen, so it takes a
/// hairline-and-a-half instead.
class _LockMark extends StatelessWidget {
  const _LockMark();

  /// Matches the recording ring's outer edge, so the same circle is the same
  /// size wherever the product draws it.
  static const double _diameter = JotaIndicators.ringRadius * 2;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return Container(
      width: _diameter,
      height: _diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.ink, width: 1.5),
      ),
      // The serif wordmark, capital J — never the mono `JOTA-91C4` form, which
      // is an identifier and belongs to a particular device.
      child: Text(
        'Jota',
        style: context.type.headline.copyWith(fontSize: 26, letterSpacing: 0),
      ),
    );
  }
}

/// Face and fingerprint side by side, split by a short hairline. Both are shown
/// because the phone decides which one it will actually ask for, and the pair
/// says "biometrics" faster than either alone.
class _BiometricMarks extends StatelessWidget {
  const _BiometricMarks();

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(LucideIcons.scanFace, size: 26, color: c.ink),
        const SizedBox(width: JotaGrid.gapL),
        // The app's one line weight, stood on its end.
        Container(width: JotaGrid.hairline, height: 20, color: c.rule),
        const SizedBox(width: JotaGrid.gapL),
        Icon(LucideIcons.fingerprint, size: 26, color: c.ink),
      ],
    );
  }
}
