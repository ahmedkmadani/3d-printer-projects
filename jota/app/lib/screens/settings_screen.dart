// ============================================================================
//  Jota — settings
//
//  Your device, background sync, storage, and a couple of "about" actions. No
//  account, no server key, no telemetry — transcription is handled elsewhere —
//  so this is the whole configuration surface of the product.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/format.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/lock_controller.dart';
import '../state/services.dart';
import 'splash_screen.dart';
import 'tag_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  /// True when shown as a tab inside the home shell — the back chevron is
  /// dropped (there is no route to pop back to).
  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  int _archiveBytes = 0;
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final Services s = context.read<Services>();
    final int archive = await s.audio.archiveBytes();
    final int cache = await s.audio.cacheBytes();
    if (!mounted) return;
    setState(() {
      _archiveBytes = archive;
      _cacheBytes = cache;
      _loading = false;
    });
  }

  /// Toggle the app lock. Turning it on prompts Face ID / passcode first (so the
  /// user can't lock themselves out); if the phone has neither, we say so and
  /// leave it off. A cancelled prompt just leaves it as it was — no message.
  Future<void> _setLock(LockController lock, bool value) async {
    final LockSetupResult result = await lock.setEnabled(value);
    if (!mounted) return;
    if (result == LockSetupResult.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set up Face ID or a passcode in your phone settings first.',
          ),
        ),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Services s = context.read<Services>();
    final DeviceController device = context.watch<DeviceController>();
    final LockController lock = context.watch<LockController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return JotaScreen(
      label: 'Settings',
      upcase: false,
      onBack: widget.embedded ? null : () => Navigator.of(context).pop(),
      child: _loading
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(top: JotaGrid.gapL),
              children: <Widget>[
                const _SectionLabel('Device'),
                JotaKeyValue(
                  name: 'Your Jota',
                  value: device.hasPairedDevice
                      ? (s.settings.deviceName ?? 'Connected')
                      : 'Not set up',
                ),
                if (device.hasPairedDevice) ...<Widget>[
                  const SizedBox(height: JotaRows.gap),
                  JotaButton(
                    label: 'Forget this Jota',
                    danger: true,
                    upcase: false,
                    height: JotaRows.heightCompact,
                    onTap: () async {
                      await device.forgetDevice();
                      setState(() {});
                    },
                  ),
                ],

                const SizedBox(height: JotaGrid.gapXL),
                const _SectionLabel('Tags'),
                Text(
                  'The words you sort notes by — here and on your Jota.',
                  style: t.prose.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: JotaGrid.gapM),
                JotaButton(
                  label: 'Edit tags',
                  upcase: false,
                  height: JotaRows.heightCompact,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TagEditorScreen(),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),

                const SizedBox(height: JotaGrid.gapXL),
                const _SectionLabel('Background'),
                _ToggleRow(
                  label: 'Sync in the background',
                  value: s.settings.backgroundSync,
                  onChanged: (bool v) async {
                    await device.setBackgroundSync(v);
                    setState(() {});
                  },
                ),

                const SizedBox(height: JotaGrid.gapXL),
                const _SectionLabel('Privacy'),
                _ToggleRow(
                  label: 'Lock the app',
                  value: lock.enabled,
                  onChanged: (bool v) => _setLock(lock, v),
                ),
                const SizedBox(height: JotaGrid.gapS),
                Text(
                  'Ask for Face ID or your passcode each time you open Jota. '
                  'Your notes stay on this phone — this keeps them yours.',
                  style: t.prose.copyWith(color: c.inkMuted),
                ),

                const SizedBox(height: JotaGrid.gapXL),
                const _SectionLabel('Storage'),
                JotaKeyValue(name: 'Notes', value: fmtBytes(_archiveBytes)),
                JotaKeyValue(
                  name: 'Playback cache',
                  value: fmtBytes(_cacheBytes),
                ),
                const SizedBox(height: JotaRows.gap),
                JotaButton(
                  label: 'Clear cache',
                  upcase: false,
                  height: JotaRows.heightCompact,
                  onTap: () async {
                    await s.audio.clearCache();
                    await _load();
                  },
                ),

                const SizedBox(height: JotaGrid.gapXL),
                const _SectionLabel('About'),
                JotaButton(
                  label: 'Replay onboarding',
                  upcase: false,
                  height: JotaRows.heightCompact,
                  onTap: () async {
                    await s.settings.setHasSeenOnboarding(false);
                    if (!context.mounted) return;
                    await Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const SplashScreen(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                ),

                const SizedBox(height: JotaGrid.gapXL),
                Center(
                  child: Text('JOTA', style: t.wordmark.copyWith(fontSize: 28)),
                ),
                const SizedBox(height: JotaGrid.gapS),
                Center(
                  child: Text(
                    kVersionLabel,
                    style: t.reading.copyWith(color: c.inkMuted),
                  ),
                ),
                const SizedBox(height: JotaGrid.gapXL),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: JotaGrid.gapM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            text,
            style: context.type.label.copyWith(color: context.ink.inkMuted),
          ),
          const SizedBox(height: JotaGrid.gapS),
          const JotaRule(),
        ],
      ),
    );
  }
}

/// A toggle that obeys the shape rules: a stadium that inverts when on, rather
/// than a Material Switch with its own colour and its own radius.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return JotaRow(
      label: label,
      selected: value,
      leading: const SizedBox.shrink(),
      trailing: Text(value ? 'On' : 'Off'),
      onTap: () => onChanged(!value),
    );
  }
}
