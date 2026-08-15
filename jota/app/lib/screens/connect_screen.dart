// ============================================================================
//  Jota — first run: connect your Jota
//
//  This step used to be a six-digit field that threw the digits away. It set
//  `hasSeenOnboarding`, pushed the tag step, and never scanned, connected or
//  wrote `auth` — so the user was walked through a TIMED ritual, device in
//  hand, for nothing, and two screens later the app said "No Jota paired".
//
//  Now it is the real thing, and it is ONE screen: the Jotas in range, and —
//  the moment the engine actually needs them — the six digits, right underneath
//  the device you just tapped. The code entry used to be a pushed page, which
//  meant the device list vanished at exactly the moment you wanted to check you
//  had tapped the right one.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ble/jota_protocol.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/services.dart';
import 'tag_setup_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  bool _moved = false;
  bool _submitted = false;

  String get _digits => _code.text;
  bool get _complete => _digits.length == kPairCodeLength;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // No timeout: a person on this screen is holding the device and looking
      // for it to appear. Giving up after fifteen seconds would mean switching
      // Jota on at the wrong moment loses you the whole step.
      context.read<DeviceController>().startScan(timeout: null);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
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

  void _submit(DeviceController device) {
    if (!_complete || _submitted) return;
    _submitted = true;
    device.submitPairCode(_digits);
    _code.clear();
    _submitted = false;
  }

  @override
  Widget build(BuildContext context) {
    final DeviceController device = context.watch<DeviceController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final bool wantsCode = device.needsPairCode;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Paired and not mid-prompt: this step is done. Move on by itself rather
      // than making someone confirm what they can already see happened.
      if (device.hasPairedDevice && !wantsCode) _onwards();
      if (wantsCode && !_codeFocus.hasFocus) _codeFocus.requestFocus();
    });

    final List<JotaAdvertisement> found = device.inRange;

    return JotaScreen(
      label: 'Connect',
      upcase: false,
      footer: wantsCode
          ? null
          : JotaButton(label: 'Set up later', upcase: false, onTap: _onwards),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: JotaGrid.gapM),
          Text('Connect your Jota', style: t.headline),
          const SizedBox(height: JotaGrid.gapS),
          Text(
            // The device is not obvious to operate, and nothing else in the
            // product says this. It shows its code by itself when no phone owns
            // it, so there is no menu to talk anyone through any more.
            'Switch it on. It shows a code the first time.',
            style: t.prose.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: JotaGrid.gapL),
          const JotaRule(),
          const SizedBox(height: JotaGrid.gapM),

          // The Jotas in range. The id-bearing name, because every Jota
          // advertises as plain "JOTA" and the bare local name cannot tell two
          // of them apart — these are the same four characters the device
          // prints on its own screen.
          for (final JotaAdvertisement ad in found) ...<Widget>[
            JotaRow(
              label: ad.shortName,
              selected: device.pairedId == ad.remoteId,
              trailing: Text(
                'NEARBY',
                style: t.reading.copyWith(color: c.inkMuted, fontSize: 11),
              ),
              onTap: wantsCode ? null : () => device.pairWith(ad),
            ),
            const SizedBox(height: JotaRows.gap),
          ],

          if (found.isEmpty || device.isScanning)
            Padding(
              padding: const EdgeInsets.only(top: JotaGrid.gapS),
              child: Text(
                found.isEmpty
                    ? (device.isScanning
                        ? 'Looking for your Jota…'
                        : 'No Jota found nearby.')
                    : 'Looking for more…',
                style: t.prose.copyWith(color: c.inkMuted),
              ),
            ),

          const Spacer(),

          if (wantsCode) ...<Widget>[
            Text(
              'Enter the code showing on Jota',
              style: t.prose.copyWith(color: c.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: JotaGrid.gapM),
            // The boxes are the visible field; the real one is invisible behind
            // them, which is how the digits can be mono and evenly spaced
            // without fighting a text cursor.
            Stack(
              alignment: Alignment.center,
              children: <Widget>[
                JotaCodeBoxes(digits: _digits, length: kPairCodeLength),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _code,
                      focusNode: _codeFocus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(kPairCodeLength),
                      ],
                      onChanged: (String v) {
                        if (v.length == kPairCodeLength) _submit(device);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: JotaGrid.gapL),
            JotaButton(
              label: 'Pair',
              primary: true,
              upcase: false,
              // Dimmed until six digits exist. A live button on an incomplete
              // code invites a press that can only fail.
              onTap: _complete ? () => _submit(device) : null,
            ),
            const SizedBox(height: JotaGrid.gapM),
          ],

          if (device.lastError != null) ...<Widget>[
            const SizedBox(height: JotaGrid.gapM),
            Text(
              device.lastError!,
              style: t.prose.copyWith(color: c.signal),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: JotaGrid.gapM),
          ],
        ],
      ),
    );
  }
}
