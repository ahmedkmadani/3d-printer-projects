// ============================================================================
//  Jota — home shell
//
//  The app's persistent tab frame. The three destinations live in an IndexedStack
//  so switching tabs swaps the body IN PLACE — no page push — while the floating
//  nav stays put. Tabs are built lazily (only once first visited) so an unopened
//  Sync tab never starts a scan or a pair prompt behind your back. Tags aren't a
//  destination of their own — they're a short list you set once and tweak rarely,
//  so they live under Settings, not in the nav.
//
//  Opening a note's detail still pushes a full page over the whole shell — a
//  focused view earns the whole screen. That is deliberate; we did not give each
//  tab its own navigation stack, which a package would be needed for.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../state/device_controller.dart';
import 'note_list_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import 'widgets/device_chip.dart';

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
        return const SyncScreen(embedded: true);
      case 2:
        return const SettingsScreen(embedded: true);
      default:
        return const NoteListScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    // The Scaffold insets the body above the bottom bar and owns the bottom
    // safe area, so no screen has to reserve room for the nav by hand.
    return Scaffold(
      backgroundColor: c.bg,
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            _visited.contains(i) ? _tab(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Above the nav, under every tab: the answer to "is it there" without
          // having to open Sync and ask.
          DeviceChip(onTap: () => _select(1)),
          HomeNavBar(current: _index, onSelect: _select),
        ],
      ),
    );
  }
}

/// A floating bottom bar — the app's three destinations, detached from the edges
/// so it reads as floating. The active tab is shown by INVERSION, exactly like a
/// selected row: an ink pill with the icon and label knocked out. The rest are
/// quiet muted icons. The one element in the app that carries a soft shadow.
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
            height: 60,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: const BorderRadius.all(Radius.circular(30)),
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
                  icon: LucideIcons.notebook,
                  label: 'Notes',
                  active: current == 0,
                  onTap: () => onSelect(0),
                ),
                _NavItem(
                  icon: LucideIcons.refreshCw,
                  label: 'Sync',
                  active: current == 1,
                  onTap: () => onSelect(1),
                ),
                _NavItem(
                  icon: LucideIcons.settings,
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
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: JotaMotion.fast,
          curve: JotaMotion.curve,
          padding: EdgeInsets.symmetric(
            horizontal: active ? 16 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: active ? c.ink : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 20, color: fg),
              // The active tab earns its label; the rest stay icon-only.
              if (active) ...<Widget>[
                const SizedBox(width: JotaGrid.gapS),
                Text(label, style: t.label.copyWith(color: fg, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
