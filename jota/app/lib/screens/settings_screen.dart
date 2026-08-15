// ============================================================================
//  Jota — settings
//
//  Your device, transcription, background sync, storage, and a couple of
//  "about" actions. No account and no telemetry — but transcription DOES need
//  a Google Cloud key, and this is where it goes.
//
//  That section was missing entirely until now, which made the product's one
//  promise unreachable: notes arrived, played back, and sat untranscribed
//  forever while the error message pointed at a Settings field that did not
//  exist. The preview swapped in a transcriber that always succeeds, so nobody
//  saw it.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_store.dart';
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
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final Services s = context.read<Services>();
    final int archive = await s.audio.archiveBytes();
    final int cache = await s.audio.cacheBytes();
    final String? key = await s.settings.apiKey();
    if (!mounted) return;
    setState(() {
      _archiveBytes = archive;
      _cacheBytes = cache;
      _apiKey = key;
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

  /// The key sheet. Obscured while typing, trimmed on the way in — a pasted
  /// key almost always arrives with a trailing newline, and the API rejects it
  /// with a 401 that reads like a wrong key rather than a stray character.
  Future<void> _editKey(Services s) async {
    final TextEditingController controller = TextEditingController();
    final String? value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.ink.bg,
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: JotaGrid.margin,
          right: JotaGrid.margin,
          top: JotaGrid.gapL,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + JotaGrid.gapL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Google Cloud API key', style: context.type.label),
            const SizedBox(height: JotaGrid.gapS),
            Text(
              'A Speech-to-Text key from Google Cloud. Stored in your phone\'s '
              'secure keychain, and sent only to Google.',
              style: context.type.prose.copyWith(color: context.ink.inkMuted),
            ),
            const SizedBox(height: JotaGrid.gapM),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(hintText: 'AIza…'),
              onSubmitted: (String v) =>
                  Navigator.of(sheetContext).pop(v.trim()),
            ),
            const SizedBox(height: JotaGrid.gapM),
            JotaButton(
              label: 'Save',
              primary: true,
              upcase: false,
              height: JotaRows.heightCompact,
              onTap: () => Navigator.of(sheetContext).pop(
                controller.text.trim(),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;

    await s.settings.setApiKey(value);
    await _load();
    // A key is only useful if something uses it: pick up whatever has been
    // sitting untranscribed while there was none.
    unawaited(s.transcription.drain());
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
                  value:
                      device.hasPairedDevice ? device.pairedName : 'Not set up',
                ),
                const SizedBox(height: JotaRows.gap),
                // The pair of ids, together, because the question they answer is
                // a comparison: which device is this, and which phone owns it.
                // The Jota prints its own four characters on its PAIR screen and
                // at boot, so the two can be held side by side.
                JotaKeyValue(
                  name: 'This phone',
                  value: _shortAppId(device.appId),
                ),
                JotaKeyValue(
                  name: 'Battery',
                  // "Unknown" rather than a dash or a zero: this board may
                  // simply have no way to measure it, which is a different
                  // thing from a flat pack.
                  value: device.batteryOnDevice == null
                      ? 'Unknown'
                      : '${device.batteryOnDevice}%',
                ),
                if (device.hasPairedDevice) ...<Widget>[
                  const SizedBox(height: JotaGrid.gapM),
                  Text(
                    'Your Jota remembers this phone, so it reconnects without a '
                    'code. Another phone can take it over only by entering the '
                    'six digits shown on the device.',
                    style: t.prose.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(height: JotaGrid.gapM),
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
                const _SectionLabel('Transcription'),
                Text(
                  'Jota has no internet of its own. Your phone sends the audio '
                  'to OpenAI and keeps the text here — so it needs your key.',
                  style: t.prose.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: JotaGrid.gapM),
                JotaKeyValue(
                  name: 'API key',
                  // Masked, never shown whole: enough to tell two keys apart,
                  // not enough to use one over someone's shoulder.
                  value: (_apiKey ?? '').isEmpty
                      ? 'Not set'
                      : SettingsStore.maskKey(_apiKey!),
                ),
                const SizedBox(height: JotaRows.gap),
                JotaButton(
                  label: (_apiKey ?? '').isEmpty ? 'Add a key' : 'Replace key',
                  upcase: false,
                  height: JotaRows.heightCompact,
                  onTap: () => _editKey(s),
                ),
                if ((_apiKey ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: JotaRows.gap),
                  JotaButton(
                    label: 'Remove key',
                    danger: true,
                    upcase: false,
                    height: JotaRows.heightCompact,
                    onTap: () async {
                      await s.settings.setApiKey(null);
                      await _load();
                    },
                  ),
                ],
                const SizedBox(height: JotaGrid.gapM),
                _ToggleRow(
                  label: 'Transcribe automatically',
                  value: s.settings.autoTranscribe,
                  onChanged: (bool v) async {
                    await s.settings.setAutoTranscribe(v);
                    setState(() {});
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

/// A uuid is 36 characters of noise. The first eight are plenty to tell two
/// phones apart by eye, which is the only thing anyone does with it.
String _shortAppId(String appId) => appId.isEmpty
    ? '—'
    : appId.substring(0, appId.length.clamp(0, 8)).toUpperCase();
