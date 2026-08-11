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
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../ble/jota_protocol.dart';
import '../design/format.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/services.dart';
import 'tag_setup_screen.dart';

class PairScreen extends StatefulWidget {
  const PairScreen({super.key, this.firstRun = false});

  /// True when this is the last step of the first-run flow: there is no route
  /// to pop back to (onboarding was replaced), so submitting or skipping moves
  /// forward into the app instead of returning the code to a caller.
  final bool firstRun;

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
    if (widget.firstRun) {
      unawaited(_enterApp());
      return;
    }
    // Normal path (reached from SYNC): hand the code back to the caller, which
    // writes it to the device inside the sync it already started.
    Navigator.of(context).pop(_digits);
  }

  /// First-run only: the real scan → connect → auth is wired in a later phase;
  /// for now finishing the flow means marking onboarding done and landing on
  /// the notes.
  Future<void> _enterApp() async {
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
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    // No status bar: the device's PAIR screen is a code and a line, so the
    // phone's is too. The headline and the six digits are the whole screen;
    // everything else recedes to muted ink and a single faded hairline.
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // A quiet back chevron, and only when there is somewhere to go:
            // in first-run onboarding was replaced, so nothing pops. No label,
            // no rule — just the affordance.
            if (!widget.firstRun)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  JotaGrid.gapS,
                  JotaGrid.gapS,
                  JotaGrid.margin,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(JotaGrid.gapM),
                        child: _BackChevron(),
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: JotaGrid.margin,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // The one warm, elegant line on the screen — everything
                      // below it is the device's own mono discipline.
                      Text('Enter the code', style: t.headline),
                      const SizedBox(height: JotaGrid.gapXL),

                      // Same big-figure pattern as the device: a code is a
                      // figure, so it gets the display face.
                      Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          // The real field, invisible: it owns the keyboard and
                          // the clipboard, while the boxes below own the look.
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
                                  LengthLimitingTextInputFormatter(
                                    kPairCodeLength,
                                  ),
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

                      const SizedBox(height: JotaGrid.gapL),
                      // Faded hairline, not the heavy status rule: soft under
                      // the code so the digits stay the focus.
                      const JotaRule(),
                      const SizedBox(height: JotaGrid.gapL),
                      // One quiet line, and only one: the whole instruction.
                      Text(
                        'Press PAIR on Jota to see the code.',
                        textAlign: TextAlign.center,
                        style: t.prose.copyWith(color: c.inkMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer pinned above the safe area, mirroring JotaScreen.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                JotaGrid.margin,
                JotaGrid.gapM,
                JotaGrid.margin,
                JotaGrid.gapM,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.firstRun) ...<Widget>[
                    JotaButton(
                      label: 'Continue',
                      primary: true,
                      upcase: false,
                      height: JotaRows.heightTall,
                      onTap: _complete ? _submit : null,
                    ),
                    const SizedBox(height: JotaGrid.gapS),
                    Semantics(
                      button: true,
                      label: 'Skip for now',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _enterApp,
                        child: Padding(
                          padding: const EdgeInsets.all(JotaGrid.gapM),
                          child: Text(
                            'Skip for now',
                            style: t.label.copyWith(color: c.inkMuted),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    JotaButton(
                      label: 'Pair',
                      primary: true,
                      upcase: false,
                      height: JotaRows.heightTall,
                      onTap: _complete ? _submit : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small, quiet back affordance — the same chevron the status bar used, at
/// the same size, in ink. No label, no rule; just the arrow.
class _BackChevron extends StatelessWidget {
  const _BackChevron();

  @override
  Widget build(BuildContext context) {
    return Icon(LucideIcons.arrowLeft, size: 18, color: context.ink.ink);
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
