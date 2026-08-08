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
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/app.dart';
import 'package:jota/design/format.dart';
import 'package:jota/design/widgets.dart';
import 'package:jota/preview/preview_services.dart';
import 'package:jota/screens/note_detail_screen.dart';
import 'package:jota/screens/sync_screen.dart';
import 'package:jota/state/services.dart';

/// Boots the preview graph and guarantees its timers are cancelled, so a test
/// never ends with the fake scanner still ticking.
Future<Services> bootPreview(WidgetTester tester) async {
  final Services services = await PreviewServices.boot();
  addTearDown(() async {
    await services.scanner.dispose();
    await services.sync.dispose();
    await services.transcription.dispose();
    await services.background.dispose();
  });
  return services;
}

/// One frame, then enough time for the initial async refresh and the fake's
/// first advertisement.
Future<void> pumpAwake(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
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

    // The status label, and the archive count in its right slot.
    expect(find.text('NOTES'), findsOneWidget);
    expect(find.text(fmtCount(8)), findsWidgets);

    // Ids are monospaced and zero-padded everywhere in the product.
    expect(find.text('N-012'), findsOneWidget);
    expect(find.text('N-011'), findsOneWidget);

    // A transcript, rendered as prose.
    expect(
      find.textContaining('call the dentist about moving the appointment'),
      findsOneWidget,
    );

    // A note still waiting for text. (The seed's failed note and its oldest
    // notes are below the fold at the 800x600 test surface; the count above
    // proves all eight loaded.)
    expect(find.text('No transcript'), findsWidgets);

    // Tags in use drive the filter strip.
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('WORK'), findsWidgets);

    await quiesce(tester, services);
  });

  testWidgets('tapping a note opens the detail screen', (
    WidgetTester tester,
  ) async {
    final Services services = await bootPreview(tester);
    await tester.pumpWidget(JotaApp(services: services));
    await pumpAwake(tester);

    await tester.tap(find.text('N-012'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NoteDetailScreen), findsOneWidget);

    // The right slot holds this note's position in the list — the same
    // `004/012` shape the device's own NOTE VIEW screen uses.
    expect(find.text(fmtRatio(1, 8)), findsOneWidget);

    // Duration is a figure: mono, zero-padded, on the meta line.
    expect(find.text(fmtDuration(47)), findsWidgets);

    // The transcript is here as prose, and the technical facts as mono rows.
    expect(find.text('CRC'), findsOneWidget);
    expect(find.text('SIZE'), findsOneWidget);

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

  testWidgets('sync screen reads the pending count from the advertisement', (
    WidgetTester tester,
  ) async {
    final Services services = await bootPreview(tester);
    await tester.pumpWidget(JotaApp(services: services));
    await pumpAwake(tester);

    await tester.tap(find.widgetWithText(JotaButton, 'SYNC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SyncScreen), findsOneWidget);

    // Nothing paired yet, so the screen offers what is in range.
    expect(find.text('IN RANGE'), findsWidgets);

    // The fake advertises after a beat, the way a real one does.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(find.text('JOTA'), findsWidgets);
    // Three notes waiting — learned WITHOUT connecting, which is the entire
    // point of putting the count in the manufacturer data.
    expect(find.text(fmtCount(3)), findsWidgets);

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
