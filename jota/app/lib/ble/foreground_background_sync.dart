// ============================================================================
//  Jota — the real BackgroundSyncController
//
//  Android gets a foreground service; iOS gets nothing to start, because the
//  capability there comes from the Info.plist background mode plus the
//  restoreState option set before the first BLE call. See background_sync.dart
//  for the full reasoning.
// ============================================================================
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'background_sync.dart';

/// Keeps the process alive on Android so the scan can keep running.
///
/// Top-level and annotated because the plugin looks it up by entry point after a
/// cold start.
@pragma('vm:entry-point')
void jotaForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_JotaKeepAliveHandler());
}

class _JotaKeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  /// Nudges the main isolate, which owns the radio and the database. The interval
  /// is a heartbeat, NOT a sync schedule — the sync is driven by advertisements,
  /// which arrive when they arrive.
  ///
  /// Running the BLE work in this isolate instead would mean a second
  /// FlutterBluePlus, a second sqflite handle and a second copy of every store,
  /// for no gain.
  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain(<String, Object>{
      'tick': timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class ForegroundServiceBackgroundSync implements BackgroundSyncController {
  ForegroundServiceBackgroundSync();

  BackgroundMode _mode = BackgroundMode.off;

  @override
  BackgroundMode get mode => _mode;

  final StreamController<BackgroundMode> _modeChanges =
      StreamController<BackgroundMode>.broadcast();

  @override
  Stream<BackgroundMode> get modeChanges => _modeChanges.stream;

  static const String _channelId = 'jota_sync';

  @override
  void configure() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: 'Jota sync',
        channelDescription:
            'Keeps Jota listening for notes waiting on the device.',
        // Deliberately the quietest notification Android allows: no sound, no
        // vibration, low importance. It is a receipt, not an alert.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // A heartbeat that keeps the isolate warm. Not a sync interval — 60 s is
        // frequent enough to notice a dead scan and rare enough to be free.
        eventAction: ForegroundTaskEventAction.repeat(60 * 1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  @override
  Future<BackgroundMode> enable() async {
    if (Platform.isAndroid) {
      final NotificationPermission perm =
          await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        final NotificationPermission asked =
            await FlutterForegroundTask.requestNotificationPermission();
        if (asked != NotificationPermission.granted) {
          // Android 13+ will not let a foreground service run without a postable
          // notification. Say so rather than silently doing nothing.
          return _set(BackgroundMode.denied);
        }
      }

      if (await FlutterForegroundTask.isRunningService) {
        return _set(BackgroundMode.foregroundService);
      }

      final ServiceRequestResult r = await FlutterForegroundTask.startService(
        notificationTitle: 'Jota',
        notificationText: 'Listening for notes',
        callback: jotaForegroundCallback,
      );
      return _set(
        r.success ? BackgroundMode.foregroundService : BackgroundMode.denied,
      );
    }

    if (Platform.isIOS) {
      // Nothing to start. What makes wakes actually happen is a scan filtered to
      // our service UUID, which JotaScanner always does.
      return _set(BackgroundMode.systemWake);
    }

    return _set(BackgroundMode.off);
  }

  @override
  Future<BackgroundMode> disable() async {
    if (Platform.isAndroid && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    return _set(BackgroundMode.off);
  }

  @override
  Future<void> report(String text) async {
    if (!Platform.isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Jota',
      notificationText: text,
    );
  }

  BackgroundMode _set(BackgroundMode m) {
    _mode = m;
    if (!_modeChanges.isClosed) _modeChanges.add(m);
    return m;
  }

  @override
  Future<void> dispose() async {
    await _modeChanges.close();
  }
}
