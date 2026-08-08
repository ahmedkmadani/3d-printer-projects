// ============================================================================
//  Jota — OpenAI Whisper backend
//
//  POST /v1/audio/transcriptions, multipart, using the PHONE's internet. The
//  device never sees a key and never touches a network — it has no WiFi at all.
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

class WhisperTranscriber implements Transcriber {
  WhisperTranscriber({
    required ApiKeyProvider apiKey,
    this.model = 'whisper-1',
    this.baseUrl = 'https://api.openai.com/v1',
    http.Client? client,
    this.timeout = const Duration(seconds: 120),
  })  : _apiKey = apiKey,
        _client = client ?? http.Client();

  final ApiKeyProvider _apiKey;
  final http.Client _client;

  /// `whisper-1` is the general-availability transcription model. The newer
  /// `gpt-4o-transcribe` / `gpt-4o-mini-transcribe` models take the same
  /// multipart request and can be selected in settings.
  final String model;

  /// Overridable so a self-hosted whisper.cpp server speaking the same shape
  /// can be dropped in without touching this file.
  final String baseUrl;

  final Duration timeout;

  @override
  String get id => model;

  @override
  String get displayName => 'OpenAI Whisper ($model)';

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

    // 25 MB is the endpoint's hard limit. At 16 kHz 16-bit mono that is about
    // 13 minutes of WAV — longer than this device is meant to record, but a
    // clear message beats a 413 from a server.
    const int maxBytes = 25 * 1024 * 1024;
    if (request.wav.length > maxBytes) {
      throw TranscriptionException(
        TranscriptionFailure.badAudio,
        'recording is ${(request.wav.length / (1024 * 1024)).toStringAsFixed(1)} MB, '
        'over the 25 MB limit',
      );
    }

    final Uri uri = Uri.parse('$baseUrl/audio/transcriptions');
    final http.MultipartRequest req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${key.trim()}'
      ..fields['model'] = model
      // `verbose_json` also returns the detected language and duration, which
      // are worth storing; `json` would give only the text.
      ..fields['response_format'] = 'verbose_json'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          request.wav,
          filename: request.filename,
        ),
      );

    if (request.language != null && request.language!.isNotEmpty) {
      req.fields['language'] = request.language!;
    }
    if (request.prompt != null && request.prompt!.isNotEmpty) {
      req.fields['prompt'] = request.prompt!;
    }

    http.Response res;
    try {
      final http.StreamedResponse streamed =
          await _client.send(req).timeout(timeout);
      res = await http.Response.fromStream(streamed);
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

    if (res.statusCode != 200) {
      throw _mapError(res);
    }

    final Object? body = jsonDecode(utf8.decode(res.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const TranscriptionException(
        TranscriptionFailure.unknown,
        'unexpected response shape',
      );
    }

    return TranscriptionResult(
      text: (body['text'] as String? ?? '').trim(),
      model: model,
      language: body['language'] as String?,
      durationSeconds: (body['duration'] as num?)?.toDouble(),
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
        return TranscriptionException(
          TranscriptionFailure.rateLimited,
          message,
        );
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
