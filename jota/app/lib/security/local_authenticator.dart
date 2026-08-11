// ============================================================================
//  Jota — the real app-lock gate (local_auth)
//
//  Face ID / Touch ID on iOS, fingerprint / face on Android, each with the
//  device passcode as an automatic fallback (biometricOnly: false). We never
//  store a secret ourselves — the OS owns the credential and the prompt.
// ============================================================================
import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/local_auth.dart';

import 'authenticator.dart';

class LocalAuthenticator implements Authenticator {
  final LocalAuthentication _local = LocalAuthentication();

  @override
  Future<bool> canAuthenticate() async {
    try {
      // isDeviceSupported() is true when a biometric OR a device passcode is
      // set — exactly the set of credentials our prompt can fall back across.
      return await _local.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _local.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Survive the app being pushed to the background mid-prompt (e.g. a
          // Face ID sheet the user leaves and returns to) instead of failing.
          stickyAuth: true,
          // Allow the device passcode when there is no biometric — otherwise a
          // passcode-only phone could never unlock.
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      // No hardware, not enrolled, too many attempts — all read as "not now".
      return false;
    }
  }
}
