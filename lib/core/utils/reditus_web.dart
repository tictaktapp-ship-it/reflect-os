import 'dart:js' as js;

void trackReditusConversion(String email) {
  try {
    js.context.callMethod(
      'gr',
      ['track', 'conversion', js.JsObject.jsify({'email': email})],
    );
  } catch (_) {
    // Reditus not loaded or gr() not defined — fail silently
  }
}
