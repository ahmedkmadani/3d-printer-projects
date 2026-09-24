// ============================================================================
//  Jota — erase over BLE
//
//  The contract's promise: an erase wipes the DEVICE — notes, tags, bond —
//  and only the owner can ask. The fake models the firmware's behaviour, so
//  these tests hold the app to the sequence real hardware will demand.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:jota/ble/sync_service.dart';
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
  test('an erase wipes the device and drops the bond', () async {
    final Services services = await boot();

    int prompts = 0;
    Future<String?> code() async {
      prompts++;
      return kPreviewPairCode;
    }

    // Pair and drain the device first, so the erase acts on a bonded Jota.
    final SyncResult first =
        await services.sync.run(kPreviewDeviceId, onPairCodeNeeded: code);
    expect(first.ok, isTrue, reason: first.error ?? '');
    expect(prompts, 1);

    await services.sync.eraseDevice(kPreviewDeviceId);

    // The bond died with the wipe: the next connection is a stranger's and
    // must be asked for fresh digits.
    await services.sync.run(kPreviewDeviceId, onPairCodeNeeded: code);
    expect(
      prompts,
      2,
      reason: 'after an erase, the device must demand the digits again',
    );
  });

  test('a phone that is not the owner cannot erase', () async {
    final Services services = await boot();

    // Never paired: this phone's app id is not the owner (nobody is), and the
    // erase must be refused rather than wiping a device it does not hold.
    expect(
      () => services.sync.eraseDevice(kPreviewDeviceId),
      throwsA(isA<SyncException>()),
    );
  });
}
