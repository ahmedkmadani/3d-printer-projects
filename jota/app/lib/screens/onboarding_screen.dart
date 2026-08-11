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
import '../design/widgets.dart';
import '../state/services.dart';
import 'onboarding_illustration.dart';
import 'pair_screen.dart';

/// One onboarding page: an illustration, a Fraunces headline, and one line of
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

const List<_Page> _pages = <_Page>[
  _Page(
    stage: 0,
    headline: 'When your head\nis full.',
    body: 'Thoughts pile up and talk over each other. '
        'That’s jota — the crowd in your head.',
  ),
  _Page(
    stage: 1,
    headline: 'Say it,\nlet it out.',
    body: 'Press once and speak. Jota takes the thought off '
        'your mind and holds it for you.',
  ),
  _Page(
    stage: 2,
    headline: 'Feel\nlighter.',
    body: 'Your head clears. It’s out, it’s saved, and it’s '
        'yours — come back to it whenever you’re ready.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

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
          builder: (_) => const PairScreen(firstRun: true),
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
                          label: 'Skip',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _finish,
                            child: Text(
                              'Skip',
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
                itemCount: _pages.length,
                onPageChanged: (int i) => setState(() => _index = i),
                itemBuilder: (BuildContext context, int i) =>
                    _OnboardingPage(page: _pages[i]),
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
              child: Row(
                children: <Widget>[
                  JotaDots(count: _pages.length, active: _index),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: JotaButton(
                      label: _isLast ? 'Get started' : 'Next',
                      primary: true,
                      upcase: false,
                      onTap: _next,
                    ),
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
  const _OnboardingPage({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: JotaGrid.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Center(
              child: JotaHeroCard(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: MindIllustration(stage: page.stage),
                ),
              ),
            ),
          ),
          const SizedBox(height: JotaGrid.gapXL),
          Text(page.headline, style: t.headline),
          const SizedBox(height: JotaGrid.gapS),
          Text(
            page.body,
            style: t.prose.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: JotaGrid.gapL),
        ],
      ),
    );
  }
}
