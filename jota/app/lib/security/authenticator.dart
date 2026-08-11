// ============================================================================
//  Jota — the app-lock gate (interface)
//
//  A thin seam over the platform's biometric / passcode prompt. The real
//  implementation wraps local_auth; the preview fakes it. Nothing above this
//  interface imports the plugin, which is what keeps main_preview.dart running
//  in a browser where local_auth is a MissingPluginException.
// ============================================================================
abstract class Authenticator {
  /// Whether this device can authenticate at all — a biometric is enrolled, or
  /// at least a device passcode is set. If false, the app lock cannot be turned
  /// on (there would be no way back in).
  Future<bool> canAuthenticate();

  /// Prompt for Face ID / Touch ID / fingerprint, falling back to the device
  /// passcode. `reason` is shown by the OS. Returns true only on a confirmed
  /// match; false on cancel, lockout, or any error.
  Future<bool> authenticate(String reason);
}
