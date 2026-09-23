// ============================================================================
//  Jota — settings interface
//
//  There is no account and no server, so this is the entire configuration
//  surface of the product: one secret, one paired device, three behaviours.
//
//  The real implementation (PrefsSettingsStore) splits by sensitivity —
//  flutter_secure_storage for the API key, shared_preferences for everything
//  else. Nothing outside that file needs to know which is which.
// ============================================================================
import 'dart:math';

abstract class SettingsStore {
  // ---- API key ------------------------------------------------------------
  // Async because on the real implementation it is a Keychain read.

  Future<String?> apiKey();

  Future<void> setApiKey(String? key);

  Future<bool> hasApiKey();

  /// `sk-…abcd`. Enough to tell two keys apart, not enough to use one.
  static String maskKey(String key) {
    if (key.length <= 8) return '••••';
    return '${key.substring(0, 3)}…${key.substring(key.length - 4)}';
  }

  // ---- identity -----------------------------------------------------------

  /// This phone's own id — a uuid generated once, on first run, and never
  /// changed.
  ///
  /// It is what the device stores as its owner, and presenting it is what makes
  /// "pair once" true: a bonded phone reconnects with no code and no prompt.
  /// It is also what stops two phones from silently sharing a Jota, and what
  /// lets a person see which phone a device belongs to.
  String get appId;

  // ---- device -------------------------------------------------------------

  /// The remote id of the Jota we are paired with. Remembered so the app can
  /// reconnect without a scan, and so background sync knows what to look for.
  String? get deviceId;

  String? get deviceName;

  Future<void> setDevice(String? id, {String? name});

  bool get hasDevice;

  // ---- behaviour ----------------------------------------------------------

  bool get backgroundSync;
  Future<void> setBackgroundSync(bool v);

  /// Transcribe automatically once a note arrives. On by default — the whole
  /// premise is that you speak now and read later.
  bool get autoTranscribe;
  Future<void> setAutoTranscribe(bool v);

  /// The archive's order. Newest first by default; the link beside the
  /// Notes title flips it and it stays flipped.
  bool get notesNewestFirst;

  /// 'system', 'light' or 'dark'. The phone has two appearances; this is
  /// the one place the user can decide not to follow it.
  String get appearance;
  Future<void> setAppearance(String v);

  /// How many times the archive has shown its "swipe to delete / share" line.
  /// It stops after three: a hint that never leaves is a label.
  int get swipeHintShown;
  Future<void> setSwipeHintShown(int v);

  Future<void> setNotesNewestFirst(bool v);

  /// Whether the first-run splash → onboarding flow has been completed. False on
  /// a fresh install; set true once the user finishes or skips onboarding, so
  /// every launch after the first goes straight to the notes.
  bool get hasSeenOnboarding;
  Future<void> setHasSeenOnboarding(bool v);

  /// The user's tags, managed in the APP (app-first). Editable any time without
  /// the device; synced to the Jota whenever it connects. Uppercase, since the
  /// e-paper shows them in its mono label face.
  List<String> get tags;
  Future<void> setTags(List<String> v);

  /// Whether opening the app requires Face ID / Touch ID / the device passcode.
  /// Off by default. The notes are personal and live only on this phone, so the
  /// lock is the on-device complement to that: private AND protected.
  bool get appLockEnabled;
  Future<void> setAppLockEnabled(bool v);

  String get model;
  Future<void> setModel(String v);

  /// ISO-639-1, or null to let the backend detect. A hint measurably improves
  /// accuracy on short clips, which is most of what this device records.
  String? get language;
  Future<void> setLanguage(String? v);

  /// Which Transcriber implementation to use. See lib/transcribe/.
  String get backend;
  Future<void> setBackend(String v);
}

/// What a fresh install starts with, and what an un-paired Jota shows on its
/// TAGS screen — the same three, defined once on each side (the firmware's copy
/// is `tagsSetDefaults` in `app/tags.cpp`).
///
/// Three rather than a longer list: a tag is chosen with one button on a
/// 200x200 panel, and a list you have to think about is a list you skip. These
/// are seeded, not enforced — all three can be renamed or removed.
const List<String> kDefaultTags = <String>['WORK', 'PERSONAL', 'IDEAS'];

/// A random uuid v4, from the platform's secure generator.
///
/// Not worth a package: this is called once in the lifetime of an install, and
/// the only property that matters is that two installs never collide.
String newAppId() {
  final Random r = Random.secure();
  final List<int> b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 1
  final String hex =
      b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
