// ============================================================================
//  Jota — background sync, and what it actually is on each platform
//
//  Jota is a peripheral. It cannot contact the phone. All it can do is advertise,
//  and the phone has to notice. What "noticing" costs is entirely different on
//  the two platforms, and pretending otherwise produces an app that works in the
//  demo and not on anyone's phone.
//
//  ANDROID — a foreground service.
//    A persistent notification is the price of a process that does not get
//    frozen. The service keeps the app's process alive; the scan and the sync run
//    in the normal isolate with the normal database and the normal
//    flutter_blue_plus instance.
//
//  iOS — bluetooth-central plus state restoration, and no timers at all.
//    There is no foreground service and no way to buy one. What there IS:
//      * a scan that names an explicit service UUID keeps being delivered to a
//        backgrounded app (a scan with no UUID filter does not);
//      * the system may terminate the app and later relaunch it in the background
//        when that service is seen, IF the app opted into state restoration
//        before making any other CoreBluetooth call;
//      * a connection request with autoConnect survives into the background and
//        completes when the device appears.
//    Delivery is on the system's schedule, not ours. It can be minutes.
//
//  WHAT DOES NOT WORK, on either platform, and is not implemented anywhere:
//    a periodic timer that wakes up every N minutes and scans. iOS suspends
//    timers the moment the app leaves the foreground, and Android's Doze does the
//    same outside a maintenance window. A "sync every 10 minutes" toggle would be
//    a lie in the settings screen.
//
//  See README.md, "Background sync, honestly", for the user-facing version.
// ============================================================================

/// What the app is currently allowed to do in the background.
enum BackgroundMode {
  /// Not enabled. Sync happens when the app is open.
  off,

  /// Android: foreground service running, scan alive, notification showing.
  foregroundService,

  /// iOS: registered for background delivery of this service UUID. Wakes are on
  /// the system's schedule.
  systemWake,

  /// Asked for, but the platform said no — usually a denied notification
  /// permission on Android 13+.
  denied;

  String get label {
    switch (this) {
      case BackgroundMode.off:
        return 'OFF';
      case BackgroundMode.foregroundService:
        return 'SERVICE';
      case BackgroundMode.systemWake:
        return 'SYSTEM';
      case BackgroundMode.denied:
        return 'DENIED';
    }
  }
}

abstract class BackgroundSyncController {
  BackgroundMode get mode;

  Stream<BackgroundMode> get modeChanges;

  /// Call once at startup, before any BLE call.
  void configure();

  /// Turn background sync on, honestly reporting what was actually obtained
  /// rather than what was asked for.
  Future<BackgroundMode> enable();

  Future<BackgroundMode> disable();

  /// Update the persistent notification so the user can see what the app is
  /// doing without opening it. A no-op where there is no notification.
  Future<void> report(String text);

  Future<void> dispose();

  /// One line, in the user's language, describing what background sync will
  /// really do on this device. Shown verbatim in settings — the honesty has to be
  /// in the product, not only in the README.
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
}
