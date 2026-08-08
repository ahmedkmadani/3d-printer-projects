// ============================================================================
//  Jota — settings
//
//  Three things: the API key, the device, and what the app is allowed to do in
//  the background. There is no account, no sync service and no telemetry, so
//  this is the whole configuration surface of the product.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ble/background_sync.dart';
import '../design/format.dart';
import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _maskedKey;
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
    final String? key = await s.settings.apiKey();
    final int archive = await s.audio.archiveBytes();
    final int cache = await s.audio.cacheBytes();
    if (!mounted) return;
    setState(() {
      _maskedKey = (key == null || key.isEmpty) ? null : _mask(key);
      _archiveBytes = archive;
      _cacheBytes = cache;
      _loading = false;
    });
  }

  static String _mask(String key) {
    if (key.length <= 8) return '••••';
    return '${key.substring(0, 3)}…${key.substring(key.length - 4)}';
  }

  Future<void> _editKey() async {
    final Services s = context.read<Services>();
    final TextEditingController controller = TextEditingController();

    final String? value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.ink.bg,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: JotaGrid.margin,
            right: JotaGrid.margin,
            top: JotaGrid.gapL,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + JotaGrid.gapL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('OPENAI API KEY', style: context.type.label),
              const SizedBox(height: JotaGrid.gapM),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                style: context.type.reading,
                decoration: const InputDecoration(hintText: 'sk-…'),
              ),
              const SizedBox(height: JotaGrid.gapM),
              Text(
                'Stored in the iOS Keychain / Android EncryptedSharedPreferences. '
                'It is sent only to OpenAI, only when transcribing, and never '
                'reaches the device — Jota has no network at all.',
                style: context.type.prose.copyWith(
                  color: context.ink.inkMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: JotaGrid.gapM),
              Row(
                children: <Widget>[
                  Expanded(
                    child: JotaButton(
                      label: 'Remove',
                      danger: true,
                      height: JotaRows.heightCompact,
                      onTap: () => Navigator.of(sheetContext).pop(''),
                    ),
                  ),
                  const SizedBox(width: JotaRows.gap),
                  Expanded(
                    child: JotaButton(
                      label: 'Save',
                      primary: true,
                      height: JotaRows.heightCompact,
                      onTap: () => Navigator.of(sheetContext)
                          .pop(controller.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    if (value == null) return;
    await s.settings.setApiKey(value.isEmpty ? null : value);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final Services s = context.read<Services>();
    final DeviceController device = context.watch<DeviceController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    return JotaScreen(
      label: 'SETTINGS',
      onBack: () => Navigator.of(context).pop(),
      child: _loading
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.only(top: JotaGrid.gapL),
              children: <Widget>[
                const _SectionLabel('TRANSCRIPTION'),
                JotaRow(
                  label: _maskedKey ?? 'ADD API KEY',
                  trailing: Icon(
                    _maskedKey == null ? Icons.add : Icons.edit_outlined,
                  ),
                  onTap: _editKey,
                ),
                const SizedBox(height: JotaRows.gap),
                _ToggleRow(
                  label: 'AUTO-TRANSCRIBE',
                  value: s.settings.autoTranscribe,
                  onChanged: (bool v) async {
                    await s.settings.setAutoTranscribe(v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: JotaGrid.gapS),
                Text(
                  'Audio is decoded to WAV on the phone and sent to OpenAI '
                  'Whisper. Nothing else leaves the device.',
                  style: t.prose.copyWith(color: c.inkMuted, fontSize: 13),
                ),

                const SizedBox(height: JotaGrid.gapXL),
                const _SectionLabel('DEVICE'),
                JotaKeyValue(
                  name: 'Paired',
                  value: device.hasPairedDevice
                      ? (s.settings.deviceName ?? 'JOTA')
                      : 'NONE',
                ),
                if (device.hasPairedDevice)
                  JotaKeyValue(
                    name: 'ID',
                    value: device.pairedId ?? '',
                  ),
                const SizedBox(height: JotaRows.gap),
                if (device.hasPairedDevice)
                  JotaButton(
                    label: 'Forget device',
                    danger: true,
                    height: JotaRows.heightCompact,
                    onTap: () async {
                      await device.forgetDevice();
                      setState(() {});
                    },
                  ),

                const SizedBox(height: JotaGrid.gapXL),
                const _SectionLabel('BACKGROUND SYNC'),
                _ToggleRow(
                  label: 'BACKGROUND SYNC',
                  value: s.settings.backgroundSync,
                  onChanged: (bool v) async {
                    await device.setBackgroundSync(v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: JotaGrid.gapS),
                // The honest description, from the same source the README
                // quotes. No "syncs every 10 minutes" anywhere.
                Text(
                  BackgroundSyncController.explain(device.backgroundMode),
                  style: t.prose.copyWith(color: c.inkMuted, fontSize: 13),
                ),

                const SizedBox(height: JotaGrid.gapXL),
                const _SectionLabel('STORAGE'),
                JotaKeyValue(name: 'Archive', value: fmtBytes(_archiveBytes)),
                JotaKeyValue(
                  name: 'Decoded cache',
                  value: fmtBytes(_cacheBytes),
                ),
                const SizedBox(height: JotaRows.gap),
                JotaButton(
                  label: 'Clear decoded cache',
                  height: JotaRows.heightCompact,
                  onTap: () async {
                    await s.audio.clearCache();
                    await _load();
                  },
                ),
                const SizedBox(height: JotaGrid.gapS),
                Text(
                  'The archive is the audio exactly as Jota sent it and is the '
                  'only copy. The cache is decoded WAV and rebuilds itself.',
                  style: t.prose.copyWith(color: c.inkMuted, fontSize: 13),
                ),

                const SizedBox(height: JotaGrid.gapXL),
                Center(
                  child: Text('JOTA', style: t.wordmark.copyWith(fontSize: 28)),
                ),
                const SizedBox(height: JotaGrid.gapS),
                Center(
                  child: Text(
                    'V0.1.0',
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
      trailing: Text(value ? 'ON' : 'OFF'),
      onTap: () => onChanged(!value),
    );
  }
}
