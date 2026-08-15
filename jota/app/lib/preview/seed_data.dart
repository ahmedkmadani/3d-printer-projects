// ============================================================================
//  Jota — seed data for the web preview
//
//  Eight notes chosen to put every state the list and detail screens can be in on
//  screen at once: transcribed and long, transcribed and short, still queued,
//  finished with no speech in it, failed for want of an API key, tagged and
//  untagged, today and last week.
//
//  The audio is synthetic — deterministic pseudo-random bytes of the right
//  LENGTH, so byte counts, durations and CRCs are all self-consistent and the
//  real decoder runs over them. It is not speech and it does not sound like
//  anything; see the README.
// ============================================================================
import 'dart:typed_data';

import '../audio/adpcm.dart';
import '../audio/crc32.dart';
import '../data/note.dart';
import 'in_memory_stores.dart';

/// The simulated device's id, used everywhere a remote id is needed.
const String kPreviewDeviceId = 'JOTA-PREVIEW-01';

/// The fake device's own id, in the same form the firmware derives from its
/// efuse MAC. The last four characters are what a person sees: JOTA-91C4.
const String kPreviewDeviceIdHex = '7f3a91c4';

/// What the fake device "shows on its e-paper" during pairing.
const String kPreviewPairCode = '428913';

/// ADPCM is 8 KB/s at 16 kHz (4 bits per sample). The device's own arithmetic.
const int kBytesPerSecond = Adpcm.sampleRate ~/ 2;

/// Deterministic filler of exactly the length a note of [secs] would be, rounded
/// to whole 256-byte ADPCM blocks like the real thing.
Uint8List syntheticAdpcm(int secs, {int seed = 1}) {
  final int length = Adpcm.floorToBlock(secs * kBytesPerSecond);
  final Uint8List out = Uint8List(length);
  // A tiny LCG: same numbers every run, so a CRC computed here is stable.
  int x = seed * 2654435761 & 0xFFFFFFFF;
  for (int i = 0; i < length; i++) {
    x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
    out[i] = (x >> 16) & 0xFF;
  }
  return out;
}

class _Seed {
  const _Seed({
    required this.id,
    required this.minutesAgo,
    required this.secs,
    this.tag,
    this.transcript,
    this.state = TranscriptState.done,
    this.error,
  });

  final int id;
  final int minutesAgo;
  final int secs;
  final String? tag;
  final String? transcript;
  final TranscriptState state;
  final String? error;
}

// Timestamps are relative so the list always reads as "today / yesterday /
// a date", whenever the preview is opened.
const List<_Seed> _seeds = <_Seed>[
  _Seed(
    id: 12,
    minutesAgo: 42,
    secs: 47,
    tag: 'WORK',
    // The same sentence the device's own NOTE VIEW render shows, so the preview
    // and the e-paper mock-up can be held side by side.
    transcript: 'call the dentist about moving the appointment to next week '
        'and ask whether the referral is still valid',
  ),
  _Seed(
    id: 11,
    minutesAgo: 200,
    secs: 12,
    tag: 'BUY',
    transcript: 'milk, oat milk, the good coffee from the place on the corner, '
        'and something for Sara on Friday',
  ),
  _Seed(
    id: 10,
    minutesAgo: 320,
    secs: 8,
    state: TranscriptState.pending,
  ),
  _Seed(
    id: 9,
    minutesAgo: 1140,
    secs: 132,
    tag: 'IDEA',
    transcript: 'the enclosure should be one part, not three — if the lid '
        'carries the battery and the base carries the board then the only '
        'fastener is the lid itself, and the plunger can key into the same '
        'boss the hinge uses. worth a print tonight to see whether the walls '
        'are stiff enough at one point six.',
  ),
  _Seed(
    id: 8,
    minutesAgo: 1400,
    secs: 23,
    tag: 'WORK',
    transcript: 'tell Marc the sync protocol resumes by byte offset now, so he '
        'can stop worrying about the lift losing the connection',
  ),
  _Seed(
    id: 7,
    minutesAgo: 1660,
    secs: 5,
    // Whisper returns an empty string for silence. Recorded as done-with-no-text
    // rather than failed, so it does not sit in the retry queue forever.
    transcript: '',
  ),
  _Seed(
    id: 6,
    minutesAgo: 4300,
    secs: 64,
    tag: 'LATER',
    state: TranscriptState.failed,
    error: 'Add an API key in Settings to transcribe notes.',
  ),
  _Seed(
    id: 5,
    minutesAgo: 5800,
    secs: 91,
    tag: 'IDEA',
    transcript: 'a status line, a hairline, and one idea per screen. that is '
        'the whole rule — if a screen needs a second figure it is two screens.',
  ),
];

/// Build the seed notes and load their audio into [audio].
List<Note> seedNotes(InMemoryAudioStore audio, {DateTime? now}) {
  final DateTime base = now ?? DateTime.now();
  final List<Note> notes = <Note>[];

  for (final _Seed s in _seeds) {
    final Uint8List adpcm = syntheticAdpcm(s.secs, seed: s.id);
    audio.put(kPreviewDeviceId, s.id, adpcm);

    final DateTime recorded = base.subtract(Duration(minutes: s.minutesAgo));

    notes.add(
      Note(
        deviceId: kPreviewDeviceId,
        noteId: s.id,
        recordedAt: recorded,
        secs: s.secs,
        bytes: adpcm.length,
        crc: Crc32.toHex(Crc32.compute(adpcm)),
        adpcmPath: audio.archivePathFor(kPreviewDeviceId, s.id),
        tag: s.tag,
        transcript: s.transcript,
        transcriptState: s.state,
        transcriptError: s.error,
        transcriptModel: s.state == TranscriptState.done && s.transcript != null
            ? 'whisper-1'
            : null,
        syncedAt: recorded.add(const Duration(minutes: 3)),
      ),
    );
  }

  return notes;
}

/// The notes still sitting on the simulated device, waiting to be pulled. Three
/// of them, so the SYNC screen's `001/003` ratio and its progress bar both have
/// something real to show.
class PendingNote {
  const PendingNote({
    required this.id,
    required this.secs,
    required this.minutesAgo,
    this.transcript,
    this.tag,
  });

  final int id;
  final int secs;
  final int minutesAgo;

  /// The tag armed on the device when it was recorded. Null for a note taken
  /// with nothing armed — which is the common case, and has to look right too.
  final String? tag;

  /// What the simulated Whisper will "hear" once this note is pulled.
  final String? transcript;
}

const List<PendingNote> kPendingOnDevice = <PendingNote>[
  PendingNote(
    id: 13,
    secs: 8,
    minutesAgo: 26,
    transcript: 'check whether the lid still closes with the thicker gasket',
    tag: 'WORK',
  ),
  PendingNote(
    id: 14,
    secs: 5,
    minutesAgo: 18,
    transcript: 'book the ferry before Thursday',
    tag: 'PERSONAL',
  ),
  PendingNote(
    id: 15,
    secs: 12,
    minutesAgo: 4,
    transcript: 'the ring should not move between idle and recording — only '
        'the annulus thickens inward',
  ),
];
