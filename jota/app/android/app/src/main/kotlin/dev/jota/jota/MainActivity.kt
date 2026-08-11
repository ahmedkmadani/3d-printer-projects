package dev.jota.jota

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: local_auth's biometric prompt
// is a FragmentActivity API, so the app lock (Settings ▸ Privacy) needs a
// fragment host to show the system sheet.
class MainActivity: FlutterFragmentActivity()
