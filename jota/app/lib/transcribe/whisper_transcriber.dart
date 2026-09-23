// ============================================================================
//  Jota — on-device transcription with whisper.cpp
//
//  The audio never leaves the phone. problem.md calls privacy a FUNCTIONAL
//  requirement, not a feature: if you are not sure where a recording goes you
//  speak differently, and a thought you softened while saying it is not the
//  thought. This backend is the only one that can make that promise without
//  qualification.
//
//  The multilingual `small` model, language detected per note. It replaced
//  `tiny.en` on 2026-09-23 after the first real recording: "test test one two
//  three" came back as "just just just 1 2 3" from tiny.en, while the same WAV
//  read correctly through base.en, small.en, small and medium on a laptop.
//  tiny was the whole problem, not the microphone. Sudanese Arabic mixed with
//  English is what this device actually hears, which rules the .en models out
//  and makes `small` the smallest one worth running; `medium` is the next
//  step up if `small` proves too weak on dialect, at three times the size
//  and time.
//
//  The model is downloaded once, on first use, rather than shipped in the APK:
//  466 MB of weights in the bundle would be paid for by every install
//  including the ones that never record anything.
// ============================================================================
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'transcriber.dart';

class WhisperTranscriber implements Transcriber {
  WhisperTranscriber({WhisperModel model = WhisperModel.small})
      : _model = model;

  final WhisperModel _model;
  final WhisperController _controller = WhisperController();

  @override
  String get id => 'whisper-${_model.modelName}';

  @override
  String get displayName => 'On device (${_model.modelName})';

  /// Ready only once the weights are actually on disk.
  ///
  /// The queue checks this before dequeuing, so a note is never marked failed
  /// because a download had not finished — that reads as "your recording was
  /// no good" when the truth is "the app is not set up yet".
  @override
  Future<bool> get isReady async {
    final String path = await _controller.getPath(_model);
    return File(path).existsSync();
  }

  /// Fetch the weights. Safe to call repeatedly; it returns immediately once
  /// they are present.
  Future<void> ensureModel() async {
    if (await isReady) return;
    debugPrint('jota/stt  downloading ${_model.modelName}…');
    await _controller.downloadModel(_model);
    debugPrint('jota/stt  ${_model.modelName} ready');
  }

  @override
  Future<TranscriptionResult> transcribe(TranscriptionRequest request) async {
    await ensureModel();

    // whisper.cpp reads a file, and what we hold is bytes. Written to the
    // cache directory rather than anywhere permanent: this WAV is a decode of
    // audio the archive already holds, so it is scratch, and the note's real
    // copy is the ADPCM.
    final Directory dir = await getTemporaryDirectory();
    final File wav = File('${dir.path}/${request.filename}');
    await wav.writeAsBytes(request.wav, flush: true);

    // The stored hint, or detection. A hint measurably helps `small` on short
    // clips and on dialect: told "ar" it stops trying English on a Sudanese
    // sentence with an English word in it.
    final String lang = (request.language == null || request.language!.isEmpty)
        ? 'auto'
        : request.language!;

    try {
      // `var`, because whisper_ggml does not export TranscribeResult from its
      // public API — only the response type inside it. Naming it would mean
      // importing a src/ path, which is the package's private business and
      // would break on any of its releases.
      final out = await _controller.transcribe(
        model: _model,
        audioPath: wav.path,
        // whisper.cpp detects the language from the first 30 s when told
        // 'auto'. A note that switches Arabic->English mid-sentence is still
        // decoded by one model pass; the language only seeds it.
        lang: lang,
        // The note's own context, when the caller has any: names and jargon
        // measurably help on short clips, and short clips are most of what
        // this device records.
        initialPrompt: request.prompt,
        // Whisper emits things like "(wind blowing)" for non-speech. On a
        // pocket recorder that is nearly all of the false output.
        suppressNonSpeechTokens: true,
      );

      if (out == null) {
        throw const TranscriptionException(
          TranscriptionFailure.badAudio,
          'whisper could not read this recording',
        );
      }

      return TranscriptionResult(
        text: out.transcription.text.trim(),
        model: id,
        language: lang,
        durationSeconds: out.time.inMilliseconds / 1000.0,
      );
    } finally {
      // Scratch, so it goes even when the decode threw.
      if (wav.existsSync()) {
        try {
          await wav.delete();
        } on FileSystemException {
          // A leftover file in the cache directory is the OS's problem, not
          // something worth failing a transcription over.
        }
      }
    }
  }
}
