// ============================================================================
//  Jota — transcription interface
//
//  The device records; the phone turns audio into text. WHICH service does that
//  is a detail, and it is deliberately behind this interface: Whisper today, a
//  local on-device model tomorrow, someone's self-hosted endpoint after that.
//  Nothing outside lib/transcribe/ knows the difference.
//
//  The contract is narrow on purpose — one method, WAV in, text out. Anything
//  richer (diarisation, timestamps, streaming partials) would be a promise most
//  backends cannot keep.
// ============================================================================
import 'dart:typed_data';

/// A request to turn one note into text.
class TranscriptionRequest {
  const TranscriptionRequest({
    required this.wav,
    required this.filename,
    this.language,
    this.prompt,
  });

  /// 16-bit PCM WAV. Callers decode the device's ADPCM first (see
  /// lib/audio/) — no backend should be expected to know Jota's codec.
  final Uint8List wav;

  /// Used as the upload's filename. Some endpoints sniff the extension.
  final String filename;

  /// ISO-639-1 hint. Optional, but it measurably helps on short clips, and
  /// short clips are most of what this device records.
  final String? language;

  /// Optional context to bias the decoder — names, jargon, the previous note.
  final String? prompt;
}

class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.model,
    this.language,
    this.durationSeconds,
  });

  final String text;

  /// Recorded on the note so a later re-run with a better model is a visible
  /// change rather than a mystery.
  final String model;

  final String? language;
  final double? durationSeconds;

  bool get isEmpty => text.trim().isEmpty;
}

/// Failure modes worth telling apart, because the UI's response differs:
/// a missing key is a settings problem, a rate limit is a wait, and a network
/// error is a retry.
enum TranscriptionFailure {
  /// No API key configured, or the backend is not set up.
  notConfigured,

  /// The key was rejected.
  unauthorized,

  /// Rate limited or out of quota. Retry later.
  rateLimited,

  /// The audio was rejected — too long, too large, wrong format.
  badAudio,

  /// Network or timeout. Retry.
  network,

  /// Anything else.
  unknown,
}

class TranscriptionException implements Exception {
  const TranscriptionException(this.failure, this.message);

  final TranscriptionFailure failure;
  final String message;

  /// Whether trying the exact same request again could plausibly work.
  bool get isRetryable =>
      failure == TranscriptionFailure.network ||
      failure == TranscriptionFailure.rateLimited;

  /// What the note detail screen shows under a failed transcript.
  String get userMessage {
    switch (failure) {
      case TranscriptionFailure.notConfigured:
        return 'Add an API key in Settings to transcribe notes.';
      case TranscriptionFailure.unauthorized:
        return 'The API key was rejected. Check it in Settings.';
      case TranscriptionFailure.rateLimited:
        return 'Rate limited. Jota will try again later.';
      case TranscriptionFailure.badAudio:
        return 'The service could not read this recording.';
      case TranscriptionFailure.network:
        return 'No connection. Jota will try again later.';
      case TranscriptionFailure.unknown:
        return message;
    }
  }

  @override
  String toString() => 'TranscriptionException($failure): $message';
}

/// Implement this to add a backend.
abstract class Transcriber {
  /// Stable identifier, stored on the note. e.g. `whisper-1`.
  String get id;

  /// Shown in settings.
  String get displayName;

  /// False when the backend cannot run — no key, no model downloaded. The
  /// queue checks this before dequeuing work so notes are not marked failed
  /// for a reason the user has not been told about.
  Future<bool> get isReady;

  Future<TranscriptionResult> transcribe(TranscriptionRequest request);
}

/// The stand-in when nothing is configured.
///
/// Exists so the rest of the app never has to null-check a Transcriber, and so
/// "no key yet" produces a clear message instead of a crash.
class UnconfiguredTranscriber implements Transcriber {
  const UnconfiguredTranscriber();

  @override
  String get id => 'none';

  @override
  String get displayName => 'Not configured';

  @override
  Future<bool> get isReady async => false;

  @override
  Future<TranscriptionResult> transcribe(TranscriptionRequest request) async {
    throw const TranscriptionException(
      TranscriptionFailure.notConfigured,
      'no transcription backend configured',
    );
  }
}
