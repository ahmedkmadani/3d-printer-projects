// ============================================================================
//  Jota — the preview service graph
//
//  The same Services object main.dart builds, with every dependency swapped for
//  an in-memory or simulated one. Nothing below this file knows the difference:
//  the controllers, the screens and the design system are the shipping code.
// ============================================================================
import '../data/note.dart';
import '../state/services.dart';
import '../transcribe/transcriber.dart';
import '../transcribe/transcription_queue.dart';
import 'fake_authenticator.dart';
import 'fake_device.dart';
import 'fake_playback.dart';
import 'fake_transcriber.dart';
import 'in_memory_stores.dart';
import 'seed_data.dart';

abstract final class PreviewServices {
  static Future<Services> boot() async {
    final InMemoryAudioStore audio = InMemoryAudioStore();
    final List<Note> seed = seedNotes(audio);

    final InMemoryNoteRepository notes = InMemoryNoteRepository(
      audio,
      seed: seed,
    );
    final InMemoryPartialStore partials = InMemoryPartialStore();

    // Starts UNPAIRED and with no API key on purpose: those two empty states are
    // the first thing a new user sees, and the pair flow is one of the things
    // this preview exists to show.
    final InMemorySettingsStore settings = InMemorySettingsStore(
      tags: <String>['WORK', 'BUY', 'IDEA', 'LATER'],
    );

    final FakeJota device = FakeJota();

    // Durations come from the repository so the silent player agrees with what
    // the list says, rather than inventing its own.
    int durationFor(String deviceId, int noteId) {
      for (final Note n in seed) {
        if (n.noteId == noteId) return n.secs;
      }
      for (final PendingNote p in kPendingOnDevice) {
        if (p.id == noteId) return p.secs;
      }
      return 0;
    }

    Transcriber buildTranscriber() => FakeTranscriber(settings);

    return Services(
      settings: settings,
      notes: notes,
      audio: audio,
      partials: partials,
      scanner: FakeScanner(device),
      sync: FakeSyncService(device: device, notes: notes, audio: audio),
      background: FakeBackgroundSync(),
      transcription: TranscriptionQueue(
        notes: notes,
        audio: audio,
        settings: settings,
        transcriber: buildTranscriber,
      ),
      auth: FakeAuthenticator(),

      newPlayer: () => FakeNotePlayer(durationFor: durationFor),
      isPreview: true,
    );
  }
}
