// ============================================================================
//  Jota — sync / device
//
//  Deliberately plain. The person using this is not thinking about RSSI, bytes,
//  or foreground services — they want to know one thing: are my notes safe on my
//  phone yet? So the screen answers exactly that, in one line and one button:
//
//    not paired      →  connect your Jota (tap it)
//    not nearby      →  turn it on and keep it close
//    notes waiting   →  "3 notes ready" + Save to phone
//    saving          →  a bar and "Saving your notes…"
//    nothing waiting →  "All caught up"
//
//  Everything technical (signal strength, byte progress, background policy) is
//  gone from the surface; the engine still does all of it underneath.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble/device_scanner.dart';
import '../ble/jota_protocol.dart';
import '../ble/sync_service.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import 'pair_screen.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, this.embedded = false});

  /// True when shown as a tab inside the home shell — there is no route to pop
  /// back to, so the back chevron is dropped.
  final bool embedded;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _pairSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final DeviceController device = context.read<DeviceController>();
      // No timeout: while this screen is open, keep watching. A 15-second
      // window meant a Jota switched on twenty seconds after you opened Sync
      // was never seen, and the screen sat on "isn't nearby" with a button
      // asking you to look again — for a device that was, by then, right there.
      device.startScan(timeout: null);
      device.resumeAutoSync();
    });
  }

  /// Held rather than looked up in [dispose]: by then the element is
  /// deactivated and an ancestor lookup is unsafe.
  DeviceController? _device;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _device = context.read<DeviceController>();
  }

  @override
  void dispose() {
    // Scanning is not free. Hand the radio back when this screen goes away,
    // unless background sync owns it.
    final DeviceController? device = _device;
    if (device != null && !device.wantsBackgroundScan) {
      unawaited(device.stopScan());
    }
    super.dispose();
  }

  /// The engine blocks mid-sync waiting for the six digits on the e-paper.
  /// Surface the pair screen the moment it asks, and hand back whatever the
  /// user types (or null if they cancel).
  Future<void> _maybeAskForCode(DeviceController device) async {
    if (!device.needsPairCode || _pairSheetOpen) return;
    _pairSheetOpen = true;
    final String? code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const PairScreen()),
    );
    _pairSheetOpen = false;
    device.submitPairCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final DeviceController device = context.watch<DeviceController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAskForCode(device);
    });

    return JotaScreen(
      label: 'Sync',
      upcase: false,
      onBack: widget.embedded ? null : () => Navigator.of(context).pop(),
      footer: _footer(device),
      child: Column(
        children: <Widget>[
          Expanded(child: _body(device)),
          // lastError was set on every failed sync and read by nothing, so a
          // wrong code, a refusal from an owned device or a dropped link all
          // ended with the screen quietly back on "3 notes ready to save".
          if (device.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: JotaGrid.gapM),
              child: Text(
                device.lastError!,
                style: context.type.prose.copyWith(color: context.ink.signal),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(DeviceController device) {
    // "Denied" and "off" need different things from the person, and a button
    // offering to switch Bluetooth on cannot fix a refused permission.
    if (device.adapter == AdapterStatus.unauthorized) {
      return const _Status(
        title: 'Jota needs permission',
        body: 'Allow Nearby devices for Jota in your phone settings, so it '
            'can find your device. Nothing is sent anywhere.',
      );
    }
    if (!device.bluetoothReady) {
      return const _Status(
        title: 'Bluetooth is off',
        body: 'Turn on Bluetooth so your phone can find Jota.',
      );
    }
    if (device.isSyncing) {
      return _Saving(progress: device.progress);
    }
    if (!device.hasPairedDevice) {
      return _Connect(device: device);
    }
    if (device.pairedAdvertisement == null) {
      // Still watching — there is no "look again", because it never stopped.
      return const _Status(
        title: "Waiting for your Jota",
        body: 'Turn it on and keep it close. This syncs on its own as soon as '
            'it comes into range.',
      );
    }
    // Notes first, ALWAYS. A low battery is exactly when the waiting notes
    // matter most — burying them under a charge warning would hide the one
    // thing worth acting on, and the notes are what a dying Jota takes with it.
    final int pending = device.pendingOnDevice ?? 0;
    if (pending > 0) return _Ready(count: pending);

    final int? battery = device.batteryOnDevice;
    if (battery != null && battery <= 15) {
      return _Status(
        // The percentage used to be inside this title, which is serif — and
        // numbers are never serif (docs/brand.md). It is the same figure the
        // device chip draws, so it moves to the mono line under the headline
        // rather than being dropped: "low" is the news, the figure is the
        // evidence, and each is now in the face for its job.
        title: 'Jota is nearly out of charge',
        figure: '$battery%',
        body: 'Charge it over USB-C soon. Everything it had is saved here.',
      );
    }

    return const _Status(
      title: 'All caught up',
      body: 'Everything on your Jota is saved here.',
    );
  }

  Widget? _footer(DeviceController device) {
    // Nothing this screen can do about a refused permission — offering a
    // button that cannot work is worse than offering none.
    if (device.adapter == AdapterStatus.unauthorized) return null;
    if (!device.bluetoothReady) {
      // Android: one tap raises the system enable dialog. iOS: turnOn returns
      // false, so we start a scan, which makes iOS show its own power alert.
      return JotaButton(
        label: 'Turn on Bluetooth',
        primary: true,
        upcase: false,
        onTap: () async {
          final bool ok = await device.turnOnBluetooth();
          if (!ok) await device.startScan();
        },
      );
    }
    if (!device.hasPairedDevice) return null;
    if (device.isSyncing) {
      return const JotaButton(
        label: 'Saving',
        primary: true,
        busy: true,
        upcase: false,
      );
    }
    if (device.pairedAdvertisement == null) {
      return JotaButton(
        label: 'Look again',
        upcase: false,
        onTap: () {
          device.startScan(timeout: null);
          device.resumeAutoSync();
        },
      );
    }
    if ((device.pendingOnDevice ?? 0) == 0) {
      return JotaButton(
        label: 'Check again',
        upcase: false,
        onTap: () => device.startScan(),
      );
    }
    return JotaButton(
      label: 'Save to phone',
      primary: true,
      upcase: false,
      onTap: () => device.syncNow(),
    );
  }
}

/// One headline and one plain line, centred. The whole screen, most of the time.
///
/// [figure] is the optional mono run between them — the one measurement a state
/// has, when it has one. It is a separate slot rather than a placeholder in the
/// title because the title is serif and no figure is ever allowed in that face.
class _Status extends StatelessWidget {
  const _Status({required this.title, required this.body, this.figure});

  final String title;
  final String body;
  final String? figure;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(title, style: t.headline, textAlign: TextAlign.center),
        if (figure != null) ...<Widget>[
          const SizedBox(height: JotaGrid.gapS),
          Text(
            figure!,
            style: t.reading.copyWith(color: c.inkMuted, letterSpacing: 0.8),
          ),
        ],
        const SizedBox(height: JotaGrid.gapM),
        Text(
          body,
          style: t.prose.copyWith(color: c.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// The number of notes waiting, big and friendly, over a plain caption.
class _Ready extends StatelessWidget {
  const _Ready({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text('$count', style: t.display.copyWith(fontSize: 64)),
        const SizedBox(height: JotaGrid.gapS),
        Text(
          count == 1 ? 'note ready to save' : 'notes ready to save',
          style: t.prose.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }
}

/// A bar and a reassurance. No byte counts, no ratios.
class _Saving extends StatelessWidget {
  const _Saving({required this.progress});

  final SyncProgress progress;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final bool indeterminate = progress.isRunning &&
        progress.bytesExpected == 0 &&
        progress.notesTotal == 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        JotaProgressBar(
          fraction: progress.overallFraction,
          indeterminate: indeterminate,
        ),
        const SizedBox(height: JotaGrid.gapL),
        Text(
          'Saving your notes…',
          style: t.prose.copyWith(color: c.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// First run: tap your Jota to connect. Names only — no signal, no counts.
class _Connect extends StatelessWidget {
  const _Connect({required this.device});

  final DeviceController device;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final List<JotaAdvertisement> found = device.inRange;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Connect your Jota',
          style: t.headline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: JotaGrid.gapXL),
        if (found.isEmpty)
          Text(
            device.isScanning
                ? 'Looking for your Jota…'
                : 'No Jota found nearby.',
            style: t.prose.copyWith(color: c.inkMuted),
            textAlign: TextAlign.center,
          )
        else
          for (final JotaAdvertisement ad in found) ...<Widget>[
            // The id-bearing name: every Jota advertises as plain "JOTA".
            JotaRow(label: ad.shortName, onTap: () => device.pairWith(ad)),
            const SizedBox(height: JotaRows.gap),
          ],
        const SizedBox(height: JotaGrid.gapXL),
        Text(
          'Turn it on and hold it close.',
          style: t.prose.copyWith(color: c.inkMuted, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
