// ============================================================================
//  Jota — the Connect page
//
//  A page around the connect choreography (connect_sheet.dart), for the two
//  places that need a whole screen rather than a sheet: the last step of
//  first-run onboarding, which replaces itself with Home when the Jota is
//  paired, and anywhere that pushes it over the app, which pops back.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../l10n/l10n.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';
import '../state/services.dart';
import 'connect_sheet.dart';
import 'home_shell.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, this.onboarding = false});

  /// First run: when done (or skipped) the page becomes Home. Otherwise it
  /// was pushed over the app and simply pops.
  final bool onboarding;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool _moved = false;

  Future<void> _onwards() async {
    if (_moved) return;
    _moved = true;
    if (!widget.onboarding) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    await context.read<Services>().settings.setHasSeenOnboarding(true);
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DeviceController device = context.watch<DeviceController>();
    final bool wantsCode = device.needsPairCode;

    return JotaScreen(
      label: context.l10n.connect,
      upcase: false,
      rule: false,
      onBack: widget.onboarding ? null : () => Navigator.of(context).pop(),
      // Hidden while the keyboard is up for the code.
      footer: wantsCode
          ? null
          : JotaButton(
              label: widget.onboarding
                  ? context.l10n.setUpLater
                  : context.l10n.notNow,
              upcase: false,
              onTap: _onwards,
            ),
      child: SingleChildScrollView(
        // Scrollable, because the keyboard is up on this screen by definition.
        child: Padding(
          padding: const EdgeInsets.only(top: JotaGrid.gapM),
          child: ConnectSheet(onDone: _onwards),
        ),
      ),
    );
  }
}
