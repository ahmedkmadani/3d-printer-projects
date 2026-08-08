// ============================================================================
//  Jota — pairing
//
//  The mirror of the device's PAIR screen (11_pair.png): the six digits set in
//  the display face, split `428 913`, a rule under them, and one line of
//  instruction. The device shows the code; the phone shows the same shape with
//  the digits empty, waiting to be filled.
//
//  This is the entire security model — possession of the device. Once, then the
//  bond is remembered.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ble/jota_protocol.dart';
import '../design/format.dart';
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

  void _submit() {
    if (!_complete) return;
    Navigator.of(context).pop(_digits);
  }

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return JotaScreen(
      label: 'PAIR',
      // The device puts `BLE` in this slot on its own PAIR screen.
      value: 'BLE',
      onBack: () => Navigator.of(context).pop(),
      footer: JotaButton(
        label: 'Pair',
        primary: true,
        onTap: _complete ? _submit : null,
      ),
      child: Column(
        children: <Widget>[
          const Spacer(),

          // Same big-figure pattern as the device: a code is a figure, so it
          // gets the display face and the same rhythm as a duration.
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // The real field, invisible: it owns the keyboard and the
              // clipboard, while the boxes below own the appearance.
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 1,
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
              GestureDetector(
                onTap: () => _focus.requestFocus(),
                behavior: HitTestBehavior.opaque,
                child: _CodeDisplay(digits: _digits),
              ),
            ],
          ),

          const SizedBox(height: JotaGrid.gapM),
          const JotaRuleStrong(),
          const SizedBox(height: JotaGrid.gapM),
          Text(
            'ENTER THE CODE ON THE DEVICE',
            style: t.reading.copyWith(color: c.inkMuted),
          ),

          const SizedBox(height: JotaGrid.gapXL),
          Text(
            'Press PAIR on Jota. Six digits appear on its screen.',
            textAlign: TextAlign.center,
            style: t.prose.copyWith(color: c.inkMuted, fontSize: 14),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

/// `428 913` in the display face, with an underscore for each digit not yet
/// typed. The gap after three is exactly how the e-paper renders it.
class _CodeDisplay extends StatelessWidget {
  const _CodeDisplay({required this.digits});

  final String digits;

  @override
  Widget build(BuildContext context) {
    final String padded = digits.padRight(kPairCodeLength, '-');
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        fmtPairCode(padded),
        style: context.type.display,
      ),
    );
  }
}
