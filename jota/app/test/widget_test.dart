// ============================================================================
//  Jota — screen smoke tests
//
//  These run the REAL screens against the preview's fakes. That makes them worth
//  something beyond "it did not crash": the same graph the browser preview uses
//  is exercised on every `flutter test`, so a fake that drifts out of step with
//  an interface fails here rather than in a browser tab nobody opened.
//
//  Deliberately no pumpAndSettle: the scanner advertises on a repeating timer,
//  exactly as a real one does, so there is no quiet moment to settle to. Frames
//  are pumped by hand instead.
// ============================================================================
import 'package:flutter/widgets.dart' show ListView;
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/app.dart';
import 'package:jota/design/widgets.dart';
import 'package:jota/preview/preview_services.dart';
import 'package:jota/screens/note_detail_screen.dart';
import 'package:jota/screens/connect_screen.dart';
import 'package:jota/screens/widgets/device_card.dart';
import 'package:jota/state/services.dart';

/// Boots the preview graph and guarantees its timers are cancelled, so a test
/// never ends with the fake scanner still ticking.
Future<Services> bootPreview(WidgetTester tester) async {
  final Services services = await PreviewServices.boot();
  // These tests exercise the note list and what it leads to, not the first-run
  // flow, so skip onboarding — the app then boots straight past the splash to
  // the notes. (The browser preview leaves the flag false, so it still shows
  // onboarding on load.)
  await services.settings.setHasSeenOnboarding(true);
  addTearDown(() async {
    await services.scanner.dispose();
    await services.sync.dispose();
    await services.transcription.dispose();
    await services.background.dispose();
  });
  return services;
}

/// Boots past the splash and gives the note list enough time for its initial
/// async refresh and the fake's first advertisement. The splash holds for a
/// beat before routing, so the clock is advanced past that first.
Future<void> pumpAwake(WidgetTester tester) async {
  await tester.pump(); // splash first frame
  await tester.pump(const Duration(seconds: 1)); // hold elapses, route to notes
  await tester.pump(); // note list builds, kicks off its refresh
  await tester.pump(const Duration(milliseconds: 900)); // refresh + first ad
  await tester.pump();
}

/// Stops the advertising timer before the test ends.
///
/// The scanner ticks forever by design — a real one does too — and the test
/// binding rightly refuses to end with a timer still pending. Teardown is too
/// late, so every widget test parks the scanner itself.
Future<void> quiesce(WidgetTester tester, Services services) async {
  await services.scanner.stop();
  await tester.pump();
}

void main() {
  testWidgets('note list renders the seeded archive', (
    WidgetTester tester,
  ) async {
    final Services services = await bootPreview(tester);
    await tester.pumpWidget(JotaApp(services: services));
    await pumpAwake(tester);

    // Home is the landing tab now, so the archive is one tap away. The nav
    // labels only the ACTIVE pill, so 'Notes' is not on screen until then.
    await tester.tap(find.bySemanticsLabel('Notes'));
    await tester.pumpAndSettle();

    // The status label — Title case now, not all-caps. (Also appears on the
    // active nav pill, so there's more than one.)
    expect(find.text('Notes'), findsWidgets);

    // The row leads with WHEN, not with an id: you reach for a note by the
    // afternoon it came from, never by its number. The id and duration still
    // exist on the note itself.
    // The seed is relative to today, so the month is whatever month it is:
    // matching ' AUG · ' made this test expire on 1 September.
    // Rows carry the time; the day is said once, in a heading above them.
    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsWidgets);
    expect(
      find.textContaining(RegExp(r'^[A-Z]{3} \d{1,2} [A-Z]{3} · \d{2}:\d{2}')),
      findsNothing,
    );
    expect(find.byType(JotaTagPill), findsWidgets);

    // A transcript, rendered as prose in the row preview.
    expect(
      find.textContaining('call the dentist about moving the appointment'),
      findsOneWidget,
    );

    // No filter strip and no configuration banner: the list is the screen.
    expect(find.text('All'), findsNothing);
    // Tags still ride on the rows themselves, as pills.
    expect(find.text('WORK'), findsWidgets);

    await quiesce(tester, services);
  });

  testWidgets('tapping a note opens the detail screen', (
    WidgetTester tester,
  ) async {
    final Services services = await bootPreview(tester);
    await tester.pumpWidget(JotaApp(services: services));
    await pumpAwake(tester);

    // Open it the way a person does now: from the archive, by the words on
    // the row. Home's latest card no longer prints the id — it leads with the
    // stamp and the note's own words, so there is no `N-012` to tap there.
    await tester.tap(find.bySemanticsLabel('Notes'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining('call the dentist about moving the appointment'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NoteDetailScreen), findsOneWidget);

    // The detail leads with the transcript as prose; the note's date is its
    // title, so there is no list-position figure in the header any more. (The
    // list is still mounted under the pushed route, so the text is found twice.)
    expect(
      find.textContaining('call the dentist about moving the appointment'),
      findsWidgets,
    );
    // The player pill's ratio is unique to the detail screen (the list has no
    // durations), so finding it proves we are actually on it.
    expect(find.textContaining('00:00 / '), findsOneWidget);
    // A transcribed note offers the hold-to-edit affordance and, pinned at
    // the foot, Share beside the tag button. No Delete on this screen: that
    // is the swipe on the list, and one route is enough.
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(
      find.textContaining(RegExp('tag', caseSensitive: false)),
      findsWidgets,
    );
    // One quiet Delete note link, under the details card — below the fold
    // in this viewport, so scroll the note's own list until it builds.
    await tester.dragUntilVisible(
      find.text('Delete note'),
      find.byType(ListView).last,
      const Offset(0, -120),
    );
    expect(find.text('Delete note'), findsOneWidget);

    await quiesce(tester, services);
  });

  testWidgets('the preview build is labelled and carries the pair code', (
    WidgetTester tester,
  ) async {
    final Services services = await bootPreview(tester);
    expect(services.isPreview, isTrue);

    await tester.pumpWidget(JotaApp(services: services));
    await pumpAwake(tester);

    expect(find.text('PREVIEW · FAKE DATA · NO BLUETOOTH'), findsOneWidget);
    // The code has to be somewhere: there is no e-paper in a browser tab.
    expect(find.text('PAIR CODE 428 913'), findsOneWidget);

    await quiesce(tester, services);
  });

  testWidgets('the device card opens Connect and finds a Jota', (
    WidgetTester tester,
  ) async {
    final Services services = await bootPreview(tester);
    await tester.pumpWidget(JotaApp(services: services));
    await pumpAwake(tester);

    // Sync is not a place you go (product.md), so there is no sync screen to
    // reach any more. With nothing paired the card has something to go TO —
    // pairing — so it opens Connect. Once a device IS paired the same tap
    // simply syncs, in place.
    await tester.tap(find.byType(DeviceCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ConnectScreen), findsOneWidget);

    // Nothing paired yet, so the screen leads with the connect flow.
    expect(find.text('Connect your Jota'), findsOneWidget);

    // The fake advertises after a beat, the way a real one does; the device
    // then appears in range as a tappable row named by its ID — discovered
    // WITHOUT connecting, which is the point of the advertisement. The bare
    // local name would be "JOTA" for every device ever made.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(find.text('JOTA-91C4'), findsWidgets);

    await quiesce(tester, services);
  });

  testWidgets('seeded audio decodes through the real ADPCM path', (
    WidgetTester tester,
  ) async {
    final Services services = await bootPreview(tester);

    // The preview stores synthetic ADPCM of a realistic length and decodes it
    // with the shipping decoder and WAV writer. Nonsense samples, real code
    // path — so a regression in either still fails here.
    final wav = await services.audio.wavBytes('JOTA-PREVIEW-01', 12);
    expect(wav, isNotNull);
    expect(wav!.length, greaterThan(44));
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  });
}
