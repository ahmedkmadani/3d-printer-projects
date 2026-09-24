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
      } else if (mounted) {
        // Launched as the app's first screen (no Jota paired yet): skipping
        // goes to the shell, the same place pairing lands.
        unawaited(
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const HomeShell()),
          ),
        );
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
      // No word in the status slot: the serif title below already names the
      // screen, and 'Connect' in the corner was saying it twice.
      label: '',
      upcase: false,
      rule: false,
      onBack: widget.onboarding ? null : () => Navigator.of(context).pop(),
      // Hidden while the keyboard is up for the code.
      // A quiet link, not a second stadium: with Connect filled above it,
      // two full-width pills read as two equal choices, and skipping is not
      // the equal of connecting.
      footer: wantsCode
          ? null
          : Center(
              child: JotaTextLink(
                label: widget.onboarding
                    ? context.l10n.setUpLater
                    : context.l10n.notNow,
                onTap: _onwards,
              ),
            ),
      // Centred in the page's height while searching, so the drawing owns
      // the paper instead of hanging under the title with a void below;
      // scrollable the moment the keyboard needs the room.
      child: wantsCode
          ? SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: JotaGrid.gapM),
                child: ConnectSheet(onDone: _onwards),
              ),
            )
          : Center(
              child: SingleChildScrollView(
                child: ConnectSheet(onDone: _onwards),
              ),
            ),
    );
  }
}
