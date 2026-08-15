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
          builder: (_) => const ConnectScreen(),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  JotaDots(count: _pages.length, active: _index),
                  const SizedBox(height: JotaGrid.gapM),
                  JotaButton(
                    label: _isLast ? 'Connect my Jota' : 'Next',
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
  const _OnboardingPage({required this.page});

  final _Page page;

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
          SizedBox(
            width: 180,
            height: 150,
            child: MindIllustration(stage: page.stage),
          ),
          const SizedBox(height: JotaGrid.gapXL),
          Text(
            page.headline,
            style: t.headline.copyWith(fontSize: 24, height: 1.2),
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
