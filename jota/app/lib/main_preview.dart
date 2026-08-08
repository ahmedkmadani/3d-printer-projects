// ============================================================================
//  Jota — entry point (browser preview)
//
//  Runs the REAL screens against a simulated device and an in-memory archive, so
//  the look and feel can be judged without an Android SDK, a phone, or hardware.
//
//    flutter run -d chrome -t lib/main_preview.dart
//
//  Everything below Services is the shipping code — same controllers, same
//  screens, same design tokens. What is faked is stated plainly in the README
//  and on the strip along the bottom of the window.
// ============================================================================
import 'package:flutter/material.dart';

import 'app.dart';
import 'preview/preview_services.dart';
import 'state/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Deliberately no SystemChrome call: orientation locking is meaningless in a
  // browser, and on web it would be a no-op that only muddies the diff against
  // main.dart.
  final Services services = await PreviewServices.boot();
  runApp(JotaApp(services: services));
}
