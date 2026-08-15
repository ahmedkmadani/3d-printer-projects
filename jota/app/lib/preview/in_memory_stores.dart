// ============================================================================
//  Jota — in-memory stores for the web preview
//
//  Straight implementations of the lib/data/ interfaces over Dart maps. No
//  sqflite, no dart:io, no Keychain — which is exactly what makes the preview run
//  in a browser, where every one of those is a MissingPluginException.
//
//  State lives for as long as the tab does. Reloading the page resets everything
//  to the seed, which for a look-and-feel preview is a feature.
// ============================================================================
import 'dart:typed_data';

import '../audio/adpcm.dart';
import '../audio/crc32.dart';
import '../audio/wav.dart';
import '../data/audio_store.dart';
import '../data/note.dart';
import '../data/note_repository.dart';
import '../data/partial_store.dart';
import '../data/settings_store.dart';

String _key(String deviceId, int noteId) => '$deviceId/$noteId';

// ---- notes -----------------------------------------------------------------

class InMemoryNoteRepository implements NoteRepository {
  InMemoryNoteRepository(this._audio, {List<Note> seed = const <Note>[]}) {
    for (final Note n in seed) {
      _rows[_key(n.deviceId, n.noteId)] = n.copyWith(rowId: _nextRowId++);
    }
  }

  final AudioStore _audio;
  final Map<String, Note> _rows = <String, Note>{};
  final Map<String, int> _attempts = <String, int>{};
  final Set<String> _partials = <String>{};
  int _nextRowId = 1;

  List<Note> get _sorted {
    final List<Note> all = _rows.values.toList();
    all.sort((Note a, Note b) {
      final int byTime = b.recordedAt.compareTo(a.recordedAt);
      return byTime != 0 ? byTime : b.noteId.compareTo(a.noteId);
    });
    return all;
  }

  @override
  Future<List<Note>> all() async => _sorted;

  @override
  Future<List<Note>> withTag(String tag) async =>
      _sorted.where((Note n) => n.tag == tag).toList();

  @override
  Future<Note?> byId(String deviceId, int noteId) async =>
      _rows[_key(deviceId, noteId)];

  @override
  Future<Set<int>> knownIds(String deviceId) async => _rows.values
      .where((Note n) => n.deviceId == deviceId)
      .map((Note n) => n.noteId)
      .toSet();

  @override
  Future<List<Note>> awaitingTranscription({int limit = 20}) async {
    final List<Note> queue = _rows.values
        .where(
          (Note n) =>
              n.transcriptState == TranscriptState.pending ||
              n.transcriptState == TranscriptState.failed,
        )
        .toList()
      ..sort((Note a, Note b) => a.recordedAt.compareTo(b.recordedAt));
    return queue.take(limit).toList();
  }

  @override
  Future<int> count() async => _rows.length;

  @override
  Future<List<String>> tagsInUse() async {
    final Set<String> tags = _rows.values
        .map((Note n) => n.tag ?? '')
        .where((String t) => t.isNotEmpty)
        .toSet();
    final List<String> sorted = tags.toList()..sort();
    return sorted;
  }

  @override
  Future<Note> insert(Note note) async {
    final String k = _key(note.deviceId, note.noteId);
    // Idempotent, and must not clobber an existing transcript — same contract as
    // the sqflite implementation's ConflictAlgorithm.ignore.
    final Note? existing = _rows[k];
    if (existing != null) return existing;
    final Note stored = note.copyWith(rowId: _nextRowId++);
    _rows[k] = stored;
    return stored;
  }

  @override
  Future<void> update(Note note) async {
    _rows[_key(note.deviceId, note.noteId)] = note;
  }

  @override
  Future<void> setTag(Note note, String? tag) =>
      update(note.copyWith(tag: tag, clearTag: tag == null));

  @override
  Future<void> setTranscriptState(
    Note note,
    TranscriptState state, {
    String? error,
  }) {
    return update(
      note.copyWith(
        transcriptState: state,
        transcriptError: error,
        clearTranscriptError: error == null,
      ),
    );
  }

  @override
  Future<void> setTranscript(
    Note note,
    String text, {
    String? model,
    bool manual = false,
  }) {
    return update(
      note.copyWith(
        transcript: text,
        transcriptState: manual ? TranscriptState.manual : TranscriptState.done,
        transcriptModel: model,
        clearTranscriptError: true,
      ),
    );
  }

  @override
  Future<void> delete(Note note) async {
    _rows.remove(_key(note.deviceId, note.noteId));
    await _audio.deleteNote(note.deviceId, note.noteId);
  }

  @override
  Future<void> rememberPartial({
    required String deviceId,
    required int noteId,
    required int expectedBytes,
    required String crc,
    required int secs,
    required int recordedAt,
  }) async {
    _partials.add(_key(deviceId, noteId));
  }

  @override
  Future<int> bumpPartialAttempts(String deviceId, int noteId) async {
    final String k = _key(deviceId, noteId);
    return _attempts[k] = (_attempts[k] ?? 0) + 1;
  }

  @override
  Future<void> forgetPartial(String deviceId, int noteId) async {
    _partials.remove(_key(deviceId, noteId));
  }

  @override
  Future<List<int>> unfinishedNoteIds(String deviceId) async => _partials
      .where((String k) => k.startsWith('$deviceId/'))
      .map((String k) => int.tryParse(k.split('/').last) ?? 0)
      .toList();

  @override
  Future<void> close() async {}
}

// ---- audio -----------------------------------------------------------------

class InMemoryAudioStore implements AudioStore {
  InMemoryAudioStore();

  final Map<String, Uint8List> _archive = <String, Uint8List>{};
  final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Seed a note's ADPCM. Used by the seed data and by the simulated sync.
  void put(String deviceId, int noteId, Uint8List adpcm) {
    _archive[_key(deviceId, noteId)] = adpcm;
  }

  @override
  String archivePathFor(String deviceId, int noteId) =>
      'memory://archive/${_key(deviceId, noteId)}.adpcm';

  @override
  Future<String?> ensureWavPath(String deviceId, int noteId) async {
    // There is no filesystem, so there is no path a player could open. The
    // preview's NotePlayer never calls this; returning a pseudo-path keeps the
    // "missing audio" branch of the UI reachable for notes with no archive.
    final Uint8List? wav = await wavBytes(deviceId, noteId);
    if (wav == null) return null;
    return 'memory://wav/${_key(deviceId, noteId)}.wav';
  }

  @override
  Future<Uint8List?> wavBytes(String deviceId, int noteId) async {
    final String k = _key(deviceId, noteId);
    final Uint8List? cached = _cache[k];
    if (cached != null) return cached;

    final Uint8List? adpcm = _archive[k];
    if (adpcm == null) return null;

    // The REAL decoder and the REAL WAV writer, both pure Dart and both perfectly
    // happy in a browser. So the preview does exercise this path — the samples are
    // nonsense, but a bug that threw here would still be caught.
    final Uint8List wav = Wav.encodePcm16(
      Adpcm.decode(adpcm),
      sampleRate: Adpcm.sampleRate,
      channels: Adpcm.channels,
    );
    return _cache[k] = wav;
  }

  @override
  Future<bool> hasArchive(String deviceId, int noteId) async =>
      _archive.containsKey(_key(deviceId, noteId));

  @override
  Future<void> deleteNote(String deviceId, int noteId) async {
    final String k = _key(deviceId, noteId);
    _archive.remove(k);
    _cache.remove(k);
  }

  @override
  Future<int> clearCache() async {
    final int freed = await cacheBytes();
    _cache.clear();
    return freed;
  }

  @override
  Future<int> archiveBytes() async => _archive.values.fold<int>(
        0,
        (int sum, Uint8List b) => sum + b.length,
      );

  @override
  Future<int> cacheBytes() async => _cache.values.fold<int>(
        0,
        (int sum, Uint8List b) => sum + b.length,
      );
}

// ---- partials --------------------------------------------------------------

class InMemoryPartialStore implements PartialStore {
  final Map<String, List<int>> _bytes = <String, List<int>>{};

  @override
  Future<int> receivedBytes(String deviceId, int noteId) async =>
      _bytes[_key(deviceId, noteId)]?.length ?? 0;

  @override
  Future<int> resumeOffset(String deviceId, int noteId) async {
    final int held = await receivedBytes(deviceId, noteId);
    final int aligned = Adpcm.floorToBlock(held);
    if (aligned != held) await truncate(deviceId, noteId, aligned);
    return aligned;
  }

  @override
  Future<void> append(String deviceId, int noteId, List<int> chunk) async {
    (_bytes[_key(deviceId, noteId)] ??= <int>[]).addAll(chunk);
  }

  @override
  Future<void> truncate(String deviceId, int noteId, int length) async {
    final List<int>? held = _bytes[_key(deviceId, noteId)];
    if (held == null || held.length <= length) return;
    _bytes[_key(deviceId, noteId)] = held.sublist(0, length);
  }

  @override
  Future<int> crc32Of(String deviceId, int noteId) async =>
      Crc32.compute(_bytes[_key(deviceId, noteId)] ?? const <int>[]);

  @override
  Future<Uint8List> readAll(String deviceId, int noteId) async =>
      Uint8List.fromList(_bytes[_key(deviceId, noteId)] ?? const <int>[]);

  @override
  Future<void> promote(String deviceId, int noteId, String destPath) async {
    _bytes.remove(_key(deviceId, noteId));
  }

  @override
  Future<void> discard(String deviceId, int noteId) async {
    _bytes.remove(_key(deviceId, noteId));
  }

  @override
  Future<void> retainOnly(String deviceId, Set<int> liveNoteIds) async {
    _bytes.removeWhere((String k, _) {
      if (!k.startsWith('$deviceId/')) return false;
      final int id = int.tryParse(k.split('/').last) ?? -1;
      return !liveNoteIds.contains(id);
    });
  }

  @override
  Future<int> totalBytes() async =>
      _bytes.values.fold<int>(0, (int sum, List<int> b) => sum + b.length);
}

// ---- settings --------------------------------------------------------------

class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore({
    String? apiKey,
    String? deviceId,
    String? deviceName,
    bool backgroundSync = false,
    bool autoTranscribe = true,
    bool hasSeenOnboarding = false,
    List<String> tags = const <String>[],
    bool appLockEnabled = false,
  })  : _apiKey = apiKey,
        _deviceId = deviceId,
        _deviceName = deviceName,
        _backgroundSync = backgroundSync,
        _autoTranscribe = autoTranscribe,
        _hasSeenOnboarding = hasSeenOnboarding,
        _tags = tags,
        _appLockEnabled = appLockEnabled;

  String? _apiKey;
  String? _deviceId;
  String? _deviceName;
  bool _backgroundSync;
  bool _autoTranscribe;
  bool _hasSeenOnboarding;
  List<String> _tags;
  bool _appLockEnabled;
  String _model = 'latest_long';
  String? _language;
  String _backend = 'google';

  @override
  Future<String?> apiKey() async => _apiKey;

  @override
  Future<void> setApiKey(String? key) async {
    final String? k = key?.trim();
    _apiKey = (k == null || k.isEmpty) ? null : k;
  }

  @override
  Future<bool> hasApiKey() async => (_apiKey ?? '').isNotEmpty;

  @override
  String? get deviceId => _deviceId;

  @override
  String? get deviceName => _deviceName;

  @override
  Future<void> setDevice(String? id, {String? name}) async {
    _deviceId = id;
    _deviceName = id == null ? null : (name ?? _deviceName);
  }

  @override
  bool get hasDevice => (_deviceId ?? '').isNotEmpty;

  @override
  final String appId = newAppId();

  @override
  List<String> get tags => _tags;

  @override
  Future<void> setTags(List<String> v) async => _tags = v;

  @override
  bool get appLockEnabled => _appLockEnabled;

  @override
  Future<void> setAppLockEnabled(bool v) async => _appLockEnabled = v;

  @override
  bool get backgroundSync => _backgroundSync;

  @override
  Future<void> setBackgroundSync(bool v) async => _backgroundSync = v;

  @override
  bool get autoTranscribe => _autoTranscribe;

  @override
  Future<void> setAutoTranscribe(bool v) async => _autoTranscribe = v;

  @override
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  @override
  Future<void> setHasSeenOnboarding(bool v) async => _hasSeenOnboarding = v;

  @override
  String get model => _model;

  @override
  Future<void> setModel(String v) async => _model = v;

  @override
  String? get language => _language;

  @override
  Future<void> setLanguage(String? v) async =>
      _language = (v == null || v.isEmpty) ? null : v;

  @override
  String get backend => _backend;

  @override
  Future<void> setBackend(String v) async => _backend = v;
}
