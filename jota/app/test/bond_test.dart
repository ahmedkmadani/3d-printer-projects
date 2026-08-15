// ============================================================================
//  Jota — pairing and the owner bond
//
//  The defect these cover was invisible from the app: `status` is readable
//  unauthenticated, the app treated a successful read as proof of a bond, so it
//  never sent a code — and `index` answers `[]` to an unauthenticated reader.
//  Every sync therefore reported "all caught up" while the advertisement said
//  three notes were waiting.
//
//  So: assert the handshake actually happens, that it happens ONLY once, and
//  that the door is still openable by whoever is holding the device.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/ble/jota_protocol.dart';
import 'package:jota/ble/sync_service.dart';
import 'package:jota/data/settings_store.dart';
import 'package:jota/preview/preview_services.dart';
import 'package:jota/preview/seed_data.dart';
import 'package:jota/state/services.dart';

Future<Services> boot() async {
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

void main() {
  test('the first sync asks for the code, and the next one never does', () async {
    final Services services = await boot();

    int prompts = 0;
    Future<String?> code() async {
      prompts++;
      return kPreviewPairCode;
    }

    final SyncResult first = await services.sync.run(
      kPreviewDeviceId,
      onPairCodeNeeded: code,
    );
    expect(first.ok, isTrue, reason: first.error ?? '');
    expect(first.notesAdded, greaterThan(0), reason: 'notes must actually move');
    expect(prompts, 1, reason: 'a first pairing needs the digits');

    // The bond. This is the whole point: the device remembers this phone, so
    // reconnecting is silent.
    await services.sync.run(kPreviewDeviceId, onPairCodeNeeded: code);
    expect(prompts, 1, reason: 'the owner must never be asked again');
  });

  test('a wrong code is refused and moves no notes', () async {
    final Services services = await boot();

    final SyncResult r = await services.sync.run(
      kPreviewDeviceId,
      onPairCodeNeeded: () async => '000000',
    );
    expect(r.ok, isFalse);
    expect(r.notesAdded, 0);
  });

  test('cancelling the code prompt gives up without pairing', () async {
    final Services services = await boot();

    final SyncResult r = await services.sync.run(
      kPreviewDeviceId,
      onPairCodeNeeded: () async => null,
    );
    expect(r.ok, isFalse);
    expect(r.error, contains('cancelled'));
  });

  test('a second phone is refused, but the code still lets it in', () async {
    // Two installs, one device. The bond belongs to whoever paired first.
    final Services phoneA = await boot();
    await phoneA.sync.run(
      kPreviewDeviceId,
      onPairCodeNeeded: () async => kPreviewPairCode,
    );

    // A different install has a different uuid...
    final Services phoneB = await boot();
    expect(phoneB.settings.appId, isNot(phoneA.settings.appId));

    // ...so it is challenged rather than let in silently.
    int prompts = 0;
    final SyncResult refused = await phoneB.sync.run(
      kPreviewDeviceId,
      onPairCodeNeeded: () async {
        prompts++;
        return '000000';
      },
    );
    expect(refused.ok, isFalse);
    expect(prompts, 1);

    // But possession of the device wins: the digits on the e-paper transfer
    // ownership. A Jota that could lock out the person holding it would be
    // worse, not better.
    final SyncResult allowed = await phoneB.sync.run(
      kPreviewDeviceId,
      onPairCodeNeeded: () async => kPreviewPairCode,
    );
    expect(allowed.ok, isTrue, reason: allowed.error ?? '');
  });

  group('identity', () {
    test('a device id becomes the name a person reads', () {
      expect(jotaShortName('7f3a91c4'), 'JOTA-91C4');
      expect(jotaShortName(''), 'JOTA');
    });

    test('app ids are unique per install and shaped like uuids', () {
      final Set<String> ids = <String>{for (int i = 0; i < 64; i++) newAppId()};
      expect(ids.length, 64);
      expect(
        ids.every(
          (String id) => RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ).hasMatch(id),
        ),
        isTrue,
      );
    });

    test('the advertisement carries the id, unconnected', () {
      const JotaAdvertisement ad = JotaAdvertisement(
        remoteId: 'x',
        name: 'JOTA',
        pending: 2,
        paired: true,
        owned: true,
        deviceId: 0x91c4,
        rssi: -50,
      );
      expect(ad.shortName, 'JOTA-91C4');
      expect(ad.hasWork, isTrue);
    });
  });
}
