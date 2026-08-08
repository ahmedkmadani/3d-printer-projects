// ============================================================================
//  Jota — background sync, and what it actually is on each platform
//
//  Jota is a peripheral. It cannot contact the phone. All it can do is
//  advertise, and the phone has to notice. What "noticing" costs is entirely
//  different on the two platforms, and pretending otherwise produces an app
//  that works in the demo and not on anyone's phone.
//
//  ANDROID — a foreground service.
//    A persistent notification is the price of a process that does not get
//    frozen. The service keeps the app's process alive; the scan and the sync
//    run in the normal isolate with the normal database and the normal
//    flutter_blue_plus instance. The task handler below does not do the BLE
//    work — it exists to hold the process open and to poke the main isolate.
//    Running BLE in the task's own isolate would mean a second FlutterBluePlus,
//    a second sqflite handle and a second copy of every store, for no gain.
//
//  iOS — bluetooth-central plus state restoration, and no timers at all.
//    There is no foreground service and no way to buy one. What there IS:
//      * a scan that names an explicit service UUID keeps being delivered to a
//        backgrounded app (a scan with no UUID filter does not);
//      * the system may terminate the app and later relaunch it in the
//        background when that service is seen, IF the app opted into state
//        restoration before making any other CoreBluetooth call;
//      * a connection request with autoConnect survives into the background and
//        completes when the device appears.
//    Delivery is on the system's schedule, not ours. It can be minutes.
//
//  WHAT DOES NOT WORK, on either platform, and is not implemented here:
//    a periodic timer that wakes up every N minutes and scans. iOS suspends
//    timers the moment the app leaves the foreground, and Android's Doze does
//    the same outside a maintenance window. A "sync every 10 minutes" toggle
//    would be a lie in the settings screen.
//
//  See README.md, "Background sync, honestly", for the user-facing version.
// ============================================================================
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the process alive on Android so the scan below it can keep running.
///
/// Top-level and annotated because the plugin looks it up by entry point after
/// a cold start.
@pragma('vm:entry-point')
void jotaForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_JotaKeepAliveHandler());
}

class _JotaKeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  /// Nudges the main isolate, which owns the radio and the database. The
  /// interval is a heartbeat, NOT a sync schedule — the sync is driven by
  /// advertisements, which arrive when they arrive.
  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.sendDataToMain(<String, Object>{
      'tick': timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

/// What the app is currently allowed to do in the background.
enum BackgroundMode {
  /// Not enabled. Sync happens when the app is open.
  off,

  /// Android: foreground service running, scan alive, notification showing.
  foregroundService,

  /// iOS: registered for background delivery of this service UUID. Wakes are
  /// on the system's schedule.
  systemWake,

  /// Asked for, but the platform said no — usually a denied notification
  /// permission on Android 13+.
  denied,
}

class BackgroundSync {
  BackgroundSync();

  BackgroundMode _mode = BackgroundMode.off;
  BackgroundMode get mode => _mode;

  final StreamController<BackgroundMode> _modeChanges =
      StreamController<BackgroundMode>.broadcast();
  Stream<BackgroundMode> get modeChanges => _modeChanges.stream;

  static const String _channelId = 'jota_sync';

  /// Call once at startup, before any BLE call.
  void configure() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: 'Jota sync',
        channelDescription:
            'Keeps Jota listening for notes waiting on the device.',
        // Deliberately the quietest notification Android allows us to have: no
        // sound, no vibration, low importance. It is a receipt, not an alert.
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
        // A heartbeat that keeps the isolate warm. Not a sync interval — see
        // the header. 60 s is frequent enough to notice a dead scan and rare
        // enough to be free.
        eventAction: ForegroundTaskEventAction.repeat(60 * 1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Turn background sync on, honestly reporting what was actually obtained.
  Future<BackgroundMode> enable() async {
    if (Platform.isAndroid) {
      final NotificationPermission perm =
          await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        final NotificationPermission asked =
            await FlutterForegroundTask.requestNotificationPermission();
        if (asked != NotificationPermission.granted) {
          // Android 13+ will not let a foreground service run without a
          // postable notification. Say so rather than silently doing nothing.
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
      // Nothing to start. The capability comes from the Info.plist background
      // mode plus the restoreState option set in main(); what makes wakes
      // actually happen is a scan filtered to our service UUID, which
      // JotaScanner always does.
      return _set(BackgroundMode.systemWake);
    }

    return _set(BackgroundMode.off);
  }

  Future<BackgroundMode> disable() async {
    if (Platform.isAndroid && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    return _set(BackgroundMode.off);
  }

  /// Update the notification so the user can see what it is doing without
  /// opening the app. Android only; a no-op elsewhere.
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

  /// One line, in the user's language, describing what background sync will
  /// really do on this device. Shown verbatim in settings — the honesty has to
  /// be in the product, not only in the README.
  static String explain(BackgroundMode mode) {
    switch (mode) {
      case BackgroundMode.off:
        return 'Notes sync while the app is open.';
      case BackgroundMode.foregroundService:
        return 'Jota keeps a quiet notification so it can pull notes while the '
            'app is closed.';
      case BackgroundMode.systemWake:
        return 'iOS wakes Jota when the device is nearby and has notes. Timing '
            'is decided by the system and can take a few minutes.';
      case BackgroundMode.denied:
        return 'Notifications are off, so Android will not allow background '
            'sync. Notes sync while the app is open.';
    }
  }

  Future<void> dispose() async {
    await _modeChanges.close();
  }
}
