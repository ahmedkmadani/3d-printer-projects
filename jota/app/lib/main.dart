// ============================================================================
//  Jota — entry point (real hardware)
//
//  Builds the service graph over BLE, sqflite, the filesystem and the Keychain.
//  For the browser preview with fake data, see main_preview.dart.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'design/theme.dart';
import 'state/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The device is a pocket object held in one hand; so is this.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  // `Services.boot()` used to be awaited here with nothing around it, and
  // runApp() came after. So anything that threw during boot — a database that
  // could not be created, a keychain unavailable on first run, a plugin that
  // failed to register — meant runApp was NEVER reached: no widget tree, no
  // error, just a black rectangle and a process that looked alive. That is the
  // worst possible failure on a phone, because it is indistinguishable from a
  // crash and it hides the one line that would explain it.
  //
  // Now the failure has somewhere to go.
  try {
    final Services services = await Services.boot();
    runApp(JotaApp(services: services));
  } catch (e, stack) {
    debugPrint('[jota] boot failed: $e\n$stack');
    runApp(_BootFailure(error: e, stack: stack));
  }
}

/// Shown when the app cannot start at all. Deliberately depends on nothing but
/// Flutter itself — no theme extension, no services — because whatever broke
/// may be exactly what a richer screen would need.
class _BootFailure extends StatelessWidget {
  const _BootFailure({required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF6F1E8),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(JotaGrid.margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 40),
                const Text(
                  'Jota could not start',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Serif',
                    fontSize: 26,
                    color: Color(0xFF23201C),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your notes are still on this phone. This is a fault in the '
                  'app, not in what you have recorded.',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans',
                    fontSize: 14,
                    color: Color(0xFF8B8177),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      '$error\n\n$stack',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 11,
                        color: Color(0xFF23201C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
