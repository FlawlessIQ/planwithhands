import 'package:flutter/foundation.dart';

/// Connects Firebase Functions to the local emulator in debug mode.
Future<void> connectFunctionsEmulatorIfNeeded() async {
  if (kDebugMode) {
    try {
      // TEMPORARILY DISABLED: Using production functions for user management
      // due to Google Identity Toolkit API quota issues in emulator

      // Default instance
      // FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      // Explicit us-central1 instance (our functions region)
      // FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator('localhost', 5001);
    } catch (_) {
      // Best-effort; ignore if already connected or not available
    }
  }
}
