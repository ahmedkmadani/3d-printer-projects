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

import 'design/theme.dart';
import 'screens/lock_screen.dart';
import 'screens/splash_screen.dart';
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
      child: MaterialApp(
        title: 'Jota',
        debugShowCheckedModeBanner: false,
        theme: JotaTheme.light(),
        darkTheme: JotaTheme.dark(),
        // Follows the system. E-paper has one appearance; a phone has two, and
        // fighting the user's choice is not a design decision worth making.
        themeMode: ThemeMode.system,
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
        home: const SplashScreen(),
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
                  'PAIR CODE 428 913',
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
