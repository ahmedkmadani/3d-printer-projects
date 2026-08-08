// ============================================================================
//  Jota — playback interface
//
//  Small on purpose: load a note, play, pause, seek, and tell me where you are.
//  The real implementation decodes the ADPCM archive to a WAV and hands it to
//  just_audio; the preview one advances a timer and makes no sound. The playback
//  bar cannot tell the difference, which is the whole point.
// ============================================================================
abstract class NotePlayer {
  /// Prepare a note for playback. False when the audio could not be loaded — a
  /// missing archive file is a UI state, not a crash.
  Future<bool> load(String deviceId, int noteId);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  /// Ticks while playing. The bar renders `00:47` from this.
  Stream<Duration> get position;

  /// Fires whenever [playing] changes, so the button can flip.
  Stream<bool> get playingChanges;

  bool get playing;

  /// Known only after [load], and only when the source reports it. The bar falls
  /// back to the duration the index gave us.
  Duration? get duration;

  Future<void> dispose();
}
