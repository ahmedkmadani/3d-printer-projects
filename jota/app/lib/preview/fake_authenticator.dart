// ============================================================================
//  Jota — the preview app-lock gate
//
//  A browser tab has no biometrics. This reports itself capable so the Settings
//  toggle is explorable, and (by default) succeeds instantly so the preview is
//  never stuck behind a lock. Flip `succeed` to false to hold the lock screen
//  on for a screenshot.
// ============================================================================
import '../security/authenticator.dart';

class FakeAuthenticator implements Authenticator {
  FakeAuthenticator({this.succeed = true});

  final bool succeed;

  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<bool> authenticate(String reason) async => succeed;
}
