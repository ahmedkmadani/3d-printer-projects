// ============================================================================
//  Jota — silent playback for the web preview
//
//  Advances a position at 1x and makes no sound. It exists so the playback bar's
//  layout, its `00:12 / 00:47` figures, its stadium button and its scrubber can
//  all be judged; it tests nothing about audio.
// ============================================================================
import 'dart:async';

import '../audio/note_player.dart';
import 'seed_data.dart';

class FakeNotePlayer implements NotePlayer {
  FakeNotePlayer({required this.durationFor});

  /// How long a given note is, in seconds. Supplied by the preview graph so the
  /// fake agrees with what the note list says.
  final int Function(String deviceId, int noteId) durationFor;

  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();

  Timer? _ticker;
  Duration _at = Duration.zero;
  Duration? _duration;
  bool _playing_ = false;

  static const Duration _tick = Duration(milliseconds: 200);

  @override
  Future<bool> load(String deviceId, int noteId) async {
    // A beat of latency, because the real one decodes ADPCM here and the button's
    // busy state should be visible in the preview too.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final int secs = durationFor(deviceId, noteId);
    if (secs <= 0) return false;
    _duration = Duration(seconds: secs);
    _at = Duration.zero;
    return true;
  }

  @override
  Future<void> play() async {
    if (_playing_) return;
    _playing_ = true;
    if (!_playing.isClosed) _playing.add(true);
    _ticker = Timer.periodic(_tick, (_) {
      _at += _tick;
      final Duration? total = _duration;
      if (total != null && _at >= total) _at = total;
      if (!_position.isClosed) _position.add(_at);
    });
  }

  @override
  Future<void> pause() async {
    _ticker?.cancel();
    _ticker = null;
    if (!_playing_) return;
    _playing_ = false;
    if (!_playing.isClosed) _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    _at = position;
    if (!_position.isClosed) _position.add(_at);
  }

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<bool> get playingChanges => _playing.stream;

  @override
  bool get playing => _playing_;

  @override
  Duration? get duration => _duration;

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    await _position.close();
    await _playing.close();
  }
}

/// Stands in for the network round trip to Whisper.
///
/// Returns the line the seed data says this note contains, so a note pulled
/// during the simulated sync gains its transcript a second later, the way it
/// would in the real app.
String previewTranscriptOrDefault(int noteId) {
  return previewTranscriptFallback[noteId % previewTranscriptFallback.length];
}

/// Used only when a note has no scripted line — a manually added note, or one the
/// user creates by re-running the sync.
const List<String> previewTranscriptFallback = <String>[
  'remember to move the sensor two millimetres inboard',
  'ask about the lead time on the flexible PCB',
  'the hairline is one pixel and it stays one pixel',
];

/// Re-exported so callers do not need to reach into fake_device.dart for it.
const String previewPairCode = kPreviewPairCode;
