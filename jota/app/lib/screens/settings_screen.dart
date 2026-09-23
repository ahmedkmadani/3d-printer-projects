// ============================================================================
//  Jota — settings
//
//  Drawn against the Jota Design Lock: a serif title, one hairline, and then a
//  FLAT list of label/value rows — sans label on the left, mono muted figure on
//  the right, a hairline under each. Then the "what leaves your phone" card on
//  the field colour, and the one destructive action pinned at the bottom.
//
//  It used to be six labelled sections of stadium rows, buttons and paragraphs.
//  Every explanation was a paragraph you had to read to find the control it
//  belonged to, and each section header re-stated what the row beneath it
//  already said. The design cuts all of it: a setting is a name and its current
//  value, and the value IS the affordance — tapping the row changes it.
//
//  The design shows four rows (Tags, Device, Battery, Unlock). The rest of the
//  app's real settings follow in the same shape below them, because they are
//  behaviours that exist and must stay reachable — the transcription key above
//  all, which is the one thing that makes a note become words.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/settings_store.dart';
import '../design/format.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/lock_controller.dart';
import '../state/services.dart';
import 'onboarding_screen.dart';
import 'splash_screen.dart' show kVersionLabel;
import 'tag_editor_screen.dart';

/// Whether the cloud transcription path is shown at all: the Google key row,
/// the On device / Google Cloud switch, and the "what leaves your phone" card.
///
/// Off since Whisper runs inside the app. Everything hides behind this rather
/// than being deleted, because the cloud path is still the only one that can
/// read Arabic, and the day it comes back it should come back whole. While it
/// is off, nothing leaves the phone, so there is nothing for the card to say.
const bool kShowCloudTranscription = false;

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

  /// Forgetting needs the Jota in range, and says so when it isn't.
  ///
  /// The device has to be told, or it keeps trusting this phone: the app id
  /// minted at install never changes, so a forget that cleared only this side
  /// let the very next connection authenticate silently. Someone unpairing in
  /// order to hand the Jota on would have changed nothing at all.
  ///
  /// Requiring the device absolutely would be a trap of its own — a Jota that
  /// is lost, flat, broken or already given away could never be removed, and
  /// the only way out would be reinstalling. So the block is a warning with a
  /// way past it, and the way past says exactly what it leaves behind.
  Future<void> _forget(DeviceController device) async {
    try {
      await device.forgetDevice();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Jota forgotten')));
      return;
    } on Exception {
      // Out of range, or off. Fall through to the choice below.
    }

    if (!mounted) return;
    final bool? anyway = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Jota isn’t in range', style: context.type.headline),
          content: Text(
            'Bring your Jota close and try again, so it forgets this phone '
            'too.\n\nRemove it anyway and this Jota will still trust this '
            'phone until you erase it on the device — hold both buttons.',
            style: context.type.prose,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: context.type.label),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Remove anyway',
                style: context.type.label.copyWith(color: context.ink.signal),
              ),
            ),
          ],
        );
      },
    );

    if (anyway != true || !mounted) return;
    await device.forgetDevice(force: true);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Removed here. Erase on the Jota to finish.'),
        ),
      );
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
  ///
  /// An empty result removes the key, which is why "Remove key" is no longer a
  /// row of its own: it is the same decision as replacing it, so it belongs in
  /// the same sheet — the convention [promptForTag] already uses.
  Future<void> _editKey(Services s, {required bool hasKey}) async {
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
            Row(
              children: <Widget>[
                if (hasKey) ...<Widget>[
                  Expanded(
                    child: JotaButton(
                      label: 'Remove',
                      danger: true,
                      upcase: false,
                      height: JotaRows.heightCompact,
                      onTap: () => Navigator.of(sheetContext).pop(''),
                    ),
                  ),
                  const SizedBox(width: JotaRows.gap),
                ],
                Expanded(
                  child: JotaButton(
                    label: 'Save',
                    primary: true,
                    upcase: false,
                    height: JotaRows.heightCompact,
                    onTap: () => Navigator.of(sheetContext).pop(
                      controller.text.trim(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null) return; // dismissed

    if (value.isEmpty) {
      await s.settings.setApiKey(null);
      await _load();
      return;
    }

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
    final bool hasKey = (_apiKey ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The design's top strip. The clock on its left belongs to the
            // phone, and Settings has no meta label on its right, so all this
            // holds is the back affordance — and nothing at all in the shell,
            // where there is no route to pop. No rule under it: the screen's
            // one hairline sits under the title, where the design puts it.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                JotaGrid.margin,
                JotaGrid.gapS,
                JotaGrid.margin,
                0,
              ),
              // Embedded in the shell there is no chevron and no label, so the
              // row is 34pt of nothing above the title. Take no room instead.
              child: widget.embedded
                  ? const SizedBox.shrink()
                  : SizedBox(
                      height: JotaGrid.statusHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _BackChevron(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : ListView(
                      // Room under the last row so the scroll ends in
                      // whitespace. Without it the viewport edge lands
                      // mid-row, and a hairline-separated row sliced in half
                      // just above a pinned button reads as a broken layout
                      // rather than as "there is more below".
                      padding: const EdgeInsets.fromLTRB(
                        JotaGrid.margin,
                        0,
                        JotaGrid.margin,
                        JotaGrid.gapL,
                      ),
                      children: <Widget>[
                        Text('Settings', style: t.headline),
                        const SizedBox(height: JotaGrid.gapM),
                        const JotaRule(),

                        // Where transcription happens. On device keeps the
                        // audio on the phone, which problem.md treats as a
                        // functional requirement rather than a feature. The
                        // multilingual `small` model reads Arabic and English;
                        // the cloud path stays hidden unless it is needed.
                        _SettingRow(
                          label: 'Transcribe',
                          value: !kShowCloudTranscription
                              ? 'ON DEVICE'
                              : s.settings.backend == 'device'
                                  ? 'On device →'
                                  : 'Google Cloud →',
                          // A plain fact while the cloud path is hidden: with
                          // no key row a switch to Google would be a switch to
                          // nothing.
                          onTap: !kShowCloudTranscription
                              ? null
                              : () async {
                                  final bool onDevice =
                                      s.settings.backend == 'device';
                                  await s.settings.setBackend(
                                    onDevice ? 'google' : 'device',
                                  );
                                  if (!context.mounted) return;
                                  setState(() {});
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          onDevice
                                              ? 'Using Google Cloud'
                                              : 'On device — the first note '
                                                  'downloads a 466 MB model',
                                        ),
                                      ),
                                    );
                                },
                        ),

                        // The four the design names, in its order.
                        _SettingRow(
                          label: 'Tags',
                          value: '${s.settings.tags.length} →',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const TagEditorScreen(),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                        ),
                        _SettingRow(
                          label: 'Device',
                          value: device.hasPairedDevice
                              ? device.pairedName
                              : 'NOT SET UP',
                        ),
                        _SettingRow(
                          label: 'Battery',
                          // "Unknown" rather than a dash or a zero: this board
                          // may simply have no way to measure it, which is a
                          // different thing from a flat pack.
                          value: device.batteryOnDevice == null
                              ? 'UNKNOWN'
                              : '${device.batteryOnDevice}%',
                        ),
                        _SettingRow(
                          label: 'Unlock with fingerprint',
                          value: lock.enabled ? 'ON' : 'OFF',
                          onTap: () => _setLock(lock, !lock.enabled),
                        ),

                        // Everything below is a real behaviour the design's
                        // four rows do not cover. Same shape, so the list stays
                        // one list rather than growing sections again.
                        if (kShowCloudTranscription)
                          _SettingRow(
                            label: 'Transcription key',
                            // Masked, never shown whole: enough to tell two keys
                            // apart, not enough to use one over someone's
                            // shoulder.
                            value: hasKey
                                ? SettingsStore.maskKey(_apiKey!)
                                : 'NOT SET →',
                            onTap: () => _editKey(s, hasKey: hasKey),
                          ),
                        _SettingRow(
                          label: 'Transcribe automatically',
                          value: s.settings.autoTranscribe ? 'ON' : 'OFF',
                          onTap: () async {
                            await s.settings.setAutoTranscribe(
                              !s.settings.autoTranscribe,
                            );
                            setState(() {});
                          },
                        ),
                        _SettingRow(
                          label: 'Sync in the background',
                          value: s.settings.backgroundSync ? 'ON' : 'OFF',
                          onTap: () async {
                            await device.setBackgroundSync(
                              !s.settings.backgroundSync,
                            );
                            setState(() {});
                          },
                        ),
                        // Kept next to Device because the question the pair
                        // answers is a comparison: which Jota is this, and
                        // which phone owns it.
                        _SettingRow(
                          label: 'This phone',
                          value: _shortAppId(device.appId),
                        ),
                        _SettingRow(
                          label: 'Notes',
                          value: fmtBytes(_archiveBytes),
                        ),
                        _SettingRow(
                          label: 'Playback cache',
                          value: '${fmtBytes(_cacheBytes)} →',
                          onTap: () async {
                            await s.audio.clearCache();
                            await _load();
                          },
                        ),
                        _SettingRow(
                          label: 'Replay onboarding',
                          value: '→',
                          onTap: () async {
                            await s.settings.setHasSeenOnboarding(false);
                            if (!context.mounted) return;
                            await Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                builder: (_) => const OnboardingScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          },
                        ),
                        if (device.hasPairedDevice)
                          _SettingRow(
                            label: 'Forget this Jota',
                            value: '→',
                            onTap: () => _forget(device),
                          ),
                        const _SettingRow(
                          label: 'Version',
                          value: kVersionLabel,
                        ),

                        const SizedBox(height: JotaGrid.gapL),
                        // Story T2, and the reason problem.md calls privacy a
                        // FUNCTIONAL requirement: if you are not sure where a
                        // recording goes, you speak differently, and a thought
                        // you softened while saying it is not the thought.
                        //
                        // So this says the awkward part out loud. The audio
                        // does leave, today, to become text. Anything vaguer
                        // would be the product quietly buying itself room,
                        // which is exactly what would make someone hesitate
                        // before speaking.
                        if (kShowCloudTranscription) ...<Widget>[
                          _LeavesCard(hasKey: hasKey),
                          const SizedBox(height: JotaGrid.gapL),
                        ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                JotaGrid.margin,
                JotaGrid.gapM,
                JotaGrid.margin,
                JotaGrid.gapM,
              ),
              child: JotaButton(
                label: 'Erase device',
                danger: true,
                upcase: false,
                // PLACEHOLDER. The firmware can erase itself — both buttons,
                // held twice — but there is no BLE command for it, so the app
                // cannot ask. Wiring it means a new characteristic on both
                // sides of docs/ble-service.md. Until then this says what it
                // cannot do rather than pretending to do it, because a
                // destructive button that silently does nothing is the worst
                // possible thing to be wrong about.
                onTap: () => _say(
                  context,
                  'Not yet — hold both buttons on the Jota for five seconds',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One setting: its name in sans on the left, its current value in mono on the
/// right, a hairline under it. Flat, not a stadium — a stadium per setting was
/// a wall of pills, and the device's stadium means "one of these is selected",
/// which a list of unrelated settings never is.
///
/// A trailing `→` in the value is the whole affordance for a row that goes
/// somewhere; a row that toggles simply shows ON or OFF and flips on tap.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(child: Text(label, style: t.prose)),
                  const SizedBox(width: JotaGrid.gapM),
                  Text(
                    value,
                    style: t.reading.copyWith(
                      color: c.inkMuted,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const JotaRule(),
          ],
        ),
      ),
    );
  }
}

/// The back affordance, matching the one [JotaStatusBar] draws — this screen
/// builds its own top strip because the design has no rule under it.
class _BackChevron extends StatelessWidget {
  const _BackChevron({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(right: JotaGrid.gapM),
          child: Icon(LucideIcons.arrowLeft, size: 18, color: context.ink.ink),
        ),
      ),
    );
  }
}

/// What actually leaves this phone, in plain words. The one card on the field
/// colour, and the only place on this screen that is not a row.
class _LeavesCard extends StatelessWidget {
  const _LeavesCard({required this.hasKey});

  /// Without a key nothing is transcribed, so nothing leaves at all — and
  /// saying so is more reassuring than a caveat about what would happen.
  final bool hasKey;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    return Container(
      padding: const EdgeInsets.all(JotaGrid.gapL),
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: const BorderRadius.all(
          Radius.circular(JotaCards.radius),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'WHAT LEAVES YOUR PHONE',
            // Mono, like every other label in a card in the design — this is
            // chrome on a figure-shaped surface, not prose.
            style: t.reading.copyWith(
              color: c.inkMuted,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: JotaGrid.gapS),
          Text(
            hasKey
                ? 'Audio goes to Google to become text. Nothing else leaves — '
                    'the sorting runs here, on this phone.'
                : 'Nothing. Without a key nothing is transcribed, so no audio '
                    'is sent anywhere. Your notes are recorded, stored and '
                    'played back entirely on this phone.',
            style: t.prose,
          ),
        ],
      ),
    );
  }
}

/// One-line feedback. Settings has no error region and does not need one.
void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A uuid is 36 characters of noise. The first eight are plenty to tell two
/// phones apart by eye, which is the only thing anyone does with it.
String _shortAppId(String appId) => appId.isEmpty
    ? '—'
    : appId.substring(0, appId.length.clamp(0, 8)).toUpperCase();
