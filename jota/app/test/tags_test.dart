// ============================================================================
//  Jota — tags
//
//  Three things went wrong here at once and each gets a test:
//
//    * a Jota that already had tags on it was never read, so a fresh install
//      showed an empty list beside a device holding five
//    * a tag written from the app was pushed over a link that had never
//      authenticated, so the device dropped it — while the write still acked,
//      which made a failure look exactly like a success
//    * the add path let you add a tag that was already there
//
//  Run against the same fakes the browser preview uses, so the interface the
//  real engine implements is the one being exercised.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/ble/jota_protocol.dart';
import 'package:jota/ble/sync_service.dart';
import 'package:jota/data/note.dart';

import 'package:jota/preview/preview_services.dart';
import 'package:jota/screens/tag_editor_screen.dart';
import 'package:jota/state/device_controller.dart';
import 'package:jota/state/notes_controller.dart';
import 'package:jota/state/services.dart';
import 'package:provider/provider.dart';

/// Boots the preview graph and parks its timers on the way out.
Future<Services> bootPreview(WidgetTester? tester) async {
  final Services services = await PreviewServices.boot();
  addTearDown(() async {
    await services.scanner.stop();
    await services.scanner.dispose();
    await services.sync.dispose();
    await services.transcription.dispose();
    await services.background.dispose();
  });
  return services;
}

/// The tag editor with just enough of the app around it to run.
///
/// [localTags] is what the phone already knows — empty stands for a fresh
/// install, which is the case that has to reach for the device's list.
Future<Services> pumpTagEditor(
  WidgetTester tester, {
  List<String> localTags = const <String>[],
}) async {
  final Services services = await bootPreview(tester);
  // Set unconditionally: the preview graph seeds a few tags, and the case that
  // matters most is the one with none.
  await services.settings.setTags(localTags);

  // A paired device is the whole point: without one the editor never asks the
  // device anything.
  await services.settings.setDevice('JOTA-PREVIEW-01', name: 'JOTA');

  // And actually pair, the way a person does — present the code once so the
  // device stores this phone as its owner. Everything afterwards has to work
  // WITHOUT a prompt; the tag editor deliberately never asks for a code, so a
  // device that did not know us would just be skipped.
  //
  // Inside runAsync: the fake answers on real timers, and a testWidgets body
  // runs on a fake clock that only advances when pumped — so awaiting the
  // handshake directly here would wait forever.
  await tester.runAsync(() async {
    await services.sync.readTags(
      'JOTA-PREVIEW-01',
      onPairCodeNeeded: () async => '428913',
    );
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<Services>.value(value: services),
        ChangeNotifierProvider<NotesController>(
          create: (_) => NotesController(
            repository: services.notes,
            transcription: services.transcription,
          ),
        ),
        ChangeNotifierProvider<DeviceController>(
          create: (BuildContext context) => DeviceController(
            scanner: services.scanner,
            sync: services.sync,
            settings: services.settings,
            background: services.background,
            notes: context.read<NotesController>(),
          ),
        ),
      ],
      child: const MaterialApp(home: TagEditorScreen()),
    ),
  );
  return services;
}

/// The fake takes a beat to answer, as a radio does.
Future<void> letTheRadioAnswer(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump();
}

void main() {
  testWidgets('a device that already has tags fills an empty app list', (
    WidgetTester tester,
  ) async {
    final Services services = await pumpTagEditor(tester);
    expect(services.settings.tags, isEmpty, reason: 'fresh install');

    await letTheRadioAnswer(tester);

    // The three the fake Jota ships with, now on screen...
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('PERSONAL'), findsOneWidget);
    expect(find.text('IDEAS'), findsOneWidget);
    // ...and kept, so the next launch does not have to ask again.
    expect(services.settings.tags, contains('WORK'));
  });

  testWidgets("the phone's own list is never overwritten by the device", (
    WidgetTester tester,
  ) async {
    final Services services = await pumpTagEditor(
      tester,
      localTags: <String>['ERRANDS'],
    );
    await letTheRadioAnswer(tester);

    // App-first: the device's three do not appear over the phone's one.
    expect(find.text('ERRANDS'), findsOneWidget);
    expect(find.text('WORK'), findsNothing);
    expect(services.settings.tags, <String>['ERRANDS']);
  });

  testWidgets('adding a tag that already exists does not duplicate the row', (
    WidgetTester tester,
  ) async {
    await pumpTagEditor(tester);
    await letTheRadioAnswer(tester);
    expect(find.text('WORK'), findsOneWidget);

    await tester.tap(find.text('Add tag'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), 'work'); // uppercased
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('WORK is already a tag'), findsOneWidget);
  });

  group('the fake device holds the contract the firmware holds', () {
    Future<String?> code() async => '428913';

    test('a write replaces the whole list and is read back', () async {
      final Services services = await bootPreview(null);

      await services.sync.writeTags(
        'JOTA-PREVIEW-01',
        <String>['ONE', 'TWO'],
        onPairCodeNeeded: code,
      );
      expect(
        await services.sync.readTags(
          'JOTA-PREVIEW-01',
          onPairCodeNeeded: code,
        ),
        <String>['ONE', 'TWO'],
      );
    });

    test('over-long and over-many tags are clamped, not rejected', () async {
      final Services services = await bootPreview(null);

      await services.sync.writeTags(
        'JOTA-PREVIEW-01',
        <String>[
          'THIRTEENCHARS',
          'B',
          'C',
          'D',
          'E',
          'F',
          'G',
          'H',
          'NINTH',
        ],
        onPairCodeNeeded: code,
      );

      final List<String> got = await services.sync.readTags(
        'JOTA-PREVIEW-01',
        onPairCodeNeeded: code,
      );
      expect(got.length, 8, reason: 'max 8 tags');
      expect(got.first, 'THIRTEENCHAR', reason: 'max 12 characters');
      expect(got, isNot(contains('NINTH')));
    });

    test('only the top five reach the device, in list order', () async {
      final Services services = await bootPreview(null);
      await services.settings.setDevice('JOTA-PREVIEW-01', name: 'JOTA');
      final NotesController notes = NotesController(
        repository: services.notes,
        transcription: services.transcription,
      );
      addTearDown(notes.dispose);
      final DeviceController device = DeviceController(
        settings: services.settings,
        scanner: services.scanner,
        sync: services.sync,
        background: services.background,
        notes: notes,
      );
      addTearDown(device.dispose);
      // Become the owner first — writeDeviceTags never prompts for a code, so
      // an unknown phone would simply be skipped and the test would pass for
      // the wrong reason.
      await services.sync.readTags('JOTA-PREVIEW-01', onPairCodeNeeded: code);

      // The contract allows eight. The product sends five, because each extra
      // one is another button press and another e-paper refresh inside the ten
      // seconds you have to tag a note at the wheel.
      const List<String> all = <String>[
        'PERSONAL', 'IDEAS', 'WORK', 'THERAPY', 'MONEY', 'BOOKS', 'HEALTH',
      ];
      await device.writeDeviceTags(all);

      final List<String> onDevice = await services.sync.readTags(
        'JOTA-PREVIEW-01',
        onPairCodeNeeded: code,
      );
      expect(onDevice, all.take(kDeviceTagSlots).toList());
      expect(onDevice, isNot(contains('BOOKS')));

      // And the order is the setting: drag MONEY to the top and it travels,
      // while THERAPY drops off the end. No second switch to keep in step.
      final List<String> reordered = <String>[
        'MONEY', 'PERSONAL', 'IDEAS', 'WORK', 'BOOKS', 'THERAPY', 'HEALTH',
      ];
      await device.writeDeviceTags(reordered);
      expect(
        await services.sync.readTags(
          'JOTA-PREVIEW-01',
          onPairCodeNeeded: code,
        ),
        reordered.take(kDeviceTagSlots).toList(),
      );
    });
  });

  test('a tag armed on the device arrives with the note', () async {
    // The whole point of tagging on a two-button device: the choice made on the
    // panel has to survive the trip. Before this, no note had a tag field on
    // the device at all and pressing select did nothing.
    final Services services = await bootPreview(null);

    final SyncResult r = await services.sync.run(
      'JOTA-PREVIEW-01',
      onPairCodeNeeded: () async => '428913',
    );
    expect(r.ok, isTrue, reason: r.error ?? '');

    final List<Note> notes = await services.notes.all();
    final Note tagged = notes.firstWhere((Note n) => n.noteId == 13);
    expect(tagged.tag, 'WORK');

    // And a note recorded with nothing armed stays untagged, rather than
    // picking up the empty string as a tag named "".
    final Note untagged = notes.firstWhere((Note n) => n.noteId == 15);
    expect(untagged.tag, isNull);
  });

  test('a tag operation refuses to fight a sync for the radio', () async {
    final Services services = await bootPreview(null);

    // Start a run and do NOT await it: while it holds the link, a tag write
    // that opened a second connection would tear the transfer down.
    final Future<SyncResult> run = services.sync.run(
      'JOTA-PREVIEW-01',
      onPairCodeNeeded: () async => '428913',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      () => services.sync.writeTags(
        'JOTA-PREVIEW-01',
        <String>['NOPE'],
        onPairCodeNeeded: () async => '428913',
      ),
      throwsA(isA<SyncException>()),
    );

    await run;
  });
}
