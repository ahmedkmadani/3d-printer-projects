// ============================================================================
//  Jota — sync interface and progress model
//
//  What a sync run looks like from the outside. Split from the engine so the
//  screens can be driven by a simulation as well as by a radio, and so the
//  progress model — which the UI leans on heavily — is defined somewhere that
//  does not import flutter_blue_plus.
//
//  Note the identity of a device here is a plain `String remoteId`, not a
//  BluetoothDevice. The caller already has the id (it is in settings); handing
//  the engine an opaque platform object bought nothing.
// ============================================================================

/// Where a sync run is.
enum SyncPhase {
  idle,
  connecting,
  authenticating,
  settingClock,
  readingIndex,
  transferring,
  verifying,
  finishing,
  done,
  failed,
}

/// A snapshot of the run, for the UI. Mirrors what the device's own SYNC screen
/// shows: a ratio in the status slot and one progress bar.
class SyncProgress {
  const SyncProgress({
    required this.phase,
    this.notesDone = 0,
    this.notesTotal = 0,
    this.currentNoteId,
    this.bytesReceived = 0,
    this.bytesExpected = 0,
    this.message,
    this.error,
    this.resumed = false,
  });

  final SyncPhase phase;

  /// Notes fully verified and acked this run.
  final int notesDone;

  /// Notes the index offered that we still needed.
  final int notesTotal;

  final int? currentNoteId;
  final int bytesReceived;
  final int bytesExpected;
  final String? message;
  final String? error;

  /// True when the current note picked up from a previous session's bytes.
  final bool resumed;

  bool get isRunning =>
      phase != SyncPhase.idle &&
      phase != SyncPhase.done &&
      phase != SyncPhase.failed;

  /// Fraction for the note in flight.
  double get noteFraction =>
      bytesExpected <= 0 ? 0 : (bytesReceived / bytesExpected).clamp(0.0, 1.0);

  /// Fraction across the whole run, counting the note in flight as partial.
  double get overallFraction {
    if (notesTotal <= 0) return phase == SyncPhase.done ? 1 : 0;
    return ((notesDone + noteFraction) / notesTotal).clamp(0.0, 1.0);
  }

  static const SyncProgress idle = SyncProgress(phase: SyncPhase.idle);
}

class SyncResult {
  const SyncResult({
    required this.notesAdded,
    required this.notesRemaining,
    this.error,
  });

  final int notesAdded;

  /// Still pending on the device — either the link dropped or a note failed
  /// verification. Their bytes are on disk; the next run continues them.
  final int notesRemaining;

  final String? error;

  bool get ok => error == null;
}

/// A failed operation, already phrased for a human.
///
/// The engine's exceptions come from flutter_blue_plus and read like stack
/// traces; the controller is not allowed to import that layer to unwrap them, so
/// the engine translates on the way out and everything above sees this.
class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Asks the user for the six digits on the e-paper. Returns null if they cancel —
/// the engine then gives up rather than guessing, because three wrong codes cost
/// a 30-second advertising blackout.
typedef PairCodeRequest = Future<String?> Function();

abstract class SyncService {
  Stream<SyncProgress> get progress;

  SyncProgress get current;

  bool get isRunning;

  /// Run one full sync against the device with this remote id.
  ///
  /// Implementations must be safe to call whenever a Jota is seen, and must
  /// no-op if a run is already in flight — that is what makes it safe to wire to
  /// both a button and a background scan callback.
  Future<SyncResult> run(
    String remoteId, {
    required PairCodeRequest onPairCodeNeeded,
    bool autoConnect,
  });

  /// Read the device's tag list.
  ///
  /// Takes [onPairCodeNeeded] for the same reason `run` does: `tags` sits behind
  /// the same auth gate as everything else, so a tag operation on a link that
  /// has not authenticated is discarded by the device.
  Future<List<String>> readTags(
    String remoteId, {
    required PairCodeRequest onPairCodeNeeded,
  });

  /// Replace the device's whole tag list.
  Future<void> writeTags(
    String remoteId,
    List<String> tags, {
    required PairCodeRequest onPairCodeNeeded,
  });

  Future<void> dispose();
}
