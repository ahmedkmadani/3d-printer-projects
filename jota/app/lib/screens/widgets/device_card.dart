// ============================================================================
//  Jota — the device card
//
//  One card on Home answering the question the app could not answer before:
//  is my Jota there, and which one is it?
//
//  It borrows the device's own vocabulary rather than inventing a phone idiom —
//  a dot that is filled when present and hollow when not, the same figure
//  treatment for the count, and the device's own JOTA-91C4 so the two screens
//  can be read against each other.
//
//  It used to be a stadium pinned above the nav on every tab. That was chrome
//  about a device drawn like a control: it read as a button that led nowhere,
//  floated between the content and the nav, and took a row from screens that
//  had nothing to do with the device. Now it is one of Home's field-coloured
//  cards, with the charge as a real figure, read from the advertisement the
//  device sends (GPIO4 on the board, live since 2026-09-23).
//
//  Tapping it DOES the thing rather than going somewhere to do it. product.md:
//  "Sync is never a place you go." With no device yet there is still something
//  to go TO, so that case pushes Connect.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ble/device_scanner.dart';
import '../../ble/sync_service.dart';
import '../../design/theme.dart';
import '../../state/device_controller.dart';
import '../connect_screen.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key});

  Future<void> _tapped(BuildContext context) async {
    final DeviceController device = context.read<DeviceController>();
    if (!device.hasPairedDevice) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ConnectScreen()),
      );
      return;
    }
    if (device.isSyncing) return;
    final SyncResult? r = await device.syncNow();
    if (!context.mounted) return;

    // SAY WHAT HAPPENED. A sync started from here used to report nowhere:
    // the engine stored an error, the card went back to idle, and the archive
    // stayed empty with no account of why — which is indistinguishable from
    // "there was nothing to fetch". On real hardware that cost an evening.
    // "Up to date" must mean the DEVICE has nothing left, not merely that this
    // run threw no exception. A run where every transfer failed ends with
    // added=0, remaining=3 and error=null — so ok is true — and the old
    // wording reported that as "Already up to date" while three notes sat on
    // the device.
    final String message = r == null
        ? (device.lastError ?? 'Nothing to sync')
        : !r.ok
            ? (r.error ?? 'Sync failed')
            : r.notesAdded > 0
                ? 'Got ${r.notesAdded} note${r.notesAdded == 1 ? '' : 's'}'
                : r.notesRemaining > 0
                    ? '${r.notesRemaining} still on Jota — could not transfer'
                    : 'Already up to date';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final DeviceController device = context.watch<DeviceController>();
    final JotaColors c = context.ink;
    final JotaType t = context.type;

    final _DeviceLine line = _DeviceLine.of(device);

    // Mono, small, tracked and muted: every figure in the card (the id, the
    // charge, the count) is one the device itself prints in the same face.
    final TextStyle small = t.meta.copyWith(color: c.inkMuted);

    return Semantics(
      label: 'Jota status: ${line.name} ${line.figure ?? ''} ${line.status}',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tapped(context),
        child: Container(
          // The design draws this card taller than Home's other two: the
          // figure is the point of it. Sized so it stays that height in every
          // state — on the first real install the charge was unknown and the
          // device out of range, the figure slot went empty, and the card
          // shrank to one line, which is the chip it replaced, only filled.
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(
            horizontal: JotaGrid.gapL,
            vertical: JotaGrid.gapM + JotaGrid.unit,
          ),
          decoration: BoxDecoration(
            color: c.field,
            borderRadius: const BorderRadius.all(
              Radius.circular(JotaCards.radius),
            ),
          ),
          child: Row(
            children: <Widget>[
              // WHICH Jota. Yields first: the state is the half you are
              // reading the card for, so it never gets truncated.
              Expanded(
                child: Row(
                  children: <Widget>[
                    _Dot(present: line.present, busy: line.busy),
                    const SizedBox(width: JotaGrid.gapS + 2),
                    Flexible(
                      child: Text(
                        line.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: JotaGrid.gapM),
              // HOW it is: one figure, and the state under it.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (line.figure != null) ...<Widget>[
                    Text(
                      line.figure!,
                      // The display role is the big mono figure; only the
                      // leading is tightened so the status line can sit
                      // right under it.
                      style: t.display.copyWith(height: 1),
                    ),
                    const SizedBox(height: JotaGrid.unit),
                  ],
                  Text(line.status, maxLines: 1, style: small),
                ],
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
    // Busy: the dot breathes. A slow fade in and out, nothing spinning — the
    // device is doing something and the card says so without a spinner
    // borrowed from a web page.
    if (busy) return _Breathing(color: c.signal);
    return Container(
      width: JotaIndicators.signalDot,
      height: JotaIndicators.signalDot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: present ? c.signal : Colors.transparent,
        border: Border.all(color: present ? c.signal : c.inkMuted, width: 1),
      ),
    );
  }
}

/// The signal dot, breathing: 0.25 to full and back, about once a second.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.color});

  final Color color;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: JotaIndicators.signalDot,
        height: JotaIndicators.signalDot,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}

/// The whole state machine, in one place, so the wording cannot drift.
class _DeviceLine {
  const _DeviceLine({
    required this.name,
    required this.status,
    this.figure,
    this.present = false,
    this.busy = false,
  });

  /// Left: WHICH Jota. The same id the device prints on its own splash.
  final String name;

  /// Right, large: the one figure worth a glance — the charge when the device
  /// is quiet, the count when it is holding notes for you.
  ///
  /// A dash when the charge is unknown — a device on old firmware, or one not
  /// heard from yet. A dash is an honest gap; a number would be an invented
  /// one. Null only when there is no device to have a figure.
  final String? figure;

  /// Right, small: HOW it is, in caps.
  final String status;

  final bool present;
  final bool busy;

  static String _charge(DeviceController device) {
    final int? pct = device.batteryOnDevice;
    return pct == null ? '—' : '$pct%';
  }

  static _DeviceLine of(DeviceController device) {
    if (!device.hasPairedDevice) {
      return const _DeviceLine(name: 'NO JOTA', status: 'TAP TO CONNECT');
    }
    final String name = device.pairedName;
    final String charge = _charge(device);

    if (device.isSyncing) {
      return _DeviceLine(
        name: name,
        figure: charge,
        status: 'SAVING',
        present: true,
        busy: true,
      );
    }
    if (device.adapter == AdapterStatus.unauthorized) {
      return _DeviceLine(
        name: name,
        figure: charge,
        status: 'NEEDS PERMISSION',
      );
    }
    if (!device.bluetoothReady) {
      return _DeviceLine(name: name, figure: charge, status: 'BLUETOOTH OFF');
    }

    final int? pending = device.pendingOnDevice;
    if (pending == null) {
      // Out of range is NOT the same as "nothing waiting", and saying "up to
      // date" for a device we cannot see would be a lie the app told for weeks.
      return _DeviceLine(name: name, figure: charge, status: 'NOT IN RANGE');
    }
    if (pending == 0) {
      return _DeviceLine(
        name: name,
        figure: charge,
        status: 'SYNCED',
        present: true,
      );
    }
    // Notes waiting outrank the charge for the big slot; the charge rides
    // along in the small one so neither fact is lost.
    return _DeviceLine(
      name: name,
      figure: '$pending',
      status: 'WAITING · $charge',
      present: true,
    );
  }
}
