// ============================================================================
//  Jota — splash
//
//  The phone's echo of the device's own splash (renders/ui/01_splash.png): the
//  Jota wordmark, a strong rule, and the version beneath — on warm paper. Held
//  for a beat while the service graph settles, then it reads the first-run flag
//  and routes: a fresh install goes to onboarding, everyone else goes straight
//  to the notes.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    // A visual beat, not real work — the graph is already booted before runApp.
    _hold = Timer(const Duration(milliseconds: 900), _go);
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
      MaterialPageRoute<void>(
        builder: (_) =>
            seen ? const HomeShell() : const OnboardingScreen(),
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
              // Just the wordmark, dead centre. No rule.
              //
              // `Jota`, not `JOTA`. The serif wordmark is the name and the name
              // is capital-J-lowercase (docs/brand.md); the all-caps form is the
              // MONO identifier, which is what the device prints and what
              // `JOTA-91C4` is built from. Setting the identifier in the serif
              // face made the splash the one place the two forms were confused.
              Expanded(
                child: Center(child: Text('Jota', style: t.wordmark)),
              ),
              // Version pinned to the bottom, small and quiet.
              Padding(
                padding: const EdgeInsets.only(bottom: JotaGrid.gapXL),
                child: Text(
                  kVersionLabel,
                  style: t.reading.copyWith(color: c.inkMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
