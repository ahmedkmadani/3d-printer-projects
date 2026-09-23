// What keeps coming back — the local, no-model version.
//
// The rule under test (problem.md): the same worry across four sessions is a
// finding; four entries that each mention it are not.
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/data/note.dart';
import 'package:jota/insights/insights.dart';

final DateTime now = DateTime(2026, 8, 15, 9);

Note note(int id, {required int daysAgo, String? text, int secs = 60}) {
  return Note(
    deviceId: 'JOTA-TEST',
    noteId: id,
    recordedAt: now.subtract(Duration(days: daysAgo)),
    secs: secs,
    bytes: 1000,
    crc: 'aaaaaaaa',
    adpcmPath: '/tmp/$id.adpcm',
    transcript: text,
    transcriptState:
        text == null ? TranscriptState.pending : TranscriptState.done,
    syncedAt: now,
  );
}

void main() {
  test('a week of short notes does not report zero', () {
    // 8 + 5 + 12 seconds. In minutes that rounds to zero, so the Home screen
    // said "0 MINUTES" for a week that had three real notes in it — a figure
    // that is arithmetically right and reports nothing. Most thoughts worth
    // catching take seconds to say, so seconds is the honest unit down here.
    const WeekSummary w = WeekSummary(
      noteCount: 3,
      totalSeconds: 25,
      topics: <Topic>[],
      latest: null,
    );
    expect(w.spokenValue, '25');
    expect(w.spokenUnit, 'SECONDS');
  });

  test('a real week still reports minutes', () {
    const WeekSummary w = WeekSummary(
      noteCount: 4,
      totalSeconds: 305,
      topics: <Topic>[],
      latest: null,
    );
    expect(w.spokenValue, '5');
    expect(w.spokenUnit, 'MINUTES');
  });


  test('this week counts notes and minutes, not the whole window', () {
    final WeekSummary s = summarise(
      <Note>[
        note(1, daysAgo: 1, secs: 120),
        note(2, daysAgo: 3, secs: 60),
        note(3, daysAgo: 20, secs: 600), // inside the window, not this week
      ],
      now: now,
    );
    expect(s.noteCount, 2);
    expect(s.totalMinutes, 3);
    expect(s.latest?.noteId, 1);
  });

  test('a two-word phrase across three notes is one finding, not three', () {
    final WeekSummary s = summarise(
      <Note>[
        note(1, daysAgo: 1, text: 'dentist appointment moved again'),
        note(2, daysAgo: 8, text: 'call about the dentist appointment'),
        note(3, daysAgo: 16, text: 'dentist appointment on friday'),
      ],
      now: now,
    );
    final List<String> labels = s.topics.map((Topic t) => t.label).toList();
    expect(labels, contains('Dentist appointment'));
    // The phrase swallows its own words.
    expect(labels, isNot(contains('Dentist')));
    expect(labels, isNot(contains('Appointment')));
  });

  test('the patterns card waits for enough transcribed notes', () {
    final List<Note> few = <Note>[
      for (int i = 1; i <= 7; i++) note(i, daysAgo: i, text: 'words $i'),
    ];
    expect(enoughForPatterns(few), isFalse);
    final List<Note> enough = <Note>[
      ...few,
      note(8, daysAgo: 8, text: 'words 8'),
      note(9, daysAgo: 9), // no transcript: does not count
    ];
    expect(enoughForPatterns(enough), isTrue);
  });

  test('a word in three separate notes is a topic', () {
    final WeekSummary s = summarise(
      <Note>[
        note(1, daysAgo: 1, text: 'boundaries with family again'),
        note(2, daysAgo: 8, text: 'the same boundaries problem'),
        note(3, daysAgo: 16, text: 'boundaries, still'),
      ],
      now: now,
    );
    expect(s.topics.map((Topic t) => t.label), contains('Boundaries'));
  });

  test('two notes is not yet a pattern', () {
    final WeekSummary s = summarise(
      <Note>[
        note(1, daysAgo: 1, text: 'boundaries again'),
        note(2, daysAgo: 8, text: 'boundaries still'),
      ],
      now: now,
    );
    expect(s.topics, isEmpty);
  });

  test('one long rant cannot manufacture a pattern', () {
    // Said five times, in ONE note. Emphasis, not a recurring theme — the
    // whole value of the screen is that it only reports things that came back.
    final WeekSummary s = summarise(
      <Note>[
        note(
          1,
          daysAgo: 1,
          text: 'deadline deadline deadline deadline deadline and more '
              'about the deadline',
        ),
      ],
      now: now,
    );
    expect(s.topics, isEmpty);
  });

  test('common words never surface as findings', () {
    final WeekSummary s = summarise(
      <Note>[
        note(1, daysAgo: 1, text: 'really just something about things'),
        note(2, daysAgo: 8, text: 'really just something about things'),
        note(3, daysAgo: 16, text: 'really just something about things'),
      ],
      now: now,
    );
    expect(s.topics, isEmpty);
  });

  test('Arabic function words are stopped too', () {
    // A stoplist that only knew English would rank "يعني" and "اللي" as this
    // person's recurring concerns — confidently, and wrongly.
    final WeekSummary s = summarise(
      <Note>[
        note(1, daysAgo: 1, text: 'يعني اللي حصل مع العائلة'),
        note(2, daysAgo: 8, text: 'يعني اللي قلت ليهو عن العائلة'),
        note(3, daysAgo: 16, text: 'يعني اللي بفكر فيهو مع العائلة'),
      ],
      now: now,
    );
    final List<String> labels = s.topics.map((Topic t) => t.label).toList();
    expect(labels, contains('العائلة'));
    expect(labels, isNot(contains('يعني')));
    expect(labels, isNot(contains('اللي')));
  });

  test('weekly bars span the window, oldest first', () {
    final WeekSummary s = summarise(
      <Note>[
        note(1, daysAgo: 1, text: 'sleep is bad'),
        note(2, daysAgo: 2, text: 'sleep again'),
        note(3, daysAgo: 25, text: 'sleep back then'),
      ],
      now: now,
    );
    final Topic t = s.topics.firstWhere((Topic t) => t.label == 'Sleep');
    expect(t.weeklyCounts, hasLength(4));
    expect(t.weeklyCounts.first, 1, reason: 'the 25-day-old note');
    expect(t.weeklyCounts.last, 2, reason: 'the two from this week');
  });

  test('notes older than the window are ignored entirely', () {
    final WeekSummary s = summarise(
      <Note>[
        note(1, daysAgo: 40, text: 'boundaries'),
        note(2, daysAgo: 41, text: 'boundaries'),
        note(3, daysAgo: 42, text: 'boundaries'),
      ],
      now: now,
    );
    expect(s.topics, isEmpty);
    expect(s.latest, isNull);
    expect(s.isEmpty, isTrue);
  });

  test('untranscribed notes still count as time, but carry no topics', () {
    final WeekSummary s = summarise(
      <Note>[note(1, daysAgo: 1, secs: 300)],
      now: now,
    );
    expect(s.noteCount, 1);
    expect(s.totalMinutes, 5);
    expect(s.topics, isEmpty);
  });
}
