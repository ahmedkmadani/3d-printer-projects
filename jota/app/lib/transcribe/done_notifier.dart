// ============================================================================
//  Jota — "your note is ready"
//
//  On-device Whisper takes minutes per note on this phone. Nobody watches a
//  spinner for minutes; they put the phone down. This is the tap on the
//  shoulder when the words land — and only then: while the app is on screen
//  the list already cross-fades the text in, and a banner on top of that
//  would be the same news twice.
//
//  One channel, low importance, no sound: it is a receipt, not an alarm,
//  the same stance as the sync service's notification. Tapping it opens the
//  app, which is all it needs to do.
// ============================================================================
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/note.dart';

abstract class TranscriptionNotifier {
  /// Called once work is about to start, so the permission prompt comes at
  /// the moment it makes sense — "a note is being transcribed, may I tell
  /// you when it is done" — rather than at install.
  Future<void> prepare();

  /// A note's words have landed.
  Future<void> transcribed(Note note);
}

class LocalTranscriptionNotifier
    with WidgetsBindingObserver
    implements TranscriptionNotifier {
  LocalTranscriptionNotifier() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const String _channelId = 'jota_transcripts';

  /// The app's pinned locale, read at post time. Set by Services after boot;
  /// null follows the phone. A notification is app UI, so it speaks the
  /// app's language, loaded here without a BuildContext.
  Locale? Function()? localeOf;

  AppLocalizations get _l {
    final Locale device = WidgetsBinding.instance.platformDispatcher.locale;
    final Locale loc = localeOf?.call() ?? device;
    return lookupAppLocalizations(
      loc.languageCode == 'ar' ? const Locale('ar') : const Locale('en'),
    );
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _asked = false;
  AppLifecycleState _state = AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    debugPrint('jota/notify  lifecycle $state');
  }

  bool get _inForeground => _state == AppLifecycleState.resumed;

  @override
  Future<void> prepare() async {
    if (!_ready) {
      // The launcher icon as the small icon: no bespoke glyph yet, and a
      // missing drawable is a crash rather than a blank.
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _ready = true;
      debugPrint('jota/notify  plugin initialised');
    }
    if (_asked) return;
    _asked = true;
    // Android 13+ asks; older versions and iOS return without a prompt or
    // with their own. A "no" is remembered by the OS, so asking again later
    // is a no-op rather than a nag.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true);
  }

  @override
  Future<void> transcribed(Note note) async {
    debugPrint('jota/notify  ${note.displayId} done; ready=$_ready '
        'state=$_state');
    if (!_ready || _inForeground) return;
    await _plugin.show(
      // One id per note, so a re-run replaces its own notification instead
      // of stacking a second one.
      note.rowId ?? note.noteId,
      _l.noteReady(note.displayId),
      note.preview,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _l.channelTranscripts,
          channelDescription: _l.channelTranscriptsBody,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
    );
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
