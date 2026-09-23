// ============================================================================
//  Jota — the app widget
//
//  Shared by both entry points. `main.dart` hands it a Services made of BLE and
//  sqflite; `main_preview.dart` hands it a Services made of fakes. Everything
//  from here down — controllers, screens, theme — is identical, which is the only
//  reason the preview is worth looking at.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'design/format.dart';
import 'design/theme.dart';
import 'preview/seed_data.dart';
import 'screens/lock_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart' show kForceOnboarding;
import 'state/device_controller.dart';
import 'state/lock_controller.dart';
import 'state/notes_controller.dart';
import 'state/services.dart';

class JotaApp extends StatelessWidget {
  const JotaApp({super.key, required this.services});

  final Services services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Services>.value(value: services),
        ChangeNotifierProvider<NotesController>(
          create: (_) => NotesController(
            repository: services.notes,
            transcription: services.transcription,
            settings: services.settings,
          )..refresh(),
        ),
        ChangeNotifierProxyProvider<NotesController, DeviceController>(
          create: (BuildContext context) => DeviceController(
            scanner: services.scanner,
            sync: services.sync,
            settings: services.settings,
            background: services.background,
            notes: context.read<NotesController>(),
          ),
          update: (_, __, DeviceController? previous) => previous!,
        ),
        ChangeNotifierProvider<LockController>(
          create: (_) => LockController(
            auth: services.auth,
            settings: services.settings,
          ),
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: services.themeMode,
        builder: (BuildContext context, ThemeMode mode, _) => MaterialApp(
          title: 'Jota',
          debugShowCheckedModeBanner: false,
          theme: JotaTheme.light(),
          darkTheme: JotaTheme.dark(),
          // Follows the system unless Settings says otherwise. E-paper has one
          // appearance; a phone has two, and the dark theme was built and
          // never reachable on a phone set to light.
          themeMode: mode,
          // The app lock overlays every screen from above the Navigator, so it
          // covers the notes, a modal, anything. The preview chrome (if any) sits
          // under it. Always present now, not just for the preview.
          builder: (BuildContext context, Widget? child) {
            Widget content = child ?? const SizedBox.shrink();
            if (services.isPreview) content = _PreviewChrome(child: content);
            return _LockGate(child: content);
          },
          // First run shows splash → onboarding → pair; every launch after that,
          // the splash reads the flag and goes straight to the notes.
          // Straight in. The splash (mark, wordmark, 2.6 s hold) is switched
          // off for now: it stood between you and your notes on every open and
          // said nothing the shell does not. SplashScreen still exists; put it
          // back here when there is a reason to.
          home: !kForceOnboarding && services.settings.hasSeenOnboarding
              ? const HomeShell()
              : const OnboardingScreen(),
        ),
      ),
    );
  }
}

/// Holds the lock screen over the app whenever [LockController] says so. It
/// lives inside MaterialApp.builder — above the Navigator — so nothing the user
/// was looking at leaks through behind it.
class _LockGate extends StatelessWidget {
  const _LockGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool locked = context.watch<LockController>().locked;
    return Stack(
      children: <Widget>[
        child,
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

/// A strip along the bottom of the preview build.
///
/// It says what this is, and it carries the pair code — on real hardware that
/// code is on the e-paper, and there is no e-paper in a browser tab.
class _PreviewChrome extends StatelessWidget {
  const _PreviewChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;

    return Column(
      children: <Widget>[
        Expanded(child: child),
        Container(
          width: double.infinity,
          color: c.ink,
          padding: const EdgeInsets.symmetric(
            horizontal: JotaGrid.margin,
            vertical: JotaGrid.gapS + 2,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'PREVIEW · FAKE DATA · NO BLUETOOTH',
                  style: t.reading.copyWith(color: c.onInk, fontSize: 11),
                ),
                Text(
                  // From the fake's own constant, not typed again here: the
                  // real device's code is random now, and a banner quoting a
                  // literal is exactly how the two drift apart.
                  'PAIR CODE ${fmtPairCode(kPreviewPairCode)}',
                  style: t.label.copyWith(color: c.onInk, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
