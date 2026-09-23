// ============================================================================
//  Jota — transcription queue
//
//  Notes arrive from the device in bursts and the network is not always there,
//  so transcription is a queue rather than a step in the sync. A note is stored
//  and playable the moment its CRC checks out; the text catches up.
//
//  Serial, deliberately. Three concurrent uploads from a phone that just woke
//  up is how you get rate limited, and the user is reading the notes one at a
//  time anyway.
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../data/audio_store.dart';
import '../data/note.dart';
import '../data/note_repository.dart';
import '../data/settings_store.dart';
import '../ble/background_sync.dart';
import 'done_notifier.dart';
import 'transcriber.dart';

class TranscriptionQueue {
  TranscriptionQueue({
    required NoteRepository notes,
    required AudioStore audio,
    required SettingsStore settings,
    required Transcriber Function() transcriber,
    TranscriptionNotifier? notifier,
    BackgroundSyncController? keepAlive,
  })  : _notes = notes,
        _audio = audio,
        _settings = settings,
        _transcriber = transcriber,
        _notifier = notifier,
        _keepAlive = keepAlive;

  final NoteRepository _notes;
  final AudioStore _audio;
  final SettingsStore _settings;

  /// Tells the user when a note's words land while the app is not on screen.
  /// Null in the preview and in tests.
  final TranscriptionNotifier? _notifier;

  /// The foreground service, held for as long as a job runs. Whisper takes
  /// minutes per note on this phone and the OS kills a backgrounded app well
  /// inside that (seen on 2026-09-23: the process was gone within five
  /// minutes, the note stuck at "Transcribing…"). A foreground service is
  /// the one thing Android will not kill. Started only if the user has not
  /// already turned background sync on, and stopped again afterwards.
  final BackgroundSyncController? _keepAlive;
  int _active = 0;
  bool _startedService = false;

  Future<void> _hold(Note note) async {
    _active++;
    final BackgroundSyncController? k = _keepAlive;
    if (k == null) return;
    if (_active == 1 && k.mode == BackgroundMode.off) {
      final BackgroundMode got = await k.enable();
      _startedService = got == BackgroundMode.foregroundService;
      debugPrint('jota/queue  keep-alive: $got');
    }
    await k.report('Transcribing ${note.displayId}…');
  }

  Future<void> _release() async {
    _active--;
    final BackgroundSyncController? k = _keepAlive;
    if (k == null || _active > 0) return;
    if (_startedService) {
      _startedService = false;
      await k.disable();
    } else {
      await k.report('Listening for notes');
    }
  }

  /// A factory, not an instance: the user can change the key or the model in
  /// settings between two items in the queue.
  final Transcriber Function() _transcriber;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires whenever a note's transcript state changes, so the list can refresh.
  Stream<void> get changes => _changes.stream;

  bool _draining = false;
  bool get isDraining => _draining;

  final Set<int> _inFlight = <int>{};

  bool isRunningFor(Note note) => _inFlight.contains(note.rowId ?? -1);

  /// Work through everything pending. Safe to call repeatedly — after a sync,
  /// on app resume, on a manual retry.
  Future<void> drain() async {
    if (_draining) return;
    if (!_settings.autoTranscribe) return;

    final Transcriber t = _transcriber();
    if (!await t.isReady) {
      debugPrint('jota/queue  transcriber not ready; leaving notes pending');
      return; // no key: leave the notes pending, not failed
    }

    _draining = true;
    try {
      final List<Note> queue = await _notes.awaitingTranscription();
      debugPrint('jota/queue  drain: ${queue.length} waiting');
      if (queue.isNotEmpty) await _notifier?.prepare();
      for (final Note note in queue) {
        final bool keepGoing = await _transcribeOne(note, t);
        if (!keepGoing) break; // rate limited or offline: stop, try later
      }
    } finally {
      _draining = false;
    }
  }

  /// Transcribe one note now, regardless of the auto-transcribe setting. This
  /// is the "TRANSCRIBE" button on the detail screen.
  Future<void> transcribeNow(Note note) async {
    await _notifier?.prepare();
    await _transcribeOne(note, _transcriber());
  }

  /// Returns false when the queue should stop for now.
  Future<bool> _transcribeOne(Note note, Transcriber t) async {
    final int key = note.rowId ?? note.noteId;
    if (_inFlight.contains(key)) return true;
    _inFlight.add(key);
    await _hold(note);

    await _notes.setTranscriptState(note, TranscriptState.running);
    _changes.add(null);

    try {
      // The archive is ADPCM; every backend wants a container. Decode once,
      // cache the WAV — the user is likely to hit play on this note next.
      final wav = await _audio.wavBytes(note.deviceId, note.noteId);
      if (wav == null) {
        await _notes.setTranscriptState(
          note,
          TranscriptState.failed,
          error: 'audio file is missing',
        );
        return true;
      }

      final TranscriptionResult r = await t.transcribe(
        TranscriptionRequest(
          wav: wav,
          filename: '${note.displayId}.wav',
          language: _settings.language,
        ),
      );

      if (r.isEmpty) {
        // Whisper returns an empty string for silence — and for the synthesised
        // tone the dummy notes contain. That is a real outcome, not an error,
        // so it is recorded as done-with-no-speech rather than failed, which
        // would put it back in the retry queue forever.
        await _notes.setTranscript(note, '', model: r.model);
      } else {
        await _notes.setTranscript(note, r.text, model: r.model);
        final Note? done = await _notes.byId(note.deviceId, note.noteId);
        if (done != null) await _notifier?.transcribed(done);
      }
      return true;
    } on TranscriptionException catch (e) {
      await _notes.setTranscriptState(
        note,
        TranscriptState.failed,
        error: e.userMessage,
      );
      // A bad key or a rate limit will fail identically for every other note in
      // the queue. Stop rather than burning the whole backlog.
      return !(e.failure == TranscriptionFailure.unauthorized ||
          e.failure == TranscriptionFailure.rateLimited ||
          e.failure == TranscriptionFailure.network ||
          e.failure == TranscriptionFailure.notConfigured);
    } on Exception catch (e) {
      await _notes.setTranscriptState(
        note,
        TranscriptState.failed,
        error: e.toString(),
      );
      return true;
    } finally {
      _inFlight.remove(key);
      _changes.add(null);
      await _release();
    }
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}
