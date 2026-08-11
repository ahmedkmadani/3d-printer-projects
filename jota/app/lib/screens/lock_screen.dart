// ============================================================================
//  Jota — lock screen
//
//  The full-screen cover shown while the app is locked. Same warm paper and
//  wordmark as the splash, so a locked Jota reads as Jota, not an error. One
//  action: unlock. It reappears whenever the app returns from the background.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/lock_controller.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    final JotaType t = context.type;
    final LockController lock = context.watch<LockController>();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: JotaGrid.margin),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('JOTA', style: t.wordmark),
                      const SizedBox(height: JotaGrid.gapM),
                      Text(
                        'Locked',
                        style: t.reading.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: JotaGrid.gapXL),
                child: JotaButton(
                  label: 'Unlock',
                  primary: true,
                  upcase: false,
                  height: JotaRows.heightTall,
                  busy: lock.authenticating,
                  onTap: lock.unlock,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
