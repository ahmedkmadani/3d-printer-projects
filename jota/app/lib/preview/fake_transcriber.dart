// ============================================================================
//  Jota — a simulated transcription backend
//
//  Implements the same Transcriber interface as GoogleSttTranscriber, so the queue,
//  the running/failed/done states and the detail screen's TRANSCRIBE button are
//  all driven by the real code. It just answers from a script instead of from a
//  network.
//
//  It honours the API key the way the real one does: with no key it reports
//  `notConfigured`, so the "add a key in Settings" path is walkable in a browser.
// ============================================================================
import '../data/settings_store.dart';
import '../transcribe/transcriber.dart';
import 'fake_device.dart';
import 'fake_playback.dart';

class FakeTranscriber implements Transcriber {
  FakeTranscriber(this._settings);

  final SettingsStore _settings;

  @override
  String get id => 'preview';

  @override
  String get displayName => 'Simulated speech-to-text (preview)';

  @override
  Future<bool> get isReady => _settings.hasApiKey();

  @override
  Future<TranscriptionResult> transcribe(TranscriptionRequest request) async {
    if (!await isReady) {
      throw const TranscriptionException(
        TranscriptionFailure.notConfigured,
        'no API key',
      );
    }

    // A believable round trip, so the note list's "Transcribing…" row is on
    // screen long enough to look at.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    // The queue names the upload after the note (`N-013.wav`), which is the one
    // piece of note identity the Transcriber interface carries. Enough to look up
    // what this recording is scripted to contain.
    final RegExpMatch? m = RegExp(r'N-(\d+)').firstMatch(request.filename);
    final int noteId = m == null ? 0 : (int.tryParse(m.group(1)!) ?? 0);

    final String? scripted = previewTranscriptFor(noteId);
    return TranscriptionResult(
      text: scripted ?? previewTranscriptOrDefault(noteId),
      model: 'preview',
      language: 'en',
      durationSeconds: null,
    );
  }
}
