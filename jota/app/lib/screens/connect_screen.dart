// ============================================================================
//  Jota — first run: connect your Jota
//
//  This step used to be a six-digit field that threw the digits away. It set
//  `hasSeenOnboarding`, pushed the tag step, and never scanned, connected or
//  wrote `auth` — so the user was walked through a TIMED ritual, device in
//  hand, for nothing, and two screens later the app said "No Jota paired".
//
//  Now it is the real thing, and it is the same path the Sync tab uses:
//  scan, tap the device you can see the name of, pair. The six digits are only
//  asked for at the moment the engine actually needs them.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble/jota_protocol.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/services.dart';
import 'pair_screen.dart';
import 'tag_setup_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _pairSheetOpen = false;
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No timeout: a person on this screen is holding the device and looking
      // for it to appear. Giving up after fifteen seconds would mean switching
      // Jota on at the wrong moment loses you the whole step.
      context.read<DeviceController>().startScan(timeout: null);
    });
  }

  /// The engine blocks mid-pair waiting for the digits on the e-paper. Show the
  /// code screen exactly then — not before, and never as decoration.
  Future<void> _maybeAskForCode(DeviceController device) async {
    if (!device.needsPairCode || _pairSheetOpen) return;
    _pairSheetOpen = true;
    final String? code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const PairScreen()),
    );
    _pairSheetOpen = false;
    device.submitPairCode(code);
  }

  Future<void> _onwards() async {
    if (_moved) return;
    _moved = true;
    await context.read<Services>().settings.setHasSeenOnboarding(true);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const TagSetupScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DeviceController device = context.watch<DeviceController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeAskForCode(device);
      // Paired and not mid-prompt: this step is done. Move on by itself rather
      // than making someone confirm what they can already see happened.
      if (device.hasPairedDevice && !device.needsPairCode) _onwards();
    });

    final List<JotaAdvertisement> found = device.inRange;

    return JotaScreen(
      label: 'Connect',
      upcase: false,
      footer: JotaButton(
        label: 'Set up later',
        upcase: false,
        onTap: _onwards,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Connect your Jota',
            style: t.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: JotaGrid.gapM),
          Text(
            // The device is not obvious to operate, and nothing else in the
            // product says this. The button names are the SHAPES on the case,
            // because "BOOT" and "PWR" appear nowhere on the hardware.
            'Switch it on. If it asks for a code, press the round button to '
            'open the menu, step down to PAIR, then press the star.',
            style: t.prose.copyWith(color: c.inkMuted),
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
              // The id-bearing name: every Jota advertises as "JOTA", so the
              // bare local name cannot tell two of them apart. These are the
              // same four characters the device prints on its own PAIR screen.
              JotaRow(
                label: ad.shortName,
                onTap: () => device.pairWith(ad),
              ),
              const SizedBox(height: JotaRows.gap),
            ],
          if (device.lastError != null) ...<Widget>[
            const SizedBox(height: JotaGrid.gapL),
            Text(
              device.lastError!,
              style: t.prose.copyWith(color: c.signal),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
