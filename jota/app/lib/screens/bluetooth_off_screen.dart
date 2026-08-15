// ============================================================================
//  Jota — Bluetooth is off
//
//  Jota reaches the phone over Bluetooth and nothing else. With the radio off
//  there is no scan, no sync, and no way to be told a note is waiting — so the
//  app would sit there looking normal and quietly stop being a product.
//
//  It is a NOTICE, NOT A WALL. Everything already synced is on this phone and
//  still reads, so "Keep reading offline" is a real answer and not a
//  consolation. A modal that trapped you behind a radio switch would be worse
//  than the problem: the whole point of the archive is that it is yours,
//  locally, whatever the hardware is doing.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/theme.dart';
import '../design/widgets.dart';
import '../state/device_controller.dart';

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({super.key, required this.unauthorized});

  /// True when the OS denied the permission rather than the radio being off.
  /// Different problem, different fix, different words — offering "turn it on"
  /// for a permission the app cannot grant is how you teach someone that your
  /// buttons lie.
  final bool unauthorized;

  @override
  Widget build(BuildContext context) {
    final DeviceController device = context.watch<DeviceController>();
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    // The moment the radio comes back, get out of the way. Making someone
    // dismiss a screen describing a problem they have already fixed is a small
    // insult, and it happens every single time otherwise.
    if (device.bluetoothReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }

    return JotaScreen(
      label: '',
      upcase: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Spacer(),
          Center(
            child: _CrossedBluetooth(color: c.ink, signal: c.signal),
          ),
          const SizedBox(height: JotaGrid.gapXL),
          Text(
            unauthorized ? 'Jota needs Bluetooth' : 'Bluetooth is off',
            style: t.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: JotaGrid.gapM),
          Text(
            unauthorized
                ? 'Allow Bluetooth in Settings and your notes will come '
                    'across on their own.'
                : 'Jota talks to your phone over Bluetooth. Your notes are '
                    'still here.',
            style: t.prose.copyWith(color: c.inkMuted),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          if (!unauthorized)
            JotaButton(
              label: 'Turn on Bluetooth',
              primary: true,
              upcase: false,
              // Android can flip the radio from here. iOS cannot — it only
              // opens its own prompt — so this may do nothing visible there,
              // and the offline door below is what actually gets you out.
              onTap: () => device.turnOnBluetooth(),
            ),
          const SizedBox(height: JotaRows.gap),
          JotaButton(
            label: 'Keep reading offline',
            upcase: false,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: JotaGrid.gapL),
        ],
      ),
    );
  }
}

/// The Bluetooth rune with a stroke through it. Drawn rather than pulled from
/// an icon set so the slash can take the signal colour on its own — the mark
/// says "off", and off is the one thing on this screen that is not neutral.
class _CrossedBluetooth extends StatelessWidget {
  const _CrossedBluetooth({required this.color, required this.signal});

  final Color color;
  final Color signal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(painter: _BtPainter(color: color, signal: signal)),
    );
  }
}

class _BtPainter extends CustomPainter {
  const _BtPainter({required this.color, required this.signal});

  final Color color;
  final Color signal;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The rune: a vertical spine with two bowties crossing it.
    final Path p = Path()
      ..moveTo(w * 0.30, h * 0.32)
      ..lineTo(w * 0.70, h * 0.68)
      ..lineTo(w * 0.50, h * 0.84)
      ..lineTo(w * 0.50, h * 0.16)
      ..lineTo(w * 0.70, h * 0.32)
      ..lineTo(w * 0.30, h * 0.68);
    canvas.drawPath(p, stroke);

    canvas.drawLine(
      Offset(w * 0.12, h * 0.12),
      Offset(w * 0.88, h * 0.88),
      stroke..color = signal,
    );
  }

  @override
  bool shouldRepaint(_BtPainter old) =>
      old.color != color || old.signal != signal;
}
