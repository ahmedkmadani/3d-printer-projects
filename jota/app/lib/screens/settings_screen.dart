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
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ble/device_diag.dart';
import '../ble/sync_service.dart';
import '../data/note.dart';
import '../data/settings_store.dart';
import '../export/backup.dart';
import '../export/corrections.dart';
import '../design/format.dart';
import '../l10n/l10n.dart';
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
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.jotaForgotten,
              textAlign: TextAlign.center,
            ),
          ),
        );
      return;
    } on Exception {
      // Out of range, or off. Fall through to the choice below.
    }

    if (!mounted) return;
    final bool? anyway = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title:
              Text(context.l10n.jotaNotInRange, style: context.type.headline),
          content: Text(
            context.l10n.forgetBody,
            style: context.type.prose,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.cancel, style: context.type.label),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                context.l10n.removeAnyway,
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
        SnackBar(
          content: Text(
            context.l10n.jotaForgotten,
            textAlign: TextAlign.center,
          ),
        ),
      );
  }

  /// The language hint, on a sheet shaped like the note's tag sheet: title,
  /// one line, the choices as stadiums with the current one inverted.
  /// Light, dark or the phone's choice. Takes effect as it is tapped: the
  /// app's theme listens to Services.themeMode.
  Future<void> _pickAppearance(Services s) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.ink.bg,
      builder: (BuildContext sheetContext) {
        final JotaType t = sheetContext.type;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              JotaGrid.margin,
              JotaGrid.gapL,
              JotaGrid.margin,
              JotaGrid.gapL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(sheetContext.l10n.appearance, style: t.sheetTitle),
                const SizedBox(height: JotaGrid.gapL),
                // Full rows, not pills: three tiny stadiums under a serif
                // title made the sheet read as an afterthought, and the
                // targets were small for the one setting people toggle at
                // night.
                for (final String v in const <String>[
                  'system',
                  'light',
                  'dark',
                ]) ...<Widget>[
                  JotaRow(
                    label: _appearanceLabel(sheetContext.l10n, v),
                    selected: s.settings.appearance == v,
                    onTap: () => Navigator.of(sheetContext).pop(v),
                  ),
                  const SizedBox(height: JotaRows.gap),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    await s.settings.setAppearance(picked);
    s.themeMode.value = Services.themeModeOf(picked);
    if (mounted) setState(() {});
  }

  Future<void> _pickLanguage(Services s) async {
    final String? picked = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: context.ink.bg,
      builder: (BuildContext sheetContext) {
        final JotaType t = sheetContext.type;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              JotaGrid.margin,
              JotaGrid.gapL,
              JotaGrid.margin,
              JotaGrid.gapL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(sheetContext.l10n.languageSheetTitle, style: t.sheetTitle),
                const SizedBox(height: JotaGrid.gapL),
                for (final String? code in _languages) ...<Widget>[
                  JotaRow(
                    label: _languageLabel(sheetContext.l10n, code),
                    selected: s.settings.language == code,
                    // The sheet returns the code; null is a real choice
                    // (auto), so "dismissed" is told apart by a sentinel
                    // below.
                    onTap: () => Navigator.of(sheetContext).pop(code ?? _auto),
                  ),
                  const SizedBox(height: JotaRows.gap),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return; // dismissed
    await s.settings.setLanguage(picked == _auto ? null : picked);
    if (mounted) setState(() {});
  }

  static const String _auto = 'auto';

  /// The app's own language: system, English or Arabic. Same sheet shape as
  /// Appearance. Takes effect as it is tapped — MaterialApp listens to
  /// Services.appLocale — so the sheet you picked from re-renders in the
  /// language you picked.
  Future<void> _pickAppLanguage(Services s) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.ink.bg,
      builder: (BuildContext sheetContext) {
        final JotaType t = sheetContext.type;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              JotaGrid.margin,
              JotaGrid.gapL,
              JotaGrid.margin,
              JotaGrid.gapL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(sheetContext.l10n.appLanguage, style: t.sheetTitle),
                const SizedBox(height: JotaGrid.gapL),
                for (final String? code in const <String?>[null, 'en', 'ar'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: JotaRows.gap),
                    child: JotaRow(
                      label: _appLanguageLabel(sheetContext.l10n, code),
                      selected: s.settings.appLocale == code,
                      onTap: () =>
                          Navigator.of(sheetContext).pop(code ?? _system),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    final String? code = picked == _system ? null : picked;
    await s.settings.setAppLocale(code);
    s.appLocale.value = Services.localeOf(code);
    if (mounted) setState(() {});
  }

  static const String _system = 'system';

  /// The device's own account of itself, in the same key/value voice as the
  /// note's DETAILS card.
  Future<void> _showFirmware(DeviceDiag d) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.ink.bg,
      builder: (BuildContext sheetContext) {
        final JotaType t = sheetContext.type;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              JotaGrid.margin,
              JotaGrid.gapL,
              JotaGrid.margin,
              JotaGrid.gapL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(sheetContext.l10n.firmwareTitle, style: t.sheetTitle),
                const SizedBox(height: JotaGrid.gapL),
                _DiagRow(sheetContext.l10n.fwVersion, d.fw.toUpperCase()),
                if (d.built.isNotEmpty)
                  _DiagRow(sheetContext.l10n.fwBuilt, d.built),
                if (d.reset.isNotEmpty)
                  _DiagRow(sheetContext.l10n.fwLastReset, _resetWord(d.reset)),
                _DiagRow(sheetContext.l10n.fwBoots, '${d.boots}'),
                _DiagRow(sheetContext.l10n.fwCrashes, '${d.crashes}'),
                _DiagRow(sheetContext.l10n.fwNotesRecorded, '${d.notes}'),
                _DiagRow(sheetContext.l10n.fwSyncs, '${d.syncs}'),
                _DiagRow(sheetContext.l10n.fwUptime, _fmtUptime(d.upSeconds)),
                _DiagRow(sheetContext.l10n.fwFreeMemory, fmtBytes(d.freeHeap)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Erase the Jota from here: everything on it, and the bond both ways.
  Future<void> _eraseDevice(DeviceController device) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.eraseThisJota, style: context.type.headline),
          content: Text(
            context.l10n.eraseBody,
            style: context.type.prose,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.cancel, style: context.type.label),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                context.l10n.erase,
                style: context.type.label.copyWith(color: context.ink.signal),
              ),
            ),
          ],
        );
      },
    );
    if (yes != true || !mounted) return;

    // Confirm first, wait second: the Jota sleeps two minutes after a
    // wake, so demanding it be awake BEFORE the dialog made erasing a
    // race the person always lost. Now the app waits and the one
    // instruction is on screen while it does.
    _say(context, context.l10n.waitingForJota);
    try {
      final bool seen = await device.eraseWhenSeen();
      if (!mounted) return;
      if (!seen) {
        _say(context, context.l10n.noJotaNearby);
        return;
      }
      setState(() {});
      _say(context, context.l10n.jotaErased);
    } on EraseUnsupported {
      if (!mounted) return;
      _say(
        context,
        context.l10n.holdBothButtons,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      _say(
        context,
        e is SyncException ? e.message : context.l10n.couldNotErase,
      );
    }
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
      jotaToast(context, context.l10n.setPhoneLockFirst);
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
                        // Title, then the first caption at gapL: no rule
                        // under the title (Notes has none) and no second
                        // gap. The first row draws the only hairline.
                        Text(context.l10n.settingsTitle, style: t.headline),

                        // Four groups, each under a card caption, so the
                        // seventeen rows read as four questions instead of
                        // one long wall.
                        _Caption(
                          context.l10n.captionTranscription,
                          first: true,
                        ),
                        // Where transcription happens. On device keeps the
                        // audio on the phone, which problem.md treats as a
                        // functional requirement rather than a feature. The
                        // multilingual `small` model reads Arabic and English;
                        // the cloud path stays hidden unless it is needed.
                        _SettingRow(
                          label: context.l10n.rowTranscribe,
                          value: !kShowCloudTranscription
                              ? context.l10n.onDevice
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
                                          textAlign: TextAlign.center,
                                          onDevice
                                              ? 'Using Google Cloud'
                                              : 'On device — the first note '
                                                  'downloads a 466 MB model',
                                        ),
                                      ),
                                    );
                                },
                        ),
                        // Which language the notes are in. Auto lets
                        // whisper.cpp guess from the first thirty seconds,
                        // which on a short mixed clip is a coin toss; a hint
                        // settles it. A sheet, not a tap that cycles: three
                        // states behind one tap is a thing nobody discovers.
                        _SettingRow(
                          label: context.l10n.spokenLanguage,
                          value: _languageLabel(
                            context.l10n,
                            s.settings.language,
                          ),
                          onTap: () => _pickLanguage(s),
                        ),
                        _SettingRow(
                          label: context.l10n.transcribeAutomatically,
                          value: s.settings.autoTranscribe
                              ? context.l10n.valueOn
                              : context.l10n.valueOff,
                          onTap: () async {
                            await s.settings.setAutoTranscribe(
                              !s.settings.autoTranscribe,
                            );
                            setState(() {});
                          },
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
                                : 'Not set →',
                            onTap: () => _editKey(s, hasKey: hasKey),
                          ),
                        _Caption(context.l10n.captionDevice),
                        _SettingRow(
                          label: context.l10n.rowDevice,
                          value: device.hasPairedDevice
                              ? device.pairedName
                              : 'Not set up',
                        ),
                        _SettingRow(
                          label: context.l10n.rowBattery,
                          // "Unknown" rather than a dash or a zero: this board
                          // may simply have no way to measure it, which is a
                          // different thing from a flat pack.
                          value: device.batteryOnDevice == null
                              ? context.l10n.valueUnknown
                              : '${device.batteryOnDevice}%',
                        ),
                        // What the device reported about itself on the last
                        // connection. Unknown until it has connected once on
                        // firmware that can say (the `diag` characteristic).
                        _SettingRow(
                          label: context.l10n.rowFirmware,
                          value: device.deviceDiag == null
                              ? context.l10n.valueUnknown
                              : device.deviceDiag!.fw.toUpperCase(),
                          onTap: device.deviceDiag == null
                              ? null
                              : () => _showFirmware(device.deviceDiag!),
                        ),
                        // The four the design names, in its order.
                        _SettingRow(
                          label: context.l10n.rowTags,
                          value:
                              '${s.settings.tags.length} ${jotaArrow(context)}',
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
                          label: context.l10n.rowSyncBackground,
                          value: s.settings.backgroundSync
                              ? context.l10n.valueOn
                              : context.l10n.valueOff,
                          onTap: () async {
                            await device.setBackgroundSync(
                              !s.settings.backgroundSync,
                            );
                            setState(() {});
                          },
                        ),
                        if (device.hasPairedDevice)
                          _SettingRow(
                            label: context.l10n.forgetThisJota,
                            value: jotaArrow(context),
                            onTap: () => _forget(device),
                          ),
                        // Erase, as a row with the rest of the device's
                        // settings rather than a button pinned under every
                        // group. Real now: the `erase` characteristic wipes
                        // notes, tags and the bond on the device, which then
                        // shows its PAIR screen for the next owner.
                        if (device.hasPairedDevice)
                          _SettingRow(
                            label: context.l10n.eraseDevice,
                            value: jotaArrow(context),
                            danger: true,
                            onTap: () => _eraseDevice(device),
                          ),
                        _Caption(context.l10n.captionYourData),
                        _SettingRow(
                          label: context.l10n.rowStorage,
                          value: fmtBytes(_archiveBytes),
                        ),
                        // The archive is on this phone and nowhere else. One
                        // file of every note's words, to the share sheet, is
                        // the whole backup story for now.
                        _SettingRow(
                          label: context.l10n.shareAllNotes,
                          value: jotaArrow(context),
                          onTap: () => _shareBackup(s),
                        ),
                        // Every note corrected by hand, as audio plus both
                        // texts: the training data for a Whisper that knows
                        // this voice. See lib/export/corrections.dart.
                        _SettingRow(
                          label: context.l10n.exportCorrections,
                          value: jotaArrow(context),
                          onTap: () => _shareCorrections(context, s),
                        ),
                        _SettingRow(
                          label: context.l10n.playbackCache,
                          value:
                              '${fmtBytes(_cacheBytes)} ${jotaArrow(context)}',
                          onTap: () async {
                            await s.audio.clearCache();
                            await _load();
                          },
                        ),
                        _SettingRow(
                          label: context.l10n.unlockWithFingerprint,
                          value: lock.enabled
                              ? context.l10n.valueOn
                              : context.l10n.valueOff,
                          onTap: () => _setLock(lock, !lock.enabled),
                        ),
                        _Caption(context.l10n.captionAbout),
                        _SettingRow(
                          label: context.l10n.appearance,
                          value: _appearanceLabel(
                            context.l10n,
                            s.settings.appearance,
                          ),
                          onTap: () => _pickAppearance(s),
                        ),
                        // The app's own language, apart from the spoken one:
                        // a person can read the app in Arabic and record
                        // English notes, or the other way round.
                        _SettingRow(
                          label: context.l10n.appLanguage,
                          value: _appLanguageLabel(
                            context.l10n,
                            s.settings.appLocale,
                          ),
                          onTap: () => _pickAppLanguage(s),
                        ),
                        // Kept next to Device because the question the pair
                        // answers is a comparison: which Jota is this, and
                        // which phone owns it.
                        _SettingRow(
                          label: context.l10n.rowThisPhone,
                          value: _shortAppId(device.appId),
                        ),
                        _SettingRow(
                          label: context.l10n.rowVersion,
                          value: kVersionLabel,
                        ),
                        _SettingRow(
                          label: context.l10n.replayOnboarding,
                          value: jotaArrow(context),
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
/// The language hint's three states, cycled in this order. Null is Whisper's
/// own detection.
const List<String?> _languages = <String?>[null, 'ar', 'en'];

String _appearanceLabel(AppLocalizations l, String v) {
  switch (v) {
    case 'light':
      return l.appearanceLight;
    case 'dark':
      return l.appearanceDark;
    default:
      return l.appearanceSystem;
  }
}

String _languageLabel(AppLocalizations l, String? code) {
  switch (code) {
    case 'ar':
      return l.languageArabic;
    case 'en':
      return l.languageEnglish;
    default:
      return l.languageAuto;
  }
}

/// English and Arabic are shown in their own names — the one row where a
/// label must be readable to someone lost in the wrong language.
String _appLanguageLabel(AppLocalizations l, String? code) {
  switch (code) {
    case 'ar':
      return l.appLanguageArabic;
    case 'en':
      return l.appLanguageEnglish;
    default:
      return l.appLanguageSystem;
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    this.onTap,
    this.danger = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  /// The signal colour on the label: the one destructive row.
  final bool danger;

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
                  Expanded(
                    child: Text(
                      label,
                      style: t.prose.copyWith(color: danger ? c.signal : null),
                    ),
                  ),
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
            style: t.cardLabel.copyWith(color: c.inkMuted),
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
/// Every note's words as one JSON file, handed to the system share sheet.
/// Written to the cache directory: the share target copies what it wants,
/// and a stale backup in the cache is the OS's to clean.
Future<void> _shareBackup(Services s) async {
  final List<Note> notes = await s.notes.all();
  final String json = notesBackupJson(notes);
  final Directory dir = await getTemporaryDirectory();
  final DateTime now = DateTime.now();
  final String stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final File f = File('${dir.path}/jota-notes-$stamp.json');
  await f.writeAsString(json, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(f.path, mimeType: 'application/json')],
      subject: 'Jota notes $stamp',
    ),
  );
}

/// The corrections zip to the share sheet, or a word when there is nothing
/// corrected yet.
Future<void> _shareCorrections(BuildContext context, Services s) async {
  final List<Note> notes = await s.notes.all();
  final Uint8List? zip = await buildCorrectionsZip(
    notes,
    s.audio,
    language: s.settings.language,
  );
  if (zip == null) {
    if (context.mounted) {
      _say(context, context.l10n.noCorrectionsYet);
    }
    return;
  }
  final Directory dir = await getTemporaryDirectory();
  final DateTime now = DateTime.now();
  final String stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final File f = File('${dir.path}/jota-corrections-$stamp.zip');
  await f.writeAsBytes(zip, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(f.path, mimeType: 'application/zip')],
      subject: 'Jota corrections $stamp',
    ),
  );
}

/// `sleep` -> `Sleep`; the wire words are lowercase identifiers.
String _resetWord(String w) =>
    w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);

/// Uptime reads as time, not a seconds figure: `4m 38s`, `2h 05m`.
String _fmtUptime(int secs) {
  if (secs < 60) return '${secs}s';
  final int m = secs ~/ 60;
  if (m < 60) return '${m}m ${(secs % 60).toString().padLeft(2, '0')}s';
  return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
}

/// One fact in the Firmware sheet: the same quiet-name / mono-value pairing
/// as the note's DETAILS card, so the two read as kin.
class _DiagRow extends StatelessWidget {
  const _DiagRow(this.name, this.value);

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: JotaGrid.gapS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(
            child: Text(name, style: t.prose.copyWith(color: c.inkMuted)),
          ),
          const SizedBox(width: JotaGrid.gapM),
          Text(value, style: t.reading.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}

void _say(BuildContext context, String message) => jotaToast(context, message);

/// A uuid is 36 characters of noise. The first eight are plenty to tell two
/// phones apart by eye, which is the only thing anyone does with it.
String _shortAppId(String appId) => appId.isEmpty
    ? '—'
    : appId.substring(0, appId.length.clamp(0, 8)).toUpperCase();

/// A group's caption: the card label, gapL under the title for the first,
/// gapXL between groups, and the same gapM down to the rows every time.
class _Caption extends StatelessWidget {
  const _Caption(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? JotaGrid.gapL : JotaGrid.gapXL,
        bottom: JotaGrid.gapM,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.type.cardLabel.copyWith(color: context.ink.inkMuted),
      ),
    );
  }
}
