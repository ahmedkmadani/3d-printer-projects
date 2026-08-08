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
