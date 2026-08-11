// ============================================================================
//  Jota — settings on the device (the real SettingsStore)
//
//  Two stores, split by sensitivity:
//
//    flutter_secure_storage  the OpenAI API key. Keychain on iOS,
//                            EncryptedSharedPreferences on Android. Never
//                            anywhere else, never logged, never in a crash
//                            report.
//    shared_preferences      everything else — which device we paired with,
//                            whether background sync is on, the model name.
// ============================================================================
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_store.dart';

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const String _kApiKey = 'openai_api_key';
  static const String _kDeviceId = 'device_id';
  static const String _kDeviceName = 'device_name';
  static const String _kBackgroundSync = 'background_sync';
  static const String _kAutoTranscribe = 'auto_transcribe';
  static const String _kSeenOnboarding = 'seen_onboarding';
  static const String _kTags = 'tags';
  static const String _kAppLock = 'app_lock';
  static const String _kModel = 'whisper_model';
  static const String _kLanguage = 'whisper_language';
  static const String _kBackend = 'transcribe_backend';

  static Future<PrefsSettingsStore> open() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const FlutterSecureStorage secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    return PrefsSettingsStore(prefs, secure);
  }

  // ---- API key ------------------------------------------------------------

  @override
  Future<String?> apiKey() => _secure.read(key: _kApiKey);

  @override
  Future<void> setApiKey(String? key) async {
    final String? k = key?.trim();
    if (k == null || k.isEmpty) {
      await _secure.delete(key: _kApiKey);
    } else {
      await _secure.write(key: _kApiKey, value: k);
    }
  }

  @override
  Future<bool> hasApiKey() async {
    final String? k = await apiKey();
    return k != null && k.isNotEmpty;
  }

  // ---- device -------------------------------------------------------------

  @override
  String? get deviceId => _prefs.getString(_kDeviceId);

  @override
  String? get deviceName => _prefs.getString(_kDeviceName);

  @override
  Future<void> setDevice(String? id, {String? name}) async {
    if (id == null) {
      await _prefs.remove(_kDeviceId);
      await _prefs.remove(_kDeviceName);
      return;
    }
    await _prefs.setString(_kDeviceId, id);
    if (name != null) await _prefs.setString(_kDeviceName, name);
  }

  @override
  bool get hasDevice => (deviceId ?? '').isNotEmpty;

  // ---- behaviour ----------------------------------------------------------

  @override
  bool get backgroundSync => _prefs.getBool(_kBackgroundSync) ?? false;

  @override
  Future<void> setBackgroundSync(bool v) => _prefs.setBool(_kBackgroundSync, v);

  @override
  bool get autoTranscribe => _prefs.getBool(_kAutoTranscribe) ?? true;

  @override
  Future<void> setAutoTranscribe(bool v) => _prefs.setBool(_kAutoTranscribe, v);

  @override
  bool get hasSeenOnboarding => _prefs.getBool(_kSeenOnboarding) ?? false;

  @override
  Future<void> setHasSeenOnboarding(bool v) =>
      _prefs.setBool(_kSeenOnboarding, v);

  @override
  List<String> get tags => _prefs.getStringList(_kTags) ?? const <String>[];

  @override
  Future<void> setTags(List<String> v) => _prefs.setStringList(_kTags, v);

  @override
  bool get appLockEnabled => _prefs.getBool(_kAppLock) ?? false;

  @override
  Future<void> setAppLockEnabled(bool v) => _prefs.setBool(_kAppLock, v);

  @override
  String get model => _prefs.getString(_kModel) ?? 'whisper-1';

  @override
  Future<void> setModel(String v) => _prefs.setString(_kModel, v);

  @override
  String? get language {
    final String? v = _prefs.getString(_kLanguage);
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<void> setLanguage(String? v) async {
    if (v == null || v.isEmpty) {
      await _prefs.remove(_kLanguage);
    } else {
      await _prefs.setString(_kLanguage, v);
    }
  }

  @override
  String get backend => _prefs.getString(_kBackend) ?? 'whisper';

  @override
  Future<void> setBackend(String v) => _prefs.setString(_kBackend, v);
}
