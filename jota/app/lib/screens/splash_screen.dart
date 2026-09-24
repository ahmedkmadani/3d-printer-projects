// ============================================================================
//  Jota — splash
//
//  The mark draws itself in above the wordmark — the ring sweeps, the thoughts
//  arrive — then the app fades in behind it. Under 1.2 s in all: a splash is
//  paid on every launch, and this one exists to say the name, not to be
//  watched. It reads the first-run flag and routes: a fresh install goes to
//  onboarding, everyone else goes straight to the notes.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/marks.dart';
import '../design/theme.dart';
import '../state/services.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

/// Kept in step with pubspec's `version:` by hand — the same string the device
/// prints under its own wordmark.
const String kVersionLabel = 'v0.1.0';

/// Dev override. When true, forces the first-run flow on every launch, ignoring
/// the saved flag — handy while iterating on the splash and onboarding. Ships as
/// false: show onboarding once, then go straight to the notes on later launches.
const bool kForceOnboarding = false;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: JotaMotion.normal,
  )..forward();

  Timer? _hold;

  /// The mark takes 600 ms to draw; the whole mark is then held for a beat
  /// before the app fades in. About 1.1 s from first paint to Home.
  void _drawn() {
    _hold = Timer(const Duration(milliseconds: 320), _go);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void _go() {
    if (!mounted) return;
    final bool seen = !kForceOnboarding &&
        context.read<Services>().settings.hasSeenOnboarding;
    Navigator.of(context).pushReplacement(
      // A fade, not the app's slide: the splash is not a page you came from.
      PageRouteBuilder<void>(
        transitionDuration: JotaMotion.normal,
        pageBuilder: (_, __, ___) =>
            seen ? const HomeShell() : const OnboardingScreen(),
        transitionsBuilder: (_, Animation<double> a, __, Widget child) =>
            FadeTransition(opacity: a, child: child),
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
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: <Widget>[
              // The mark, drawing itself in, above the wordmark — the same
              // ring and the same five thoughts as the icon the person just
              // tapped to get here.
              //
              // `Jota`, not `JOTA`. The serif wordmark is the name and the name
              // is capital-J-lowercase (docs/brand.md); the all-caps form is the
              // MONO identifier, which is what the device prints and what
              // `JOTA-91C4` is built from. Setting the identifier in the serif
              // face made the splash the one place the two forms were confused.
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      JotaMarkDrawing(size: 132, onDone: _drawn),
                      const SizedBox(height: JotaGrid.gapL),
                      Text('Jota', style: t.wordmark),
                    ],
                  ),
                ),
              ),
              // Version pinned to the bottom, small and quiet.
              Padding(
                padding: const EdgeInsets.only(bottom: JotaGrid.gapXL),
                child: Text(
                  kVersionLabel,
                  style: t.meta.copyWith(color: c.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
