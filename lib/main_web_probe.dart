// Minimal web-only probe entrypoint.
// Intentionally avoids importing Flutter or any plugins.
// Uses dart:html to verify boot without framework/plugin init.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

void main() {
  try {
    final info = [
      'WEB PROBE: OK (no plugins, no Firebase)',
      'UserAgent: ${html.window.navigator.userAgent}',
      'Time: ${DateTime.now().toIso8601String()}',
    ].join('\n');

    final pre = html.PreElement()
      ..style.whiteSpace = 'pre-wrap'
      ..style.fontFamily = 'monospace'
      ..text = info;

    html.document.body?.children.add(pre);
    // also log to console for Remote Inspector
    // ignore: avoid_print
    print(info);
  } catch (e, st) {
    final err = html.PreElement()
      ..style.whiteSpace = 'pre-wrap'
      ..style.fontFamily = 'monospace'
      ..text = 'WEB PROBE: ERROR\n$e\n$st';
    html.document.body?.children.add(err);
    // ignore: avoid_print
    print('WEB PROBE ERROR: $e');
  }
}
