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

    return Semantics(
      label: 'Jota status: ${line.text}',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: JotaGrid.margin,
            vertical: JotaGrid.gapS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _Dot(present: line.present, busy: line.busy),
              const SizedBox(width: JotaGrid.gapS),
              Flexible(
                child: Text(
                  line.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(
                    color: line.present ? c.ink : c.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled when the device is there, hollow when it is not. Same language as the
/// e-paper's ring and dot, so the two objects read as one product.
class _Dot extends StatelessWidget {
  const _Dot({required this.present, required this.busy});

  final bool present;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final JotaColors c = context.ink;
    if (busy) {
      return SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: c.ink),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: present ? c.ink : Colors.transparent,
        border: Border.all(color: present ? c.ink : c.inkMuted, width: 1),
      ),
    );
  }
}

/// The whole state machine, in one place, so the wording cannot drift between
/// the chip and the Sync screen.
class _DeviceLine {
  const _DeviceLine(this.text, {this.present = false, this.busy = false});

  final String text;
  final bool present;
  final bool busy;

  /// ` · 62%`, or nothing at all when the charge is unknown.
  static String _charge(DeviceController device) {
    final int? pct = device.batteryOnDevice;
    return pct == null ? '' : ' · $pct%';
  }

  static _DeviceLine of(DeviceController device) {
    if (!device.hasPairedDevice) {
      return const _DeviceLine('No Jota paired · tap to connect');
    }
    if (device.isSyncing) {
      return _DeviceLine(
        '${device.pairedName} · saving your notes',
        present: true,
        busy: true,
      );
    }
    if (device.adapter == AdapterStatus.unauthorized) {
      return _DeviceLine('${device.pairedName} · needs permission');
    }
    if (!device.bluetoothReady) {
      return _DeviceLine('${device.pairedName} · Bluetooth is off');
    }

    final int? pending = device.pendingOnDevice;
    if (pending == null) {
      // Out of range is NOT the same as "nothing waiting", and saying "up to
      // date" for a device we cannot see would be a lie the app told for weeks.
      return _DeviceLine('${device.pairedName}${_charge(device)} · not in range');
    }
    if (pending == 0) {
      return _DeviceLine(
        '${device.pairedName}${_charge(device)} · up to date',
        present: true,
      );
    }
    return _DeviceLine(
      '${device.pairedName}${_charge(device)} · '
      '${pending == 1 ? '1 note' : '$pending notes'} waiting',
      present: true,
    );
  }
}
