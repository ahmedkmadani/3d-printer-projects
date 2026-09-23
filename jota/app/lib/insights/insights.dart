// ============================================================================
//  Jota — what keeps coming back
//
//  problem.md calls this out as the half every voice recorder ignores: the
//  same worry surfacing across four sessions in a month is a FINDING, and four
//  separate entries that each mention it are not. Capture was never the hard
//  part.
//
//  This is the plain, local, working version of that. It reads the transcripts
//  already on the phone and counts which words keep returning across DIFFERENT
//  notes. No model, no network, nothing leaves.
//
//  Gemma will do this better — it can see that "my brother" and "family" are
//  the same thread, which counting words never will. The point of shipping the
//  simple one first is that the screen, the shape of the data and the tests
//  all exist before the model arrives, so swapping the engine underneath is a
//  small change instead of a new feature.
// ============================================================================
import '../data/note.dart';

/// A word or phrase that keeps returning, and where it returned.
class Topic {
  const Topic({
    required this.label,
    required this.noteCount,
    required this.weeklyCounts,
  });

  /// Shown as-is. Already capitalised for reading.
  final String label;

  /// How many DISTINCT notes mention it. Not how many times it was said —
  /// saying one word ten times in a single rant is emphasis, not a pattern.
  final int noteCount;

  /// Oldest week first. Length is the window the summary was built over, so
  /// the bars line up across topics even when a topic is missing from a week.
  final List<int> weeklyCounts;
}

/// Everything the Home screen shows about a stretch of time.
class WeekSummary {
  const WeekSummary({
    required this.noteCount,
    required this.totalSeconds,
    required this.topics,
    required this.latest,
  });

  final int noteCount;
  final int totalSeconds;

  /// Most-returning first.
  final List<Topic> topics;

  /// The most recent note in the window, or null when there is none.
  final Note? latest;

  int get totalMinutes => (totalSeconds / 60).round();

  /// The spoken figure and the unit it is in.
  ///
  /// Minutes alone cannot report this. Three notes of 8, 5 and 12 seconds are
  /// 25 seconds, which rounds to ZERO minutes — so a week with real notes in it
  /// read as "0 MINUTES" and looked like nothing had been captured at all. The
  /// figure was arithmetically right and completely useless, which is worse
  /// than wrong: it is wrong in a way that looks deliberate.
  ///
  /// Under a minute, say seconds. That is also the honest unit for this
  /// product — most thoughts worth catching take a few seconds to say.
  String get spokenValue =>
      totalSeconds < 60 ? '$totalSeconds' : '$totalMinutes';

  String get spokenUnit => totalSeconds < 60 ? 'SECONDS' : 'MINUTES';
  bool get isEmpty => noteCount == 0;
}

/// Words too common to be a topic. Counting them would surface "the" and
/// "and" as your recurring concerns, which is worse than showing nothing.
///
/// Arabic is listed alongside English because half the notes are Arabic and a
/// stoplist that only knows English would rank Arabic function words as
/// findings — the most confident kind of wrong.
const Set<String> _stopwords = <String>{
  // English
  'the', 'and', 'but', 'for', 'not', 'with', 'that', 'this', 'they', 'them',
  'have', 'has', 'had', 'was', 'were', 'been', 'being', 'are', 'you', 'your',
  'yours', 'she', 'her', 'his', 'him', 'its', 'our', 'ours', 'their', 'from',
  'about', 'into', 'over', 'then', 'than', 'when', 'what', 'which', 'who',
  'will', 'would', 'could', 'should', 'can', 'just', 'like', 'know', 'think',
  'really', 'thing', 'things', 'something', 'anything', 'nothing', 'because',
  'again', 'still', 'very', 'much', 'more', 'most', 'some', 'any', 'all',
  'one', 'two', 'get', 'got', 'going', 'went', 'want', 'wanted', 'said',
  'say', 'saying', 'today', 'yesterday', 'tomorrow', 'now', 'here', 'there',
  'out', 'off', 'back', 'down', 'why', 'how', 'did', 'does', 'doing', 'done',
  'and,', 'okay', 'yeah', 'well', 'also', 'even', 'only', 'ever', 'never',
  // Arabic — pronouns, particles, and the handful of verbs that carry no topic
  'في', 'من', 'على', 'الى', 'إلى', 'عن', 'مع', 'هذا', 'هذه', 'ذلك', 'التي',
  'الذي', 'كان', 'كانت', 'يكون', 'اللي', 'انا', 'أنا', 'انت', 'أنت', 'هو',
  'هي', 'نحن', 'هم', 'كل', 'بعد', 'قبل', 'عند', 'لكن', 'او', 'أو', 'ما',
  'لا', 'نعم', 'يعني', 'شي', 'شيء', 'كدا', 'كده', 'برضو', 'زي', 'كمان',
  'تاني', 'بس', 'عشان', 'علشان', 'لما', 'دي', 'ده', 'قال', 'قلت', 'فيه',
};

/// Split on anything that is not a letter, in either script.
final RegExp _wordBreak = RegExp(r'[^\p{L}]+', unicode: true);

/// Words shorter than this are almost always function words in both scripts.
const int _minWordLength = 4;

/// A topic has to appear in at least this many separate notes.
///
/// Three, not two: two notes mentioning the same word inside one week is a
/// coincidence often enough that surfacing it as a "pattern" would make the
/// screen untrustworthy, and a screen you do not trust is one you stop
/// reading.
const int _minNotes = 3;

/// Build the summary for the [weeks] most recent weeks, ending at [now].
WeekSummary summarise(
  List<Note> notes, {
  required DateTime now,
  int weeks = 4,
  int maxTopics = 4,
}) {
  final DateTime cutoff = now.subtract(Duration(days: 7 * weeks));
  final List<Note> window = notes
      .where((Note n) => n.recordedAt.isAfter(cutoff))
      .toList()
    ..sort((Note a, Note b) => b.recordedAt.compareTo(a.recordedAt));

  // "This week" is the headline figure; the topics look further back, because
  // a pattern that only ever appears inside one week is not yet a pattern.
  final DateTime weekStart = now.subtract(const Duration(days: 7));
  final List<Note> thisWeek =
      window.where((Note n) => n.recordedAt.isAfter(weekStart)).toList();

  final Map<String, Set<int>> notesByWord = <String, Set<int>>{};
  final Map<String, List<int>> weeklyByWord = <String, List<int>>{};
  final Map<String, String> displayByWord = <String, String>{};

  for (final Note n in window) {
    if (!n.hasTranscript) continue;
    final int bucket = _weekIndex(n.recordedAt, now, weeks);
    if (bucket < 0) continue;

    // A word counts ONCE per note however often it was said, so one long rant
    // cannot manufacture a pattern on its own.
    final Set<String> seen = <String>{};
    for (final String raw in n.transcript!.split(_wordBreak)) {
      if (raw.length < _minWordLength) continue;
      final String key = raw.toLowerCase();
      if (_stopwords.contains(key)) continue;
      if (!seen.add(key)) continue;

      notesByWord.putIfAbsent(key, () => <int>{}).add(n.noteId);
      displayByWord.putIfAbsent(key, () => _titleCase(raw));
      final List<int> byWeek =
          weeklyByWord.putIfAbsent(key, () => List<int>.filled(weeks, 0));
      byWeek[bucket]++;
    }
  }

  final List<Topic> topics = <Topic>[
    for (final MapEntry<String, Set<int>> e in notesByWord.entries)
      if (e.value.length >= _minNotes)
        Topic(
          label: displayByWord[e.key]!,
          noteCount: e.value.length,
          weeklyCounts: weeklyByWord[e.key]!,
        ),
  ]..sort((Topic a, Topic b) {
      final int byCount = b.noteCount.compareTo(a.noteCount);
      // Alphabetical as the tiebreak, so the list does not reshuffle itself
      // between two rebuilds that have identical data.
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });

  return WeekSummary(
    noteCount: thisWeek.length,
    totalSeconds: thisWeek.fold(0, (int sum, Note n) => sum + n.secs),
    topics: topics.take(maxTopics).toList(),
    latest: window.isEmpty ? null : window.first,
  );
}

/// Which bar a note belongs in. 0 is the oldest week in the window.
int _weekIndex(DateTime at, DateTime now, int weeks) {
  final int daysAgo = now.difference(at).inDays;
  if (daysAgo < 0 || daysAgo >= weeks * 7) return -1;
  return weeks - 1 - (daysAgo ~/ 7);
}

String _titleCase(String w) =>
    w.length < 2 ? w.toUpperCase() : w[0].toUpperCase() + w.substring(1);
