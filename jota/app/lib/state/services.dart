// ============================================================================
//  Jota — service container
//
//  Everything long-lived, built once at startup and handed down with provider.
//  There is no dependency-injection framework here on purpose: the object graph is
//  a dozen nodes and completely static, so a constructor says it more clearly
//  than annotations would.
//
//  Every field is an INTERFACE. That is what lets `main.dart` assemble the real
//  thing over BLE and sqflite while `main_preview.dart` assembles fakes and runs
//  the identical screens in a browser.
// ============================================================================
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../audio/decoded_note_player.dart';
import '../audio/note_player.dart';
import '../ble/background_sync.dart';
import '../ble/device_scanner.dart';
import '../ble/foreground_background_sync.dart';
import '../ble/jota_scanner.dart';
import '../ble/sync_engine.dart';
import '../ble/sync_service.dart';
import '../data/audio_store.dart';
import '../data/database.dart';
import '../data/file_audio_store.dart';
import '../data/file_partial_store.dart';
import '../data/note_repository.dart';
import '../data/partial_store.dart';
import '../data/prefs_settings_store.dart';
import '../data/settings_store.dart';
import '../data/sqflite_note_repository.dart';
import '../security/authenticator.dart';
import '../security/local_authenticator.dart';
import '../transcribe/transcriber.dart';
import '../transcribe/transcription_queue.dart';
import '../transcribe/google_stt_transcriber.dart';
import '../transcribe/whisper_transcriber.dart';

class Services {
  Services({
    required this.settings,
    required this.notes,
    required this.audio,
    required this.partials,
    required this.scanner,
    required this.sync,
    required this.background,
    required this.transcription,
    required this.auth,
    required this.newPlayer,
    this.isPreview = false,
  });

  final SettingsStore settings;
  final NoteRepository notes;
  final AudioStore audio;
  final PartialStore partials;
  final DeviceScanner scanner;
  final SyncService sync;
  final BackgroundSyncController background;
  final TranscriptionQueue transcription;

  /// The biometric / passcode gate behind the app lock (Settings ▸ Privacy).
  final Authenticator auth;

  /// A factory, because the playback bar owns its player's lifetime.
  final NotePlayer Function() newPlayer;

  /// True when the graph is made of fakes. Screens use it only to add the one
  /// banner that says so — no other behaviour branches on it.
  final bool isPreview;

  /// The real graph: BLE, sqflite, the filesystem, the Keychain.
  static Future<Services> boot() async {
    // iOS state restoration must be requested before any other BLE call.
    await JotaScanner.configureForBackground();

    final Directory support = await getApplicationSupportDirectory();
    final Directory cache = await getTemporaryDirectory();

    final Database db = await JotaDatabase.open();
    final SettingsStore settings = await PrefsSettingsStore.open();
    final AudioStore audio = await FileAudioStore.open(
      appSupport: support,
      cacheDir: cache,
    );
    final PartialStore partials = await FilePartialStore.open(support);
    final NoteRepository notes = SqfliteNoteRepository(db, audio);

    final BackgroundSyncController background =
        ForegroundServiceBackgroundSync()..configure();

    // The transcriber is rebuilt per use so a key or model changed in settings
    // takes effect on the very next note, with no restart and no stale client.
    Transcriber buildTranscriber() {
      // On device first, because it is the only backend that can promise the
      // audio never leaves the phone — and problem.md calls that a functional
      // requirement, not a feature. The multilingual small model reads Arabic
      // and English; the cloud path stays as a fallback behind a flag.
      if (settings.backend == 'device') return WhisperTranscriber();
      if (settings.backend != 'google') return const UnconfiguredTranscriber();
      return GoogleSttTranscriber(
        apiKey: settings.apiKey,
        model: settings.model,
        // Sudanese Arabic has no code of its own at Google; Egyptian is the
        // closest supported neighbour, and English rides alongside because
        // that is how these notes are actually spoken. Both are settings, so
        // trying a different pair is not a rebuild.
        language: settings.language ?? 'ar-EG',
      );
    }

    return Services(
      settings: settings,
      notes: notes,
      audio: audio,
      partials: partials,
      scanner: JotaScanner(),
      sync: SyncEngine(
        notes: notes,
        partials: partials,
        audio: audio,
        settings: settings,
      ),
      background: background,
      transcription: TranscriptionQueue(
        notes: notes,
        audio: audio,
        settings: settings,
        transcriber: buildTranscriber,
      ),
      auth: LocalAuthenticator(),
      newPlayer: () => DecodedNotePlayer(audio),
    );
  }

  Future<void> dispose() async {
    await scanner.dispose();
    await sync.dispose();
    await transcription.dispose();
    await background.dispose();
    await notes.close();
  }
}
