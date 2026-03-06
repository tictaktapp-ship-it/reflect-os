// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Registers [handler] to receive data from cross-origin postMessage events.
/// Returns a disposer that removes the listener when called.
void Function() addCalendarMessageListener(void Function(dynamic) handler) {
  void bridge(html.Event event) {
    if (event is html.MessageEvent) handler(event.data);
  }
  html.window.addEventListener('message', bridge);
  return () => html.window.removeEventListener('message', bridge);
}

/// Opens the OAuth authorisation URL in a popup window.
void openCalendarOAuthPopup(String url) {
  html.window.open(url, 'calendar_oauth', 'width=500,height=700,scrollbars=yes');
}
