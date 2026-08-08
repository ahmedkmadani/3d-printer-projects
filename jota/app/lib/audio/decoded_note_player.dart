// ============================================================================
//  Jota — the real NotePlayer
//
//  Decodes the ADPCM archive to a PCM WAV (cached by the AudioStore) and plays it
//  through just_audio. The first tap on a long note pays for the decode; every
//  later one does not.
// ============================================================================
import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../data/audio_store.dart';
import 'note_player.dart';

class DecodedNotePlayer implements NotePlayer {
  DecodedNotePlayer(this._audio);

  final AudioStore _audio;
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<bool> load(String deviceId, int noteId) async {
    final String? path = await _audio.ensureWavPath(deviceId, noteId);
    if (path == null) return false;
    await _player.setFilePath(path);
    return true;
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<bool> get playingChanges => _player.playingStream;

  @override
  bool get playing => _player.playing;

  @override
  Duration? get duration => _player.duration;

  @override
  Future<void> dispose() => _player.dispose();
}
