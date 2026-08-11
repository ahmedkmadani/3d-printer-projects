// ============================================================================
//  Jota — app-lock controller
//
//  Guards the whole app behind Face ID / passcode when the user turns it on in
//  Settings. It locks on cold start and whenever the app has been in the
//  background, and holds the lock screen up until a successful unlock. Turning
//  the lock ON requires a device that can authenticate AND a successful auth
//  right then, so the user can never lock themselves out.
// ============================================================================
import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';
import '../security/authenticator.dart';

/// Why turning the lock on didn't take.
enum LockSetupResult {
  ok,

  /// No biometric and no device passcode — there'd be no way back in.
  unavailable,

  /// The confirming prompt was cancelled or failed.
  failed,
}

class LockController extends ChangeNotifier with WidgetsBindingObserver {
  LockController({required Authenticator auth, required SettingsStore settings})
      : _auth = auth,
        _settings = settings,
        _enabled = settings.appLockEnabled {
    _locked = _enabled;
    WidgetsBinding.instance.addObserver(this);
    // Prompt after the first frame so the lock screen is already painted (and
    // the platform channel is ready) before the system sheet comes up.
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
    }
  }

  final Authenticator _auth;
  final SettingsStore _settings;

  bool _enabled;
  bool _locked = false;
  bool _authenticating = false;

  bool get enabled => _enabled;

  /// True when the lock screen should cover the app.
  bool get locked => _enabled && _locked;

  /// True while the system biometric sheet is up. The lock screen shows a
  /// spinner and disables its button so there is only ever one prompt.
  bool get authenticating => _authenticating;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    // The biometric sheet itself pushes the app to inactive/paused; ignore
    // lifecycle churn while it's up, or we'd relock underneath our own prompt.
    if (_authenticating) return;
    if (state == AppLifecycleState.paused) {
      _locked = true;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed && _locked) {
      _prompt();
    }
  }

  /// The lock screen's "Unlock" button, and the on-resume auto-prompt.
  Future<void> unlock() => _prompt();

  Future<void> _prompt() async {
    if (_authenticating) return;
    _authenticating = true;
    notifyListeners();
    bool ok = false;
    try {
      ok = await _auth.authenticate('Unlock Jota');
    } catch (_) {
      // A thrown platform error is just a failed unlock — fall through to the
      // anti-lockout check below rather than escaping with the lock still up.
      ok = false;
    }
    _authenticating = false;
    if (ok) {
      _locked = false;
      notifyListeners();
      return;
    }
    // Anti-lockout: the "can't lock yourself out" guarantee is enforced when the
    // lock is turned ON, but the device's credentials can be removed later. If
    // the phone can no longer authenticate at all, the lock can never be
    // satisfied and protects nothing — release and disable it rather than strand
    // the user on a screen they can't pass.
    if (!await _canAuthenticate()) {
      _enabled = false;
      _locked = false;
      await _settings.setAppLockEnabled(false);
    }
    notifyListeners();
  }

  Future<bool> _canAuthenticate() async {
    try {
      return await _auth.canAuthenticate();
    } catch (_) {
      return false;
    }
  }

  /// Turn the app lock on or off. Turning it on is gated on a live auth so a
  /// user can't lock themselves out. Returns [LockSetupResult.ok] on success.
  Future<LockSetupResult> setEnabled(bool value) async {
    if (value == _enabled) return LockSetupResult.ok;
    if (value) {
      if (!await _auth.canAuthenticate()) return LockSetupResult.unavailable;
      if (!await _auth.authenticate('Turn on app lock')) {
        return LockSetupResult.failed;
      }
    }
    _enabled = value;
    // Just authenticated (or turned off) — don't strand the user behind a lock.
    _locked = false;
    await _settings.setAppLockEnabled(value);
    notifyListeners();
    return LockSetupResult.ok;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
