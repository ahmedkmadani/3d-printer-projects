// ============================================================================
//  Jota — settings
//
//  Two stores, split by sensitivity:
//
//    flutter_secure_storage  the OpenAI API key. Keychain on iOS, EncryptedShared
//                            Preferences on Android. Never anywhere else, never
//                            logged, never in a crash report.
//    shared_preferences      everything else — which device we paired with,
//                            whether background sync is on, the model name.
//
//  There is no account and no server, so this is the entire configuration
//  surface of the product.
// ============================================================================
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  SettingsStore(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const String _kApiKey = 'openai_api_key';
  static const String _kDeviceId = 'device_id';
  static const String _kDeviceName = 'device_name';
  static const String _kBackgroundSync = 'background_sync';
  static const String _kAutoTranscribe = 'auto_transcribe';
  static const String _kModel = 'whisper_model';
  static const String _kLanguage = 'whisper_language';
  static const String _kBackend = 'transcribe_backend';

  static Future<SettingsStore> open() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const FlutterSecureStorage secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
    return SettingsStore(prefs, secure);
  }

  // ---- API key ------------------------------------------------------------

  Future<String?> apiKey() => _secure.read(key: _kApiKey);

  Future<void> setApiKey(String? key) async {
    final String? k = key?.trim();
    if (k == null || k.isEmpty) {
      await _secure.delete(key: _kApiKey);
    } else {
      await _secure.write(key: _kApiKey, value: k);
    }
  }

  Future<bool> hasApiKey() async {
    final String? k = await apiKey();
    return k != null && k.isNotEmpty;
  }

  /// `sk-...abcd`. Enough to tell two keys apart, not enough to use one.
  static String maskKey(String key) {
    if (key.length <= 8) return '••••';
    return '${key.substring(0, 3)}…${key.substring(key.length - 4)}';
  }

  // ---- device -------------------------------------------------------------

  /// The remote id of the Jota we are paired with. Remembered so the app can
  /// reconnect without a scan, and so background sync knows what to look for.
  String? get deviceId => _prefs.getString(_kDeviceId);
  String? get deviceName => _prefs.getString(_kDeviceName);

  Future<void> setDevice(String? id, {String? name}) async {
    if (id == null) {
      await _prefs.remove(_kDeviceId);
      await _prefs.remove(_kDeviceName);
      return;
    }
    await _prefs.setString(_kDeviceId, id);
    if (name != null) await _prefs.setString(_kDeviceName, name);
  }

  bool get hasDevice => (deviceId ?? '').isNotEmpty;

  // ---- behaviour ----------------------------------------------------------

  bool get backgroundSync => _prefs.getBool(_kBackgroundSync) ?? false;
  Future<void> setBackgroundSync(bool v) => _prefs.setBool(_kBackgroundSync, v);

  /// Transcribe automatically after a note arrives. On by default — the whole
  /// premise is that you speak and later you read.
  bool get autoTranscribe => _prefs.getBool(_kAutoTranscribe) ?? true;
  Future<void> setAutoTranscribe(bool v) => _prefs.setBool(_kAutoTranscribe, v);

  String get model => _prefs.getString(_kModel) ?? 'whisper-1';
  Future<void> setModel(String v) => _prefs.setString(_kModel, v);

  /// ISO-639-1, or null to let Whisper detect. A hint measurably improves
  /// accuracy on short clips, which is most of what this device records.
  String? get language {
    final String? v = _prefs.getString(_kLanguage);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setLanguage(String? v) async {
    if (v == null || v.isEmpty) {
      await _prefs.remove(_kLanguage);
    } else {
      await _prefs.setString(_kLanguage, v);
    }
  }

  /// Which Transcriber implementation to use. See lib/transcribe/.
  String get backend => _prefs.getString(_kBackend) ?? 'whisper';
  Future<void> setBackend(String v) => _prefs.setString(_kBackend, v);
}
