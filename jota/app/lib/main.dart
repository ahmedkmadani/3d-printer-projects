// ============================================================================
//  Jota — entry point (real hardware)
//
//  Builds the service graph over BLE, sqflite, the filesystem and the Keychain.
//  For the browser preview with fake data, see main_preview.dart.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'state/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The device is a pocket object held in one hand; so is this.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  final Services services = await Services.boot();
  runApp(JotaApp(services: services));
}
