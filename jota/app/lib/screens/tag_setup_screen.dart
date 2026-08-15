// ============================================================================
//  Jota — first-run tag setup
//
//  Straight after pairing: a friendly, skippable step to pick a few tags so the
//  app is useful from the first note. Tags aren't decoration — they're what you
//  sort by here and what you browse by on the Jota itself, so it's worth a beat
//  up front. Rather than an empty text field on a blank page, this offers a
//  handful of suggestions to tap plus an "add your own", so the screen is full
//  and the choice is one tap. The selection is the same app-first list as the
//  Tags tab (saved on the way out, synced to the device).
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../ble/jota_protocol.dart';
import '../data/settings_store.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/services.dart';
import 'home_shell.dart';
import 'tag_editor_screen.dart';

class TagSetupScreen extends StatefulWidget {
  const TagSetupScreen({super.key});

  @override
  State<TagSetupScreen> createState() => _TagSetupScreenState();
}

class _TagSetupScreenState extends State<TagSetupScreen> {
  /// A calm set of everyday buckets for a crowded head. Uppercase because that
  /// is how a tag reads on the device's mono panel, and how `promptForTag`
  /// stores a custom one — so a picked chip and a typed tag agree.
  /// The three the product ships with come first, so the chips a person sees
  /// already selected are the ones at the front of the row. The rest are there
  /// for anyone who wants more than the starting set.
  static const List<String> _suggested = <String>[
    ...kDefaultTags,
    'TODO',
    'BUY',
    'PEOPLE',
    'MONEY',
    'HEALTH',
  ];

  /// The tags the user has chosen, in the order they picked them. Seeded from
  /// whatever is already saved, so returning here shows the current selection.
  final List<String> _selected = <String>[];

  @override
  void initState() {
    super.initState();
    _selected.addAll(context.read<Services>().settings.tags);
  }

  bool get _atMax => _selected.length >= kMaxTags;

  /// Chosen tags that aren't one of the suggestions — shown as their own
  /// selected chips after the suggestion row.
  List<String> get _custom =>
      _selected.where((String tag) => !_suggested.contains(tag)).toList();

  void _toggle(String tag) {
    if (_selected.contains(tag)) {
      setState(() => _selected.remove(tag));
    } else if (!_atMax) {
      setState(() => _selected.add(tag));
    }
  }

  Future<void> _addOwn() async {
    if (_atMax) return;
    final String? value = await promptForTag(context);
    if (value == null || value.isEmpty || !mounted) return;
    if (_selected.contains(value)) return;
    setState(() => _selected.add(value));
  }

  Future<void> _done() async {
    // Persist once, on the way out — the same shared path the Tags tab uses,
    // which also pushes the list to a connected device.
    await saveTags(context, _selected);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    final List<Widget> chips = <Widget>[
      for (final String tag in _suggested)
        _TagChip(
          label: tag,
          selected: _selected.contains(tag),
          // At the ceiling, unselected suggestions dim rather than vanish — the
          // limit is shown, not enforced by silently swallowing a tap.
          enabled: _selected.contains(tag) || !_atMax,
          onTap: () => _toggle(tag),
        ),
      for (final String tag in _custom)
        _TagChip(
          label: tag,
          selected: true,
          // Custom tags aren't in the suggestion grid, so they'd otherwise look
          // like any other chosen chip — a trailing × says "tap to remove".
          removable: true,
          onTap: () => _toggle(tag),
        ),
      if (!_atMax)
        _TagChip(
          label: 'Add your own',
          selected: false,
          icon: LucideIcons.plus,
          semanticLabel: 'Add your own tag',
          onTap: _addOwn,
        ),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: JotaGrid.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: JotaGrid.gapXL),
              Text(
                'Add a few tags',
                style: t.headline.copyWith(fontSize: 36),
              ),
              const SizedBox(height: JotaGrid.gapM),
              Text(
                'A calm way to sort what’s on your mind. The same tags show '
                'on your Jota — change them whenever you like.',
                style: t.prose.copyWith(color: c.inkMuted, height: 1.6),
              ),
              const SizedBox(height: JotaGrid.gapL),
              // Centred in the space between the intro and the button, so a
              // short list of tags sits in the middle of the screen rather than
              // stranding a wall of empty paper below it. The cluster itself is
              // centre-aligned so its ragged rows read as one balanced group.
              Expanded(
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: JotaRows.gap,
                    // The chips carry their own vertical hit-slop, so no extra
                    // run spacing — that would double the gap between rows.
                    runSpacing: 0,
                    children: chips,
                  ),
                ),
              ),
              if (_atMax)
                Padding(
                  padding: const EdgeInsets.only(top: JotaGrid.gapM),
                  child: Text(
                    '$kMaxTags is the most your Jota holds.',
                    style: t.reading.copyWith(color: c.inkMuted, fontSize: 12),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(
                  top: JotaGrid.gapL,
                  bottom: JotaGrid.gapM,
                ),
                child: JotaButton(
                  label: _selected.isEmpty ? 'Skip for now' : 'Done',
                  primary: true,
                  upcase: false,
                  height: JotaRows.heightTall,
                  onTap: _done,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tap-to-pick tag pill. A chosen chip inverts into the onboarding art's clay
/// — a solid terracotta fill with a knocked-out label — so it reads as *selected*
/// by the same inversion the whole app uses, just warmed from ink to the
/// illustration's accent. That keeps the affordance unmistakable (and the label
/// legible on the fill) while still letting the first-run choice feel like the
/// warm picture it sits under. Sized to its content and laid out in a [Wrap]
/// rather than stretched to a full-width row.
///
/// This is the one place the accent fills a shape, a deliberate exception to the
/// theme's "signal in two places only" rule, scoped to this screen alone.
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.icon,
    this.removable = false,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final IconData? icon;

  /// Show a trailing × on a selected chip — used for custom tags so it's clear
  /// a tap takes them off again.
  final bool removable;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;

    final Color fg = selected
        ? c.onInk
        : enabled
            ? c.ink
            : c.inkMuted;
    // INK, not the accent. Selection is shown by inversion everywhere else in
    // this product — on the panel and in the app — and the accent means live
    // or dangerous and nothing else (docs/brand.md). A row of terracotta pills
    // read as eight warnings on the one screen that is meant to feel like
    // picking favourites.
    final Color border = selected ? c.ink : c.rule;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        // A little vertical slop so the tap target clears the comfortable
        // minimum without the pill itself growing past its 36pt stadium.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: AnimatedContainer(
            duration: JotaMotion.fast,
            curve: JotaMotion.curve,
            height: JotaRows.heightCompact,
            decoration: BoxDecoration(
              color: selected ? c.ink : Colors.transparent,
              borderRadius: JotaRows.borderRadiusOf(JotaRows.heightCompact),
              border: Border.all(color: border, width: JotaGrid.hairline),
            ),
            padding: const EdgeInsets.symmetric(horizontal: JotaGrid.gapL),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: JotaGrid.gapS),
                ],
                Text(
                  label,
                  style: t.label.copyWith(
                    color: fg,
                    fontSize: 15,
                    letterSpacing: 0.4,
                  ),
                ),
                if (removable && selected) ...<Widget>[
                  const SizedBox(width: JotaGrid.gapS),
                  Icon(LucideIcons.x, size: 14, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
