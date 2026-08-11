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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      context.read<DeviceController>().startScan();
    });
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
      child: _body(device),
    );
  }

  Widget _body(DeviceController device) {
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
      return const _Status(
        title: "Jota isn't nearby",
        body: 'Turn it on and keep it close, then look again.',
      );
    }
    final int pending = device.pendingOnDevice ?? 0;
    if (pending == 0) {
      return const _Status(
        title: 'All caught up',
        body: 'Everything on your Jota is saved here.',
      );
    }
    return _Ready(count: pending);
  }

  Widget? _footer(DeviceController device) {
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
        onTap: () => device.startScan(),
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
class _Status extends StatelessWidget {
  const _Status({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(title, style: t.headline, textAlign: TextAlign.center),
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
        Text('Connect your Jota', style: t.headline, textAlign: TextAlign.center),
        const SizedBox(height: JotaGrid.gapXL),
        if (found.isEmpty)
          Text(
            device.isScanning ? 'Looking for your Jota…' : 'No Jota found nearby.',
            style: t.prose.copyWith(color: c.inkMuted),
            textAlign: TextAlign.center,
          )
        else
          for (final JotaAdvertisement ad in found) ...<Widget>[
            JotaRow(label: ad.name, onTap: () => device.pairWith(ad)),
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
