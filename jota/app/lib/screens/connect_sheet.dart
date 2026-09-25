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

import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../util_flowlog.dart';
import '../ble/jota_protocol.dart';
import '../design/device_mark.dart';
import '../design/theme.dart';
import '../l10n/l10n.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';

/// True while a connect sheet is on screen. Rapid taps on the device card
/// used to stack sheets: the top one closed on success and revealed a stale
/// twin underneath — a page that flashed and disappeared. One sheet, ever.
bool _connectSheetOpen = false;

/// The connect choreography as a bottom sheet over whatever is on screen.
/// Resolves when the sheet closes, however it closed. Single-flight: while
/// one is open, further calls do nothing.
Future<void> showConnectSheet(BuildContext context) {
  if (_connectSheetOpen) return Future<void>.value();
  _connectSheetOpen = true;
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
  ).whenComplete(() => _connectSheetOpen = false);
}

class ConnectSheet extends StatefulWidget {
  const ConnectSheet({
    super.key,
    required this.onDone,
    this.fillHeight = false,
  });

  /// True when the sheet IS the page (the connect screen): the title anchors
  /// at the top and the device block centres in the height that remains. As
  /// a bottom sheet the compact top-to-bottom flow stays.
  final bool fillHeight;

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

  /// A re-sync the user asked for that the device slept through. The tap is
  /// remembered: when the Jota next advertises, the sync fires by itself, so
  /// "tap Sync, press the button" finishes the job instead of looping
  /// through wake → tap → asleep → wake. One automatic retry; a second
  /// failure shows the ASLEEP card as before.
  bool _syncOnReturn = false;

  /// How many times a held re-sync has auto-fired and failed. Capped, or a
  /// device that advertises but will not hold a connection loops forever
  /// between _observe refiring and _fail re-arming — the exact loop the
  /// held-sync was meant to end.
  int _heldRetries = 0;

  /// The last device drawn. When a sync succeeds the Jota goes quiet and
  /// `found` empties while the done card is still on screen; without a cache
  /// the build called found.first on an empty list and threw to a white
  /// screen every frame.
  JotaAdvertisement? _lastShown;
  static const int _maxHeldRetries = 2;

  /// True when the success belongs to a re-sync of the already-paired Jota.
  /// Pairing hands over to Home; a re-sync settles back to the quiet SYNCED
  /// card and the sheet stays until it is swiped away — closing itself a
  /// second after opening read as a glitch, not a confirmation.
  bool _settleAfterDone = false;
  bool _finished = false;

  /// Bumped to shake the code row once.
  int _shake = 0;

  /// Of several Jotas in range, the one drawn. Null means the nearest.
  String? _chosenId;

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

  void _tap(DeviceController device, JotaAdvertisement ad,
      {bool held = false}) {
    if (_tappedId != null || _doneId != null) return;
    final bool resync =
        device.hasPairedDevice && device.pairedId == ad.remoteId;
    if (!held) _heldRetries = 0; // a fresh user tap starts the count over
    setState(() {
      _tappedId = ad.remoteId;
      _asleep.remove(ad.remoteId);
      _codeSent = false;
      _settleAfterDone = resync;
    });
    debugPrint(
        'jota/flow  SHEET tap resync=\$resync held=\$held retries=\$_heldRetries');
    if (resync) {
      _syncOnReturn = true;
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
    flow('SHEET succeed');
    if (_doneId != null) return;
    _syncOnReturn = false;
    _heldRetries = 0;
    setState(() {
      _doneId = id;
      _tappedId = null;
    });
    _codeFocus.unfocus();
    // The check draws for ~350 ms, then the card holds for 600 ms so the
    // moment reads before the screen moves on.
    // Check draws, holds a beat, then the flow finishes: a first pairing
    // hands over to Home, a re-sync from the card closes the sheet. It used
    // to 'settle' open on a re-sync, but the Jota sleeps the instant a sync
    // ends, so the sheet fell straight back to 'wake it' and the user tapped
    // Sync again and again — a loop made of successes.
    Timer(const Duration(milliseconds: 950), () {
      if (!mounted || _finished) return;
      _finished = true;
      widget.onDone();
    });
  }

  void _fail(DeviceController device, JotaAdvertisement? ad) {
    debugPrint(
        'jota/flow  SHEET fail tapped=\$_tappedId codeSent=\$_codeSent held=\$_syncOnReturn adNull=\${ad == null}');
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
    if (_settleAfterDone && _syncOnReturn) {
      // The paired Jota slept through the attempt. Fall back to the wake
      // state and hold the intention; _observe re-fires the sync when the
      // device comes back.
      setState(() {
        _tappedId = null;
        _code.clear();
        _codeSent = false;
      });
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

    if (id == null && _syncOnReturn && _doneId == null && !syncing) {
      if (_heldRetries >= _maxHeldRetries) {
        // Tried enough. Stop, or the sheet flips between 'wake it' and a
        // failing sync without end.
        flow('SHEET held-sync gives up after \$_heldRetries');
        _syncOnReturn = false;
        final String? pid = device.pairedId;
        if (pid != null) setState(() => _asleep.add(pid));
      } else {
        for (final JotaAdvertisement a in found) {
          if (device.hasPairedDevice && device.pairedId == a.remoteId) {
            _heldRetries++;
            flow('SHEET held-sync refire #\$_heldRetries');
            _syncOnReturn = false;
            _tap(device, a, held: true);
            break;
          }
        }
      }
    }

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

    if (found.isNotEmpty) _lastShown = _shown(found);
    final JotaAdvertisement? shown =
        found.isNotEmpty ? _shown(found) : _lastShown;
    final bool searching = found.isEmpty && _doneId == null;
    // A paired Jota is not being CONNECTED, it is being woken: first-run
    // pairing copy on an owned device read like switching devices. The
    // paired sheet says wake / press a button / Sync instead.
    final bool paired = device.hasPairedDevice;

    final Widget title = Text(
      paired ? context.l10n.wakeYourJota : context.l10n.connectYourJota,
      style: t.headline,
    );
    // Searching and found swap in place: the rings breathe until a Jota
    // is heard, then the cards rise where the rings were.
    final Widget body = AnimatedSize(
      duration: JotaMotion.normal,
      curve: JotaMotion.curve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: JotaMotion.normal,
        switchInCurve: JotaMotion.curve,
        switchOutCurve: JotaMotion.curve,
        child: (searching || shown == null)
            ? const _Searching(key: ValueKey<String>('searching'))
            : _Found(
                key: const ValueKey<String>('found'),
                ad: shown,
                others: <JotaAdvertisement>[
                  for (final JotaAdvertisement a in found)
                    if (a.remoteId != shown.remoteId) a,
                ],
                state: _stateOf(device, shown),
                pairedDevice:
                    device.hasPairedDevice && device.pairedId == shown.remoteId,
                connecting: _tappedId == shown.remoteId && _doneId == null,
                done: _doneId == shown.remoteId,
                onConnect: (_tappedId == null && _doneId == null)
                    ? () => _tap(device, shown)
                    : null,
                onSwitch: (String id) => setState(() => _chosenId = id),
                code: wantsCode && _tappedId == shown.remoteId
                    ? _CodeRow(
                        controller: _code,
                        focus: _codeFocus,
                        shake: _shake,
                        onComplete: () => _submit(device),
                      )
                    : null,
              ),
      ),
    );
    final Widget hint = searching
        ? Padding(
            padding: const EdgeInsets.only(top: JotaGrid.gapL),
            child: Text(
              paired
                  ? context.l10n.pressButtonOnIt
                  : context.l10n.switchOnYourJota,
              textAlign: TextAlign.center,
              style: t.prose.copyWith(color: c.inkMuted),
            ),
          )
        : const SizedBox.shrink();

    if (widget.fillHeight) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          title,
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[body, hint],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        title,
        const SizedBox(height: JotaGrid.gapL),
        body,
        hint,
      ],
    );
  }

  /// The nearest Jota by signal, unless the user picked another.
  JotaAdvertisement _shown(List<JotaAdvertisement> found) {
    for (final JotaAdvertisement a in found) {
      if (a.remoteId == _chosenId) return a;
    }
    JotaAdvertisement best = found.first;
    for (final JotaAdvertisement a in found) {
      if (a.rssi > best.rssi) best = a;
    }
    return best;
  }

  String _stateOf(DeviceController device, JotaAdvertisement ad) {
    final AppLocalizations l = context.l10n;
    if (_doneId == ad.remoteId) return l.statePaired;
    if (_tappedId == ad.remoteId) return l.stateConnecting;
    if (_asleep.contains(ad.remoteId)) return l.stateAsleep;
    if (device.hasPairedDevice && device.pairedId == ad.remoteId) {
      return l.statePaired;
    }
    return l.stateNearby;
  }
}

// ---- searching -------------------------------------------------------------

class _Searching extends StatefulWidget {
  const _Searching({super.key});

  @override
  State<_Searching> createState() => _SearchingState();
}

/// The Jota, drawn in muted ink and breathing slowly (0.35 → 0.55 opacity,
/// 2.4 s), with the rings expanding from behind it. There is never a frame
/// that shows only circles: the device is the picture from the first one.
class _SearchingState extends State<_Searching>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation breath =
        CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          const _Radar(size: 260),
          FadeTransition(
            opacity: Tween<double>(begin: 0.6, end: 1).animate(breath),
            child: const _Backdrop(size: 240),
          ),
          FadeTransition(
            opacity: Tween<double>(begin: 0.45, end: 0.7).animate(breath),
            child: const JotaDeviceMark(),
          ),
        ],
      ),
    );
  }
}

/// A dot with rings breathing out of it: the phone listening. Three rings a
/// third of a period apart, each growing from the dot to the edge and fading
/// as it goes, on the product's own curve. [quiet] is the small version that
/// keeps listening under the cards for a second Jota.
class _Radar extends StatefulWidget {
  const _Radar({required this.size});

  final double size;

  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
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
          ink: pulseTint(c),
          rings: 2,
          dot: 100,
          strength: 0.18,
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
    // A wide, blurred stroke: a pulse of light, not a target.
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    // Rings rise from behind the drawn device (radius ~ its half height)
    // and fade as they reach the edge. No dot: the device is the centre.
    final double r0 = dot;
    for (int k = 0; k < rings; k++) {
      final double p = (t + k / rings) % 1.0;
      final double e = JotaMotion.curve.transform(p);
      final double r = r0 + e * (rMax - r0);
      stroke.color = ink.withValues(alpha: (1 - p) * strength);
      canvas.drawCircle(centre, r, stroke);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.ink != ink;
}

/// The pulse's colour: the theme's signal, desaturated and lightened to a
/// faded orange, so the rings are warm without shouting.
Color pulseTint(JotaColors c) {
  final HSLColor h = HSLColor.fromColor(c.signal);
  return h
      .withSaturation((h.saturation * 0.55).clamp(0.0, 1.0))
      .withLightness((h.lightness + 0.18).clamp(0.0, 0.85))
      .toColor();
}

/// One soft circle behind the device — ink at a few percent with a hint of
/// the pulse's orange mixed in, no border — the small colour an earbud
/// case sits on when it pops up.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final bool dark = c.brightnessIsDark;
    final Color tint = Color.alphaBlend(
      pulseTint(c).withValues(alpha: 0.05),
      c.ink.withValues(alpha: dark ? 0.10 : 0.06),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
    );
  }
}

// ---- found -----------------------------------------------------------------

/// The Jota, found: the device itself rises into view the way an earbud
/// case does on a phone — scale 0.85 → 1 with a fade and one overshoot —
/// with its id, its charge, the one state word and a Connect button
/// under it. Other Jotas in range are small ids underneath, to switch.
class _Found extends StatelessWidget {
  const _Found({
    this.pairedDevice = false,
    super.key,
    required this.ad,
    required this.others,
    required this.state,
    required this.connecting,
    required this.done,
    required this.onConnect,
    required this.onSwitch,
    this.code,
  });

  final bool pairedDevice;
  final JotaAdvertisement ad;
  final List<JotaAdvertisement> others;
  final String state;
  final bool connecting;
  final bool done;
  final VoidCallback? onConnect;
  final ValueChanged<String> onSwitch;
  final Widget? code;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    Widget mark = done
        ? TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: JotaMotion.curve,
            builder: (BuildContext context, double v, _) =>
                JotaDeviceMark(done: true, checkProgress: v),
          )
        : const JotaDeviceMark();
    if (connecting) mark = _Pulse(child: mark);

    return Column(
      key: ValueKey<String>('found-${ad.remoteId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: JotaMotion.normal,
          curve: Curves.easeOutBack,
          child: SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[const _Backdrop(size: 240), mark],
            ),
          ),
          builder: (BuildContext context, double v, Widget? child) => Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
          ),
        ),
        const SizedBox(height: JotaGrid.gapM),
        Text(
          ad.shortName,
          textAlign: TextAlign.center,
          style: t.reading.copyWith(color: c.ink),
        ),
        const SizedBox(height: JotaGrid.gapS),
        Text(
          <String>[if (ad.battery != null) '${ad.battery}%', state]
              .join('  ·  '),
          textAlign: TextAlign.center,
          style: t.meta.copyWith(color: c.inkMuted),
        ),
        if (others.isNotEmpty) ...<Widget>[
          const SizedBox(height: JotaGrid.gapM),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: JotaGrid.gapL,
            children: <Widget>[
              for (final JotaAdvertisement o in others)
                JotaPressable(
                  onTap: () => onSwitch(o.remoteId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      o.shortName,
                      style: t.meta.copyWith(color: c.inkMuted),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (code != null) code!,
        if (!done) ...<Widget>[
          const SizedBox(height: JotaGrid.gapL),
          JotaButton(
            label: connecting
                ? context.l10n.connectingLabel
                : pairedDevice
                    ? context.l10n.sync
                    : context.l10n.connect,
            primary: true,
            upcase: false,
            onTap: onConnect,
          ),
        ],
      ],
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: JotaMotion.normal,
      curve: JotaMotion.curve,
      builder: (BuildContext context, double v, Widget? child) => Opacity(
        opacity: v,
        child:
            Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
      ),
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
