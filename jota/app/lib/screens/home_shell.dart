// ============================================================================
//  Jota — home shell
//
//  The app's persistent tab frame: HOME, NOTES, SETTINGS. They live in an
//  IndexedStack so switching swaps the body IN PLACE — no page push — while the
//  floating nav stays put, and each is built lazily so an unvisited tab never
//  starts work behind your back.
//
//  Sync is NOT a destination. A tab dedicated to a mechanism says the mechanism
//  does not work by itself; syncing happens on its own, pull-to-refresh covers
//  the times the OS blocks it, and the device card on Home answers "is it
//  there" — and syncs when tapped. There used to be a chip pinned above the
//  nav on every tab for this; it floated between content and nav like a
//  control that led nowhere, so it went into Home as a card.
//
//  Patterns are reached from Home, and Tags from Settings, for the same reason:
//  both are occasional, and the bottom bar has three slots, not five.
//
//  Opening a note's detail still pushes a full page over the whole shell — a
//  focused view earns the whole screen. That is deliberate; we did not give each
//  tab its own navigation stack, which a package would be needed for.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble/device_scanner.dart';
import '../design/theme.dart';
import '../state/device_controller.dart';
import 'bluetooth_off_screen.dart';
import 'home_screen.dart';
import 'note_list_screen.dart';
import 'settings_screen.dart';
import 'pair_screen.dart';

/// The floating nav: a compact row plus a gap of paper above and below.
const double _navHeight = JotaRows.heightCompact + 2 * JotaGrid.gapM;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late int _index = widget.initialIndex;
  late final Set<int> _visited = <int>{widget.initialIndex};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRadio());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app is the other moment a person expects their notes
    // to just be there. Un-park the automatic path and look again.
    final DeviceController device = context.read<DeviceController>();
    device.resumeAutoSync(foreground: state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      // Radios get switched off while an app is in the background more often
      // than while it is in front of you — usually in the same swipe down that
      // turned on something else.
      _radioNoticeShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkRadio());
    }
  }

  /// True while the notice is up, or while it has been dismissed for this
  /// visit. Without it, "Keep reading offline" would be answered by the same
  /// screen being pushed again on the very next rebuild.
  bool _radioNoticeShown = false;

  /// Bluetooth is the only way a note reaches this phone, so a radio that is
  /// off is worth saying out loud once — and then getting out of the way.
  Future<void> _checkRadio() async {
    if (!mounted || _radioNoticeShown) return;
    final DeviceController device = context.read<DeviceController>();

    // Nothing to warn about before there is a device to talk to: a first-run
    // phone has no notes waiting and no pairing to lose.
    if (!device.hasPairedDevice) return;
    if (device.bluetoothReady) return;
    if (device.adapter == AdapterStatus.unavailable) return; // no radio at all

    _radioNoticeShown = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BluetoothOffScreen(
          unauthorized: device.adapter == AdapterStatus.unauthorized,
        ),
      ),
    );
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  Widget _tab(int i) {
    switch (i) {
      case 1:
        return const NoteListScreen();
      case 2:
        return const SettingsScreen(embedded: true);
      default:
        return HomeScreen(onSeeNotes: () => _select(1));
    }
  }

  /// The engine blocks mid-sync waiting for the digits on the e-paper, and a
  /// sync can now start from anywhere — the device card, pull-to-refresh, or the
  /// device simply coming into range. So the prompt lives HERE, above every
  /// tab, rather than on the one screen that used to own syncing. Without it a
  /// pull-to-refresh that needed a code would wait forever with nothing on
  /// screen to type into.
  Future<void> _maybeAskForCode(DeviceController device) async {
    if (!device.needsPairCode || _pairOpen) return;
    // Only when Home is the screen you are actually looking at.
    //
    // Home stays mounted underneath Connect and keeps rebuilding on every
    // notifyListeners, so without this it pushed its OWN code screen on top of
    // the Connect screen's inline code field — two prompts for one code, and
    // the one on top could not be typed into because the one underneath kept
    // pulling the keyboard focus back. That is the "pair screen is stuck".
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    _pairOpen = true;
    final String? code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const PairScreen()),
    );
    _pairOpen = false;
    device.submitPairCode(code);
  }

  bool _pairOpen = false;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final DeviceController device = context.watch<DeviceController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAskForCode(device);
    });
    // The Scaffold insets the body above the bottom bar and owns the bottom
    // safe area, so no screen has to reserve room for the nav by hand.
    return Scaffold(
      backgroundColor: c.bg,
      body: _TabReveal(
        index: _index,
        child: IndexedStack(
          index: _index,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              _visited.contains(i) ? _tab(i) : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: HomeNavBar(current: _index, onSelect: _select),
    );
  }
}

/// A floating bottom bar — the app's three destinations, detached from the edges
/// so it reads as floating. Three WORDS, in mono caps, all three always legible;
/// the active one is shown by INVERSION, exactly like a selected row.
///
/// It used to draw a Lucide glyph per tab and reveal the word only on the tab
/// you were already on — so the two places you were not going were a house and a
/// cog, and the label was spent naming the screen you could already see. The
/// design lock's `.nav` has no glyphs in it at all: this product says things in
/// words, and an icon set borrowed from another product's drawing style was the
/// loudest foreign object in the app. The one element that carries a soft shadow.
class HomeNavBar extends StatelessWidget {
  const HomeNavBar({super.key, required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            JotaGrid.margin,
            JotaGrid.gapM,
            JotaGrid.margin,
            JotaGrid.gapM,
          ),
          child: Container(
            // A compact-row tab with a gap of paper either side: the same two
            // tokens as everywhere else, so the bar and its pills share a
            // scale with the rest of the app instead of a 60 of their own.
            height: _navHeight,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: JotaRows.borderRadiusOf(_navHeight),
              border: Border.all(color: c.rule, width: JotaGrid.hairline),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: c.ink.withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _NavItem(
                  label: 'Home',
                  active: current == 0,
                  onTap: () => onSelect(0),
                ),
                _NavItem(
                  label: 'Notes',
                  active: current == 1,
                  onTap: () => onSelect(1),
                ),
                _NavItem(
                  label: 'Settings',
                  active: current == 2,
                  onTap: () => onSelect(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    final Color fg = active ? c.onInk : c.inkMuted;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      // Exclude the child's own text from the node. Every tab now draws its
      // word all the time (it used to appear only when active), so without
      // this the rendered `NOTES` merges into the node and the tab stops
      // answering to the name a screen reader — or a test — asks for.
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: JotaMotion.fast,
          curve: JotaMotion.curve,
          height: JotaRows.heightCompact,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active ? c.ink : Colors.transparent,
            borderRadius: JotaRows.borderRadiusOf(JotaRows.heightCompact),
          ),
          // Mono caps, not the sans label style: the design lock draws the nav
          // in the figure face, and it is the same treatment the device's own
          // status strip uses for the screen it is on. The padding no longer
          // grows on the active tab — the pill has to sit around a word that
          // was always there, not around one that just appeared.
          child: Text(
            label.toUpperCase(),
            style: t.navLabel.copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}

/// The body's entrance on a tab switch: a fade from half and a lift of a few
/// pixels, once per switch. The IndexedStack underneath keeps every tab's
/// state; only the reveal is animated, so nothing is rebuilt or rescanned.
class _TabReveal extends StatefulWidget {
  const _TabReveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabReveal> createState() => _TabRevealState();
}

class _TabRevealState extends State<_TabReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: JotaMotion.normal,
    value: 1,
  );

  @override
  void didUpdateWidget(_TabReveal old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation a =
        CurvedAnimation(parent: _c, curve: JotaMotion.curve);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(a),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(a),
        child: widget.child,
      ),
    );
  }
}
