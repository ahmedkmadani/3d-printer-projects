// ============================================================================
//  Jota — the device line
//
//  One line, always visible, answering the question the app could not answer
//  before: is my Jota there, and which one is it?
//
//  It borrows the device's own vocabulary rather than inventing a phone idiom —
//  a dot that is filled when present and hollow when not, the same figure
//  treatment for the count, and the device's own JOTA-91C4 so the two screens
//  can be read against each other.
//
//  Drawn as a stadium with TWO slots, per the design lock: which Jota on the
//  left, how it is on the right (`84% · SYNCED`). It used to be one centred
//  sentence, which meant the name and the state grew and shrank against each
//  other and nothing ever sat still between rebuilds.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ble/device_scanner.dart';
import '../../design/theme.dart';
import '../../state/device_controller.dart';

class DeviceChip extends StatelessWidget {
  const DeviceChip({super.key, this.onTap});

  /// Tapping goes to Sync — the one place anything can be done about any of
  /// these states.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final DeviceController device = context.watch<DeviceController>();
    final JotaColors c = context.ink;
    final JotaType t = context.type;

    final _DeviceLine line = _DeviceLine.of(device);

    // Mono, small, tracked and muted: the chip is chrome about a device, not a
    // sentence, and every figure in it (the id, the charge, the count) is one
    // the device itself prints in the same face.
    final TextStyle style = t.reading.copyWith(
      color: c.inkMuted,
      fontSize: 12,
      letterSpacing: 0.8,
    );

    return Semantics(
      label: 'Jota status: ${line.name} ${line.status}',
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            JotaGrid.margin,
            0,
            JotaGrid.margin,
            JotaGrid.gapS,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: JotaGrid.gapM + JotaGrid.unit,
              vertical: JotaGrid.gapS + 2,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: c.rule, width: JotaGrid.hairline),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // The name yields first: the status is the half you are
                // reading the chip for, so it never gets truncated.
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _Dot(present: line.present, busy: line.busy),
                      const SizedBox(width: JotaGrid.gapS),
                      Flexible(
                        child: Text(
                          line.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: JotaGrid.gapM),
                Text(line.status, maxLines: 1, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled when the device is there, hollow when it is not. Same language as the
/// e-paper's ring and dot, so the two objects read as one product.
///
/// This is one of the two places the accent is allowed: a Jota in range and
/// talking is the definition of LIVE. Out of range it is a hollow outline, so
/// the state survives without the colour.
class _Dot extends StatelessWidget {
  const _Dot({required this.present, required this.busy});

  final bool present;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    if (busy) {
      return SizedBox(
        width: 9,
        height: 9,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: c.signal),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: present ? c.signal : Colors.transparent,
        border: Border.all(color: present ? c.signal : c.inkMuted, width: 1),
      ),
    );
  }
}

/// The whole state machine, in one place, so the wording cannot drift between
/// the chip and the Sync screen.
class _DeviceLine {
  const _DeviceLine({
    required this.name,
    required this.status,
    this.present = false,
    this.busy = false,
  });

  /// Left slot: WHICH Jota. The same id the device prints on its own splash.
  final String name;

  /// Right slot: HOW it is, in caps, charge first when it is known.
  final String status;

  final bool present;
  final bool busy;

  /// `84% · `, or nothing at all when the charge is unknown — which it is on
  /// every device built so far, because BATTERY_ADC_PIN is still -1.
  static String _charge(DeviceController device) {
    final int? pct = device.batteryOnDevice;
    return pct == null ? '' : '$pct% · ';
  }

  static _DeviceLine of(DeviceController device) {
    if (!device.hasPairedDevice) {
      return const _DeviceLine(name: 'NO JOTA', status: 'TAP TO CONNECT');
    }
    final String name = device.pairedName;

    if (device.isSyncing) {
      return _DeviceLine(
        name: name,
        status: '${_charge(device)}SAVING',
        present: true,
        busy: true,
      );
    }
    if (device.adapter == AdapterStatus.unauthorized) {
      return _DeviceLine(name: name, status: 'NEEDS PERMISSION');
    }
    if (!device.bluetoothReady) {
      return _DeviceLine(name: name, status: 'BLUETOOTH OFF');
    }

    final int? pending = device.pendingOnDevice;
    if (pending == null) {
      // Out of range is NOT the same as "nothing waiting", and saying "up to
      // date" for a device we cannot see would be a lie the app told for weeks.
      return _DeviceLine(
        name: name,
        status: '${_charge(device)}NOT IN RANGE',
      );
    }
    if (pending == 0) {
      return _DeviceLine(
        name: name,
        status: '${_charge(device)}SYNCED',
        present: true,
      );
    }
    return _DeviceLine(
      name: name,
      status: '${_charge(device)}$pending WAITING',
      present: true,
    );
  }
}
