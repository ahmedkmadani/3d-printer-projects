// ============================================================================
//  Jota — pairing again
//
//  The sync engine blocks mid-sync when the device refuses the bond and asks
//  for the six digits on its e-paper; this screen collects them and hands them
//  back. First-run pairing does NOT come through here — connect_screen.dart
//  owns that, with the device list still on screen underneath the boxes.
//
//  One box per digit, exactly as on first run. It used to be six characters of
//  the display face with dashes standing in for the digits you had not typed,
//  which read as a code the app was SHOWING you rather than a field. Only the
//  device ever shows the code — the phone only ever asks for it.
//
//  This is the entire security model — possession of the device. Once, then the
//  bond is remembered.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ble/jota_protocol.dart';
import '../design/theme.dart';
import '../design/widgets.dart';

class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  String get _digits => _controller.text;
  bool get _complete => _digits.length == kPairCodeLength;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Hand the code back to the caller, which writes it to the device inside
  /// the pairing it already started.
  ///
  /// There is no longer a "first run" branch here. It used to swallow the six
  /// digits and walk on — the field was collected, discarded, and the app then
  /// told the user no device was paired. A code screen with nothing behind it
  /// is worse than no code screen.
  void _submit() {
    if (!_complete) return;
    Navigator.of(context).pop(_digits);
  }

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    // The app's own chrome, not a bespoke chevron: this is a pushed screen like
    // any other, and popping it cancels the pairing the engine is waiting on.
    return JotaScreen(
      label: 'Pair',
      upcase: false,
      onBack: () => Navigator.of(context).pop(),
      // One hairline, and it is the one under "Pair with Jota" in the body. The
      // status rule as well made two.
      rule: false,
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
          child: LayoutBuilder(
        // Scrollable, because the keyboard is up on this screen by definition:
        // a fixed Column under a Scaffold that resizes for the keyboard has
        // only its Spacer to give, and a Spacer bottoms out at zero — past
        // that it overflows.
        //
        // LayoutBuilder + IntrinsicHeight rather than a bare scroll view: a
        // Spacer needs a bounded height to divide, and a scroll view hands its
        // child infinite height. This floors the column at the viewport, so the
        // Spacer still centres things when there is room and the whole thing
        // scrolls once the keyboard takes that room away.
        builder: (BuildContext context, BoxConstraints viewport) =>
            SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: IntrinsicHeight(
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: JotaGrid.gapM),
          Text('Pair with Jota', style: t.headline),
          const SizedBox(height: JotaGrid.gapS),
          Text(
            // The device only accepts a code while its PAIR screen is up, and
            // nothing else in the app says how to get there.
            // The device has no PAIR menu item any more — it shows its code
            // by itself whenever no phone owns it. Telling someone to press a
            // button that no longer exists is worse than saying nothing.
            'Jota shows its code whenever no phone owns it.',
            style: t.prose.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: JotaGrid.gapL),
          const JotaRule(),

          // A fixed gap, not a Spacer. This column lives inside a scroll
          // view so it can survive the keyboard, and a scroll view hands its
          // child unbounded height — a flex child cannot divide infinity, so a
          // Spacer here is a layout error rather than a centred screen.
          const SizedBox(height: JotaGrid.gapXL * 2),

          Text(
            'Enter the code showing on Jota',
            style: t.prose.copyWith(color: c.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: JotaGrid.gapM),
          // The boxes are the visible field; the real one is invisible behind
          // them, which is how the digits can be mono and evenly spaced without
          // fighting a text cursor. Tapping anywhere on them takes the keyboard.
          GestureDetector(
            onTap: () => _focus.requestFocus(),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                JotaCodeBoxes(digits: _digits, length: kPairCodeLength),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(kPairCodeLength),
                      ],
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: JotaGrid.gapL),
          JotaButton(
            label: 'Pair',
            primary: true,
            upcase: false,
            // Dimmed until six digits exist. A live button on an incomplete
            // code invites a press that can only fail.
            onTap: _complete ? _submit : null,
          ),
          const SizedBox(height: JotaGrid.gapM),
        ],
      ),
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}
