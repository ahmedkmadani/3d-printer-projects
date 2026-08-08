// ============================================================================
//  Jota — notes controller
//
//  The note list and everything that mutates it. Thin: the repository does the
//  work, this holds the in-memory copy the widgets rebuild from.
// ============================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/note.dart';
import '../data/note_repository.dart';
import '../transcribe/transcription_queue.dart';

class NotesController extends ChangeNotifier {
  NotesController({
    required NoteRepository repository,
    required TranscriptionQueue transcription,
  })  : _repo = repository,
        _transcription = transcription {
    _sub = _transcription.changes.listen((_) => refresh());
  }

  final NoteRepository _repo;
  final TranscriptionQueue _transcription;
  StreamSubscription<void>? _sub;

  List<Note> _notes = <Note>[];
  List<Note> get notes => _notes;

  /// Null means "all". Set by the filter row on the list screen.
  String? _tagFilter;
  String? get tagFilter => _tagFilter;

  bool _loading = true;
  bool get loading => _loading;

  List<String> _tagsInUse = <String>[];
  List<String> get tagsInUse => _tagsInUse;

  int get count => _notes.length;

  List<Note> get visible {
    if (_tagFilter == null) return _notes;
    return _notes.where((Note n) => n.tag == _tagFilter).toList();
  }

  Future<void> refresh() async {
    _notes = await _repo.all();
    _tagsInUse = await _repo.tagsInUse();
    _loading = false;
    notifyListeners();
  }

  void setTagFilter(String? tag) {
    _tagFilter = tag;
    notifyListeners();
  }

  /// 1-based position of a note within the current view, for the `004/012` in
  /// the detail screen's status slot.
  int positionOf(Note note) {
    final int i = visible.indexWhere(
      (Note n) => n.deviceId == note.deviceId && n.noteId == note.noteId,
    );
    return i < 0 ? 0 : i + 1;
  }

  Note? at(int index) {
    final List<Note> v = visible;
    if (index < 0 || index >= v.length) return null;
    return v[index];
  }

  Future<void> setTag(Note note, String? tag) async {
    await _repo.setTag(note, tag);
    await refresh();
  }

  Future<void> setTranscript(Note note, String text) async {
    await _repo.setTranscript(note, text, manual: true);
    await refresh();
  }

  Future<void> transcribe(Note note) async {
    await _transcription.transcribeNow(note);
    await refresh();
  }

  Future<void> drainTranscriptions() async {
    await _transcription.drain();
    await refresh();
  }

  bool isTranscribing(Note note) => _transcription.isRunningFor(note);

  /// Permanent: there is no server copy and the device dropped its own after
  /// the ack. Screens must confirm before calling this.
  Future<void> delete(Note note) async {
    await _repo.delete(note);
    await refresh();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
