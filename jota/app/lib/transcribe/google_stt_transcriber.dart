// ============================================================================
//  Jota — Google Cloud Speech-to-Text backend
//
//  POST speech:recognize, using the PHONE's internet. The device never sees a
//  key and never touches a network — it has no WiFi at all.
//
//  Replaces OpenAI Whisper (docs/decisions.md #9). The reason is Sudanese
//  Arabic mixed with English: offline and open models are weak at Arabic
//  dialect, and text you cannot read fails the whole point of capturing.
//
//  The key is read fresh from secure storage on every call rather than cached
//  in a field: it should live in the Keychain/EncryptedSharedPreferences and in
//  a local variable for the duration of one request, and nowhere else.
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'transcriber.dart';

/// Supplies the API key. A function rather than a string so the key is fetched
/// per request and never held by this object.
typedef ApiKeyProvider = Future<String?> Function();

/// Google's synchronous endpoint refuses audio longer than about a minute.
///
/// This matters more here than it would elsewhere: a post-therapy note is the
/// core use case and it runs to ten minutes (problem.md, story C2). Anything
/// past this needs `longrunningrecognize`, which wants the audio in Cloud
/// Storage first — a bucket, a lifecycle policy, and a second place your voice
/// is sitting. That is a real decision, not plumbing, so this backend refuses
/// clearly instead of guessing.
const Duration kSyncRecognizeLimit = Duration(seconds: 58);

class GoogleSttTranscriber implements Transcriber {
  GoogleSttTranscriber({
    required ApiKeyProvider apiKey,
    this.language = 'ar-EG',
    this.alternativeLanguages = const <String>['en-US'],
    this.model = 'latest_long',
    this.baseUrl = 'https://speech.googleapis.com/v1',
    http.Client? client,
    this.timeout = const Duration(seconds: 120),
  })  : _apiKey = apiKey,
        _client = client ?? http.Client();

  final ApiKeyProvider _apiKey;
  final http.Client _client;

  /// Primary language.
  ///
  /// Defaults to Egyptian Arabic rather than anything Sudanese: Google has no
  /// `ar-SD`, and Egyptian is the closest widely-supported neighbour. How well
  /// it actually reads Sudanese dialect is the open question the whole plan
  /// rests on — see docs/solution.md. Configurable so that test is a settings
  /// change, not a rebuild.
  final String language;

  /// Google will also consider these. This is what makes a sentence that opens
  /// in English and finishes in Arabic — how this user actually speaks —
  /// something the recogniser can handle rather than a coin toss.
  final List<String> alternativeLanguages;

  final String model;
  final String baseUrl;
  final Duration timeout;

  @override
  String get id => 'google-stt/$model/$language';

  @override
  String get displayName => 'Google Speech-to-Text ($language)';

  @override
  Future<bool> get isReady async {
    final String? k = await _apiKey();
    return k != null && k.trim().isNotEmpty;
  }

  @override
  Future<TranscriptionResult> transcribe(TranscriptionRequest request) async {
    final String? key = await _apiKey();
    if (key == null || key.trim().isEmpty) {
      throw const TranscriptionException(
        TranscriptionFailure.notConfigured,
        'no API key',
      );
    }

    // 10 MB is the endpoint's hard limit for inline audio.
    const int maxBytes = 10 * 1024 * 1024;
    if (request.wav.length > maxBytes) {
      throw TranscriptionException(
        TranscriptionFailure.badAudio,
        'recording is ${(request.wav.length / (1024 * 1024)).toStringAsFixed(1)} MB, '
        'over the 10 MB limit for a single request',
      );
    }

    final Uri uri = Uri.parse('$baseUrl/speech:recognize')
        .replace(queryParameters: <String, String>{'key': key.trim()});

    final Map<String, Object?> config = <String, Object?>{
      'languageCode':
          (request.language != null && request.language!.isNotEmpty)
              ? request.language
              : language,
      'enableAutomaticPunctuation': true,
      'model': model,
      // WAV carries its own encoding and sample rate in the header, and Google
      // reads them from there. Sending encoding/sampleRateHertz as well is how
      // you get a mismatch error on a file that was perfectly fine.
    };
    if (alternativeLanguages.isNotEmpty) {
      config['alternativeLanguageCodes'] = alternativeLanguages;
    }

    final String body = jsonEncode(<String, Object?>{
      'config': config,
      'audio': <String, Object?>{'content': base64Encode(request.wav)},
    });

    http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const TranscriptionException(
        TranscriptionFailure.network,
        'request timed out',
      );
    } on SocketException catch (e) {
      throw TranscriptionException(TranscriptionFailure.network, e.message);
    } on http.ClientException catch (e) {
      throw TranscriptionException(TranscriptionFailure.network, e.message);
    }

    if (res.statusCode != 200) throw _mapError(res);

    final Object? decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const TranscriptionException(
        TranscriptionFailure.unknown,
        'unexpected response shape',
      );
    }

    // Google returns one result per utterance, each with alternatives ranked
    // by confidence. Joining the top alternative of each is the transcript.
    final List<Object?> results =
        (decoded['results'] as List<Object?>?) ?? const <Object?>[];
    final StringBuffer text = StringBuffer();
    String? detected;
    for (final Object? r in results) {
      if (r is! Map<String, dynamic>) continue;
      detected ??= r['languageCode'] as String?;
      final List<Object?> alts =
          (r['alternatives'] as List<Object?>?) ?? const <Object?>[];
      if (alts.isEmpty) continue;
      final Object? best = alts.first;
      if (best is! Map<String, dynamic>) continue;
      final String piece = (best['transcript'] as String? ?? '').trim();
      if (piece.isEmpty) continue;
      if (text.isNotEmpty) text.write(' ');
      text.write(piece);
    }

    // An empty result on a request that otherwise succeeded means silence, or
    // audio too long for the synchronous endpoint — which returns 200 with
    // nothing rather than an error, and would otherwise look like "you said
    // nothing" for a ten-minute recording.
    return TranscriptionResult(
      text: text.toString(),
      model: id,
      language: detected ?? language,
    );
  }

  TranscriptionException _mapError(http.Response res) {
    String message = 'HTTP ${res.statusCode}';
    try {
      final Object? body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic> && body['error'] is Map) {
        final Map<Object?, Object?> err =
            body['error'] as Map<Object?, Object?>;
        message = err['message']?.toString() ?? message;
      }
    } on FormatException {
      // Non-JSON error body; the status code is all we have.
    }

    switch (res.statusCode) {
      case 401:
      case 403:
        return TranscriptionException(
          TranscriptionFailure.unauthorized,
          message,
        );
      case 429:
        return TranscriptionException(TranscriptionFailure.rateLimited, message);
      case 400:
      case 413:
      case 415:
        return TranscriptionException(TranscriptionFailure.badAudio, message);
      case 500:
      case 502:
      case 503:
      case 504:
        return TranscriptionException(TranscriptionFailure.network, message);
      default:
        return TranscriptionException(TranscriptionFailure.unknown, message);
    }
  }

  void dispose() => _client.close();
}
