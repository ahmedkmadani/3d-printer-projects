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
import 'home_shell.dart';

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
      // Straight into the app. There used to be a tag-picking step here, and
      // product.md is explicit that tags live in Settings only — choosing them
      // before you own a single note is a decision made with no information,
      // and it stood between pairing and the thing you came for.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
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
      // Bonded, and not mid-prompt: this step is done. Move on by itself
      // rather than making someone confirm what they can already see happened.
      //
      // `isPairing` is the fix for a real defect: hasPairedDevice goes true as
      // soon as the id is written down, which is BEFORE the handshake, so this
      // fired mid-pairing and replaced the screen with Home. The code prompt
      // then had nowhere to appear and Home raised a second one on top.
      if (device.hasPairedDevice && !wantsCode && !device.isPairing) {
        _onwards();
      }
      // Never grab the keyboard from a screen that is sitting on top of this
      // one.
      final ModalRoute<Object?>? route = ModalRoute.of(context);
      final bool visible = route == null || route.isCurrent;
      if (wantsCode && visible && !_codeFocus.hasFocus) {
        _codeFocus.requestFocus();
      }
    });

    final List<JotaAdvertisement> found = device.inRange;

    return JotaScreen(
      label: 'Connect',
      upcase: false,
      // The hairline under "Connect your Jota" in the body is this screen's
      // one piece of chrome; the status line does not get a second.
      rule: false,
      footer: wantsCode
          ? null
          : JotaButton(label: 'Set up later', upcase: false, onTap: _onwards),
      child: SingleChildScrollView(
        // Scrollable, because on this screen the keyboard is up by definition.
        // A fixed Column under a Scaffold that resizes for the keyboard has
        // only its Spacer to give, and a Spacer bottoms out at zero — past
        // that it overflows. Small phone + a found device + the keyboard is
        // exactly that case.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height * 0.60,
          ),
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
          for (final JotaAdvertisement ad in found)
            _FoundRow(
              name: ad.shortName,
              state: device.pairedId == ad.remoteId ? 'PAIRED' : 'NEARBY',
              onTap: wantsCode ? null : () => device.pairWith(ad),
            ),

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

          // A fixed gap, not a Spacer. This column lives inside a scroll
          // view so it can survive the keyboard, and a scroll view hands its
          // child unbounded height — a flex child cannot divide infinity, so a
          // Spacer here is a layout error rather than a centred screen.
          const SizedBox(height: JotaGrid.gapXL * 2),

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
        ),
      ),
    );
  }
}

/// One Jota in range: its id on the left, what it is to us on the right, a
/// hairline under it — the same flat line Settings draws, and the design's
/// `.row` exactly.
///
/// It used to be a [JotaRow], an outlined stadium. A stadium in this product
/// means "one of these is selected", and a list of devices you have not chosen
/// between yet is not that; two of them read as two buttons on a screen whose
/// only button is Pair. Both halves are mono because both are identifiers, not
/// prose — the id and the one word that says what the radio can see.
class _FoundRow extends StatelessWidget {
  const _FoundRow({required this.name, required this.state, this.onTap});

  final String name;
  final String state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(child: Text(name, style: t.reading)),
                  const SizedBox(width: JotaGrid.gapM),
                  Text(
                    state,
                    style: t.reading.copyWith(
                      color: c.inkMuted,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const JotaRule(),
          ],
        ),
      ),
    );
  }
}
