// Stub for non-web platforms. The conditional import in
// calendar_settings_screen.dart selects this file on mobile/desktop.

void Function() addCalendarMessageListener(void Function(dynamic) handler) {
  return () {};
}

void openCalendarOAuthPopup(String url) {}
