import 'package:flutter/foundation.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class UppercutTracking {
  /// Fire the Uppercut signup tracking call.
  /// Should be called immediately after successful account creation.
  /// Only fires on web platform — no-op on mobile.
  static void trackSignup(String email) {
    if (!kIsWeb) return; // Mobile: no-op (cookie tracking is web-only)

    try {
      // Check Uppercut is loaded (the script tag on the
      // marketing site may not be present on app.reflect-os.com)
      final hasUppercut = js.context.hasProperty('Uppercut');
      if (!hasUppercut) {
        debugPrint('UppercutTracking: Uppercut.js not loaded, skipping');
        return;
      }

      js.context.callMethod('eval', [
        "if (typeof Uppercut !== 'undefined') { "
            "Uppercut.signup('${email.replaceAll("'", "\\'")}'); "
            "}"
      ]);
      debugPrint('UppercutTracking: signup tracked for $email');
    } catch (e) {
      // Never throw — tracking must never break the signup flow
      debugPrint('UppercutTracking: error tracking signup: $e');
    }
  }
}
