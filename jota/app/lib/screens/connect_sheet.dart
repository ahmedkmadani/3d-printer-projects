// ============================================================================
//  Jota — connecting, as a choreography
//
//  Pairing used to be a flat list under a "Looking for your Jota…" line, with
//  a red "Timed out after 25s" when the device was asleep. It now moves the
//  way pairing earbuds does: rings breathe out of a dot while the phone
//  listens; a Jota that appears rises into a stadium card; the tapped card
//  pulses while the handshake runs; the six boxes slide up under it and pop
//  as digits land, shake once on a wrong code; and on success the card fills
//  with ink and draws a check before the sheet hands over.
//
//  One widget, used two ways: as the body of the first-run Connect page, and
//  as a bottom sheet from Home's device card — so it is the same experience
//  wherever a Jota is connected. Everything drawn is ours: circles, stadiums,
//  a stroke. No spinner.
// ============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ble/jota_protocol.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';

/// The connect choreography as a bottom sheet over whatever is on screen.
/// Resolves when the sheet closes, however it closed.
Future<void> showConnectSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.ink.bg,
    builder: (BuildContext sheetContext) {
      return Padding(
        // The keyboard rises for the code; the sheet rides on top of it.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                JotaGrid.margin,
                JotaGrid.gapL,
                JotaGrid.margin,
                JotaGrid.gapL,
              ),
              child: ConnectSheet(
                onDone: () {
                  if (Navigator.of(sheetContext).canPop()) {
                    Navigator.of(sheetContext).pop();
                  }
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ConnectSheet extends StatefulWidget {
  const ConnectSheet({super.key, required this.onDone});

  /// Called once the success animation has played out. The host decides
  /// where to go: onboarding replaces itself with Home, the sheet closes.
  final VoidCallback onDone;

  @override
  State<ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<ConnectSheet> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  /// The Jota the user tapped, while its handshake runs.
  String? _tappedId;

  /// Jotas that were tapped and did not answer: seen, but not awake enough
  /// to talk. They keep their card, marked ASLEEP, until tapped again.
  final Set<String> _asleep = <String>{};

  /// True once a code has been sent in the current attempt, so a failure
  /// afterwards is read as a wrong code rather than a device that did not
  /// answer at all.
  bool _codeSent = false;
  int _retries = 0;

  /// The success state: the card fills and draws its check, then [onDone].
  String? _doneId;
  bool _finished = false;

  /// Bumped to shake the code row once.
  int _shake = 0;

  bool _wasPairing = false;
  bool _wasSyncing = false;

  String get _digits => _code.text;
  bool get _complete => _digits.length == kPairCodeLength;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // No timeout: someone on this sheet is holding the device and waiting
      // for it to appear.
      context.read<DeviceController>().startScan(timeout: null);
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _tap(DeviceController device, JotaAdvertisement ad) {
    if (_tappedId != null || _doneId != null) return;
    setState(() {
      _tappedId = ad.remoteId;
      _asleep.remove(ad.remoteId);
      _codeSent = false;
    });
    if (device.hasPairedDevice && device.pairedId == ad.remoteId) {
      unawaited(device.syncNow(ad: ad));
    } else {
      unawaited(device.pairWith(ad));
    }
  }

  void _submit(DeviceController device) {
    if (!_complete) return;
    _codeSent = true;
    device.submitPairCode(_digits);
  }

  void _succeed(String id) {
    if (_doneId != null) return;
    setState(() {
      _doneId = id;
      _tappedId = null;
    });
    _codeFocus.unfocus();
    // The check draws for ~350 ms, then the card holds for 600 ms so the
    // moment reads before the screen moves on.
    Timer(const Duration(milliseconds: 950), () {
      if (!mounted || _finished) return;
      _finished = true;
      widget.onDone();
    });
  }

  void _fail(DeviceController device, JotaAdvertisement? ad) {
    final String? id = _tappedId;
    if (id == null) return;
    if (_codeSent && ad != null && _retries < 3) {
      // A wrong code: shake, clear, and knock again so the boxes come back
      // ready. The Jota keeps the same code up for two minutes.
      _retries++;
      setState(() {
        _shake++;
        _code.clear();
        _codeSent = false;
      });
      unawaited(device.pairWith(ad));
      return;
    }
    setState(() {
      _asleep.add(id);
      _tappedId = null;
      _code.clear();
      _codeSent = false;
    });
  }

  /// Watches the controller's transitions from the last frame to this one.
  /// The controller has no "pairing succeeded" event; the answer is in
  /// which flags fell as the handshake ended.
  void _observe(DeviceController device, List<JotaAdvertisement> found) {
    final bool pairing = device.isPairing;
    final bool syncing = device.isSyncing;
    final String? id = _tappedId;

    if (id != null) {
      JotaAdvertisement? ad;
      for (final JotaAdvertisement a in found) {
        if (a.remoteId == id) ad = a;
      }
      final bool paired = device.hasPairedDevice && device.pairedId == id;
      if (_wasPairing && !pairing) {
        if (paired) {
          _succeed(id);
        } else {
          _fail(device, ad);
        }
      } else if (_wasSyncing && !syncing && paired && !pairing) {
        final bool ok = device.lastError == null;
        if (ok) {
          _succeed(id);
        } else {
          _fail(device, ad);
        }
      }
    }
    _wasPairing = pairing;
    _wasSyncing = syncing;
  }

  @override
  Widget build(BuildContext context) {
    final DeviceController device = context.watch<DeviceController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final List<JotaAdvertisement> found = device.inRange;
    final bool wantsCode = device.needsPairCode && _tappedId != null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _observe(device, found);
      final ModalRoute<Object?>? route = ModalRoute.of(context);
      final bool visible = route == null || route.isCurrent;
      if (wantsCode && visible && !_codeFocus.hasFocus) {
        _codeFocus.requestFocus();
      }
    });

    final bool searching = found.isEmpty && _doneId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Connect your Jota', style: t.headline),
        const SizedBox(height: JotaGrid.gapL),
        // Searching and found swap in place: the rings breathe until a Jota
        // is heard, then the cards rise where the rings were.
        AnimatedSize(
          duration: JotaMotion.normal,
          curve: JotaMotion.curve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: JotaMotion.normal,
            switchInCurve: JotaMotion.curve,
            switchOutCurve: JotaMotion.curve,
            child: searching
                ? const _Searching(key: ValueKey<String>('searching'))
                : Column(
                    key: const ValueKey<String>('found'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (int i = 0; i < found.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(height: JotaRows.gap),
                        _Rise(
                          index: i,
                          child: _JotaCard(
                            ad: found[i],
                            state: _stateOf(device, found[i]),
                            connecting: _tappedId == found[i].remoteId &&
                                _doneId == null,
                            done: _doneId == found[i].remoteId,
                            onTap: (_tappedId == null && _doneId == null)
                                ? () => _tap(device, found[i])
                                : null,
                          ),
                        ),
                        if (wantsCode && _tappedId == found[i].remoteId)
                          _CodeRow(
                            controller: _code,
                            focus: _codeFocus,
                            shake: _shake,
                            onComplete: () => _submit(device),
                          ),
                      ],
                      if (_doneId == null) ...<Widget>[
                        const SizedBox(height: JotaGrid.gapL),
                        const Center(
                          child: _Radar(size: 48, quiet: true),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        if (searching) ...<Widget>[
          const SizedBox(height: JotaGrid.gapL),
          Text(
            'Switch on your Jota',
            textAlign: TextAlign.center,
            style: t.prose.copyWith(color: c.inkMuted),
          ),
        ],
      ],
    );
  }

  String _stateOf(DeviceController device, JotaAdvertisement ad) {
    if (_doneId == ad.remoteId) return 'PAIRED';
    if (_tappedId == ad.remoteId) return 'CONNECTING';
    if (_asleep.contains(ad.remoteId)) return 'ASLEEP';
    if (device.hasPairedDevice && device.pairedId == ad.remoteId) {
      return 'PAIRED';
    }
    return 'NEARBY';
  }
}

// ---- searching -------------------------------------------------------------

class _Searching extends StatelessWidget {
  const _Searching({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(child: _Radar(size: 220)),
    );
  }
}

/// A dot with rings breathing out of it: the phone listening. Three rings a
/// third of a period apart, each growing from the dot to the edge and fading
/// as it goes, on the product's own curve. [quiet] is the small version that
/// keeps listening under the cards for a second Jota.
class _Radar extends StatefulWidget {
  const _Radar({required this.size, this.quiet = false});

  final double size;
  final bool quiet;

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _RadarPainter(
          t: _c.value,
          ink: c.ink,
          rings: widget.quiet ? 2 : 3,
          dot: widget.quiet ? 3 : 6,
          strength: widget.quiet ? 0.35 : 0.7,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.t,
    required this.ink,
    required this.rings,
    required this.dot,
    required this.strength,
  });

  final double t;
  final Color ink;
  final int rings;
  final double dot;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double rMax = size.shortestSide / 2 - 1;
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = JotaGrid.hairline;
    for (int k = 0; k < rings; k++) {
      final double p = (t + k / rings) % 1.0;
      final double e = JotaMotion.curve.transform(p);
      final double r = dot + e * (rMax - dot);
      stroke.color = ink.withValues(alpha: (1 - p) * strength);
      canvas.drawCircle(centre, r, stroke);
    }
    canvas.drawCircle(centre, dot, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.ink != ink;
}

// ---- found -----------------------------------------------------------------

/// A card that rises into place: fades in and lifts a few pixels, later cards
/// a beat after the one above them.
class _Rise extends StatelessWidget {
  const _Rise({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: JotaMotion.normal + Duration(milliseconds: 90 * index),
      curve: JotaMotion.curve,
      child: child,
      builder: (BuildContext context, double v, Widget? child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 14),
          child: child,
        ),
      ),
    );
  }
}

/// One Jota, as a stadium: its id on the left, the charge and the one state
/// word on the right. Pulses while connecting; fills with ink and draws a
/// check when it is done.
class _JotaCard extends StatelessWidget {
  const _JotaCard({
    required this.ad,
    required this.state,
    required this.connecting,
    required this.done,
    this.onTap,
  });

  final JotaAdvertisement ad;
  final String state;
  final bool connecting;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    final Color fg = done ? c.onInk : c.ink;
    final Color muted = done ? c.onInk : c.inkMuted;
    final double h = scaledHeight(context, JotaRows.heightTall);

    Widget card = AnimatedContainer(
      duration: JotaMotion.normal,
      curve: JotaMotion.curve,
      height: h,
      padding: const EdgeInsets.symmetric(horizontal: JotaGrid.gapL),
      decoration: BoxDecoration(
        color: done ? c.ink : Colors.transparent,
        borderRadius: JotaRows.borderRadiusOf(h),
        border: Border.all(color: c.ink, width: JotaGrid.hairline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              ad.shortName,
              style: t.reading.copyWith(color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: JotaGrid.gapM),
          if (done)
            _Check(color: c.onInk)
          else ...<Widget>[
            if (ad.battery != null) ...<Widget>[
              Text('${ad.battery}%', style: t.reading.copyWith(color: fg)),
              const SizedBox(width: JotaGrid.gapM),
            ],
            Text(state, style: t.meta.copyWith(color: muted)),
          ],
        ],
      ),
    );

    if (connecting) card = _Pulse(child: card);

    return Semantics(
      button: onTap != null,
      label: '${ad.shortName} $state',
      child: JotaPressable(onTap: onTap, child: card),
    );
  }
}

/// A gentle breath while the handshake runs: 1 → 1.02 → 1, once a second.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.02).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// A check drawn as one stroke, over ~350 ms, in the knocked-out colour.
class _Check extends StatelessWidget {
  const _Check({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: JotaMotion.curve,
      builder: (BuildContext context, double v, _) => CustomPaint(
        size: const Size(22, 22),
        painter: _CheckPainter(progress: v, color: color),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    final Path path = Path()
      ..moveTo(w * 0.18, h * 0.55)
      ..lineTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.84, h * 0.26);
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), p);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

// ---- the code --------------------------------------------------------------

/// The six boxes, sliding up under the tapped card with the keyboard. Each
/// box pops as its digit lands; the row shakes once when the code was wrong.
class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.controller,
    required this.focus,
    required this.shake,
    required this.onComplete,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final int shake;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final String digits = controller.text;
    return _Rise(
      index: 0,
      child: Padding(
        padding: const EdgeInsets.only(top: JotaGrid.gapL),
        child: _Shake(
          trigger: shake,
          child: GestureDetector(
            onTap: focus.requestFocus,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                _PopBoxes(digits: digits, length: kPairCodeLength),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(kPairCodeLength),
                      ],
                      onChanged: (String v) {
                        if (v.length == kPairCodeLength) onComplete();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The code boxes with a pop: a box that just received its digit starts a
/// touch large and settles, so typing is felt as well as seen.
class _PopBoxes extends StatelessWidget {
  const _PopBoxes({required this.digits, required this.length});

  final String digits;
  final int length;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    final int cursor = digits.length.clamp(0, length - 1);
    const double h = JotaRows.height;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 7),
          TweenAnimationBuilder<double>(
            key: ValueKey<String>('box-$i-${i < digits.length}'),
            tween: Tween<double>(begin: i < digits.length ? 1.25 : 1, end: 1),
            duration: JotaMotion.fast,
            curve: JotaMotion.curve,
            builder: (BuildContext context, double s, Widget? child) =>
                Transform.scale(scale: s, child: child),
            child: Container(
              width: 32,
              height: h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.field,
                borderRadius: JotaRows.borderRadiusOf(h),
                border: Border.all(
                  color:
                      (i == cursor && digits.length < length) ? c.ink : c.rule,
                  width: (i == cursor && digits.length < length)
                      ? 1.6
                      : JotaGrid.hairline,
                ),
              ),
              child: Text(
                i < digits.length ? digits[i] : '',
                style: t.figure.copyWith(fontSize: 20),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shakes its child once per bump of [trigger]: ±6 px, three cycles, dying
/// out over 400 ms. The one motion in the app that means "no".
class _Shake extends StatefulWidget {
  const _Shake({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void didUpdateWidget(_Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = _c.value;
        final double dx = math.sin(t * math.pi * 6) * 6 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
