// ============================================================================
//  Jota — entry point
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'design/theme.dart';
import 'screens/note_list_screen.dart';
import 'state/device_controller.dart';
import 'state/notes_controller.dart';
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
      ],
      child: MaterialApp(
        title: 'Jota',
        debugShowCheckedModeBanner: false,
        theme: JotaTheme.light(),
        darkTheme: JotaTheme.dark(),
        // Follows the system. E-paper has one appearance; a phone has two, and
        // fighting the user's choice is not a design decision worth making.
        themeMode: ThemeMode.system,
        home: const NoteListScreen(),
      ),
    );
  }
}
