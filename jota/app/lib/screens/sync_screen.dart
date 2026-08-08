// ============================================================================
//  Jota — sync / device status
//
//  The device's SYNC screen: `SYNC` in the label, `004/005` in the right slot,
//  one progress bar in the middle of the content area, and nothing else. The
//  ratio already lives in the status slot, so the bar carries no text of its
//  own — the same reasoning as screens.cpp, screenSyncing().
//
//  Below the fold, the facts a device screen has no room for: battery, pending
//  count read from the ADVERTISEMENT (no connection needed), clock drift.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble/background_sync.dart';
import '../ble/jota_protocol.dart';
import '../ble/sync_engine.dart';
import '../design/format.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import 'pair_screen.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

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
  /// user types (or null if they cancel — three wrong codes cost a 30-second
  /// advertising blackout, so a cancel must not become a guess).
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

    final SyncProgress p = device.progress;
    final JotaAdvertisement? ad = device.pairedAdvertisement;

    return JotaScreen(
      label: 'SYNC',
      // STATUS RIGHT SLOT RULE: the run's ratio while it runs, otherwise how
      // many notes the device says are waiting.
      value: p.isRunning
          ? fmtRatio(p.notesDone, p.notesTotal)
          : ad != null
              ? fmtCount(ad.pending)
              : null,
      onBack: () => Navigator.of(context).pop(),
      footer: _Footer(device: device),
      child: ListView(
        padding: const EdgeInsets.only(top: JotaGrid.gapXL),
        children: <Widget>[
          _ProgressBlock(progress: p),
          const SizedBox(height: JotaGrid.gapXL),
          const JotaRule(),
          const SizedBox(height: JotaGrid.gapM),
          _DeviceFacts(device: device),
          const SizedBox(height: JotaGrid.gapL),
          if (!device.hasPairedDevice) _DeviceList(device: device),
          if (device.lastError != null) ...<Widget>[
            const SizedBox(height: JotaGrid.gapL),
            Text(
              device.lastError!,
              style: context.type.reading.copyWith(color: context.ink.signal),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.progress});

  final SyncProgress progress;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        JotaProgressBar(
          fraction: progress.overallFraction,
          // Before the first chunk lands, a bar sitting at 0% claims to know
          // something it does not.
          indeterminate: progress.isRunning &&
              progress.bytesExpected == 0 &&
              progress.notesTotal == 0,
        ),
        const SizedBox(height: JotaGrid.gapM),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              progress.message?.toUpperCase() ??
                  (progress.phase == SyncPhase.idle ? 'READY' : ''),
              style: t.label.copyWith(color: c.inkMuted),
            ),
            if (progress.currentNoteId != null)
              Text(fmtNoteId(progress.currentNoteId!), style: t.reading),
          ],
        ),
        if (progress.bytesExpected > 0) ...<Widget>[
          const SizedBox(height: JotaGrid.gapS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // "Resuming" is worth saying out loud: it is the difference
              // between this app and one that restarts a 480 KB transfer.
              Text(
                progress.resumed ? 'RESUMED' : '',
                style: t.reading.copyWith(color: c.inkMuted),
              ),
              Text(
                '${fmtBytes(progress.bytesReceived)} / '
                '${fmtBytes(progress.bytesExpected)}',
                style: t.reading.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ],
        if (progress.error != null) ...<Widget>[
          const SizedBox(height: JotaGrid.gapS),
          Text(
            progress.error!,
            style: t.reading.copyWith(color: c.signal),
          ),
        ],
      ],
    );
  }
}

class _DeviceFacts extends StatelessWidget {
  const _DeviceFacts({required this.device});

  final DeviceController device;

  @override
  Widget build(BuildContext context) {
    final JotaAdvertisement? ad = device.pairedAdvertisement;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        JotaKeyValue(
          name: 'Device',
          value: device.hasPairedDevice ? 'PAIRED' : 'NONE',
        ),
        JotaKeyValue(
          name: 'In range',
          value: ad == null ? 'NO' : 'YES  ${ad.rssi} dBm',
        ),
        // Straight from the advertisement — no connection was made to learn
        // this, which is exactly why the manufacturer-data field exists.
        JotaKeyValue(
          name: 'Waiting',
          value: ad == null ? '---' : fmtCount(ad.pending),
          emphasis: (ad?.pending ?? 0) > 0,
        ),
        JotaKeyValue(
          name: 'Bluetooth',
          value:
              device.bluetoothReady ? 'ON' : device.adapter.name.toUpperCase(),
        ),
        JotaKeyValue(
          name: 'Background',
          value: _modeLabel(device.backgroundMode),
        ),
      ],
    );
  }

  static String _modeLabel(BackgroundMode m) {
    switch (m) {
      case BackgroundMode.off:
        return 'OFF';
      case BackgroundMode.foregroundService:
        return 'SERVICE';
      case BackgroundMode.systemWake:
        return 'SYSTEM';
      case BackgroundMode.denied:
        return 'DENIED';
    }
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.device});

  final DeviceController device;

  @override
  Widget build(BuildContext context) {
    final List<JotaAdvertisement> found = device.inRange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'IN RANGE',
          style: context.type.label.copyWith(color: context.ink.inkMuted),
        ),
        const SizedBox(height: JotaGrid.gapM),
        if (found.isEmpty)
          Text(
            device.isScanning ? 'SCANNING…' : 'NOTHING FOUND',
            style: context.type.reading.copyWith(color: context.ink.inkMuted),
          )
        else
          for (final JotaAdvertisement ad in found) ...<Widget>[
            JotaRow(
              label: ad.name,
              trailing: Text(fmtCount(ad.pending)),
              onTap: () => device.pairWith(ad),
            ),
            const SizedBox(height: JotaRows.gap),
          ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.device});

  final DeviceController device;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: JotaButton(
            label: device.isSyncing ? 'Syncing' : 'Sync now',
            primary: true,
            busy: device.isSyncing,
            onTap: device.hasPairedDevice && !device.isSyncing
                ? () => device.syncNow()
                : null,
          ),
        ),
        const SizedBox(width: JotaRows.gap),
        SizedBox(
          width: 120,
          child: JotaButton(
            label: device.isScanning ? 'Scanning' : 'Scan',
            onTap: device.isScanning
                ? () => device.stopScan()
                : () => device.startScan(),
          ),
        ),
      ],
    );
  }
}
