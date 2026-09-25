// ============================================================================
//  Jota — onboarding
//
//  Three pages, shown once. NOT a feature tour — this is the whole reason Jota
//  exists, in three beats: a head too full, letting a thought out, and feeling
//  lighter for it. The copy speaks to that feeling, not to Bluetooth. The art
//  is hand-drawn (see onboarding_illustration.dart), warm and human.
//
//  Finishing (or skipping) sets `hasSeenOnboarding` and hands off to the pair
//  step. It is shown from the splash only when that flag is false.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../l10n/l10n.dart';
import '../design/widgets.dart';
import '../state/services.dart';
import 'onboarding_illustration.dart';
import 'connect_screen.dart';

/// One onboarding page: an illustration, a Plex Serif headline, and one line of
/// prose. The body is a single sentence — the headline carries the feeling, the
/// line underneath just lands it.
class _Page {
  const _Page({
    required this.stage,
    required this.headline,
    required this.body,
  });

  /// Which beat of the illustration — see [MindIllustration].
  final int stage;
  final String headline;
  final String body;
}

// Word for word from product.md and the design lock. Each line had grown a
// second clause explaining the first ("— the crowd in your head", "come back to
// it whenever you're ready"), which is the app talking itself out of a sentence
// that already landed. One line each, as specified.
List<_Page> _pagesOf(AppLocalizations l) => <_Page>[
      _Page(stage: 0, headline: l.obHead1, body: l.obBody1),
      _Page(stage: 1, headline: l.obHead2, body: l.obBody2),
      _Page(stage: 2, headline: l.obHead3, body: l.obBody3),
    ];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pagesOf(context.l10n).length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      unawaited(_finish());
      return;
    }
    _controller.nextPage(
      duration: JotaMotion.normal,
      curve: JotaMotion.curve,
    );
  }

  Future<void> _finish() async {
    await context.read<Services>().settings.setHasSeenOnboarding(true);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const ConnectScreen(onboarding: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Skip, top-right — the one escape from the flow. Gone on the last
            // page, where the primary button already means "done".
            SizedBox(
              height: JotaGrid.statusHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: _isLast
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: JotaGrid.margin),
                        child: Semantics(
                          button: true,
                          label: context.l10n.skip,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _finish,
                            child: Text(
                              context.l10n.skip,
                              style: t.label.copyWith(color: c.inkMuted),
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pagesOf(context.l10n).length,
                onPageChanged: (int i) => setState(() => _index = i),
                itemBuilder: (BuildContext context, int i) => _OnboardingPage(
                  page: _pagesOf(context.l10n)[i],
                  active: i == _index,
                ),
              ),
            ),

            // Shared footer: position on the left, the one action on the right.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                JotaGrid.margin,
                JotaGrid.gapM,
                JotaGrid.margin,
                JotaGrid.gapM,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  JotaDots(
                    count: _pagesOf(context.l10n).length,
                    active: _index,
                  ),
                  const SizedBox(height: JotaGrid.gapM),
                  JotaButton(
                    label: _isLast
                        ? context.l10n.connectMyJota
                        : context.l10n.next,
                    primary: true,
                    upcase: false,
                    onTap: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page, required this.active});

  final _Page page;

  /// True for the page on screen: its drawing plays its entrance then, not
  /// when the PageView builds it out of sight.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;

    // Centred, and no card. The drawing used to sit in a JotaHeroCard, which
    // put a second surface and a second corner radius on the one screen that
    // should be nothing but a picture and a sentence — and the card's edge read
    // as a boundary you were meant to do something with.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: JotaGrid.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Spacer(),
          // The drawing's own proportions (150 x 92 in the design lock),
          // at a size that owns the page: at 180 wide the ring floated in
          // the void like an icon, and the whitespace read as missing
          // content rather than air.
          SizedBox(
            width: 264,
            height: 162,
            child: MindIllustration(stage: page.stage, active: active),
          ),
          const SizedBox(height: JotaGrid.gapXL),
          Text(
            page.headline,
            style: t.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: JotaGrid.gapM),
          // ~26 characters a line: the body is one sentence and it should look
          // like one, not like a paragraph that ran to the margins.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              page.body,
              style: t.prose.copyWith(color: c.inkMuted, height: 1.55),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
