// ============================================================================
//  Jota — service container
//
//  Everything long-lived, built once in main() and handed down with provider.
//  There is no dependency-injection framework here on purpose: the object graph
//  is a dozen nodes deep and completely static, so a constructor and a
//  `Provider.value` say it more clearly than annotations would.
// ============================================================================
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../ble/background_sync.dart';
import '../ble/jota_scanner.dart';
import '../ble/sync_engine.dart';
import '../data/audio_store.dart';
import '../data/database.dart';
import '../data/note_repository.dart';
import '../data/partial_store.dart';
import '../data/settings_store.dart';
import '../transcribe/transcriber.dart';
import '../transcribe/transcription_queue.dart';
import '../transcribe/whisper_transcriber.dart';

class Services {
  Services({
    required this.db,
    required this.settings,
    required this.notes,
    required this.audio,
    required this.partials,
    required this.scanner,
    required this.sync,
    required this.background,
    required this.transcription,
  });

  final Database db;
  final SettingsStore settings;
  final NoteRepository notes;
  final AudioStore audio;
  final PartialStore partials;
  final JotaScanner scanner;
  final SyncEngine sync;
  final BackgroundSync background;
  final TranscriptionQueue transcription;

  static Future<Services> boot() async {
    // iOS state restoration must be requested before any other BLE call.
    await JotaScanner.configureForBackground();

    final Directory support = await getApplicationSupportDirectory();
    final Directory cache = await getTemporaryDirectory();

    final Database db = await JotaDatabase.open();
    final SettingsStore settings = await SettingsStore.open();
    final AudioStore audio =
        await AudioStore.open(appSupport: support, cacheDir: cache);
    final PartialStore partials = await PartialStore.open(support);
    final NoteRepository notes = NoteRepository(db, audio);

    final BackgroundSync background = BackgroundSync()..configure();

    // The transcriber is rebuilt per use so a key or model changed in settings
    // takes effect on the very next note, with no restart and no stale client.
    Transcriber buildTranscriber() {
      if (settings.backend != 'whisper') return const UnconfiguredTranscriber();
      return WhisperTranscriber(
        apiKey: settings.apiKey,
        model: settings.model,
      );
    }

    return Services(
      db: db,
      settings: settings,
      notes: notes,
      audio: audio,
      partials: partials,
      scanner: JotaScanner(),
      sync: SyncEngine(notes: notes, partials: partials, audio: audio),
      background: background,
      transcription: TranscriptionQueue(
        notes: notes,
        audio: audio,
        settings: settings,
        transcriber: buildTranscriber,
      ),
    );
  }

  Future<void> dispose() async {
    await scanner.dispose();
    await sync.dispose();
    await transcription.dispose();
    await background.dispose();
    await db.close();
  }
}
