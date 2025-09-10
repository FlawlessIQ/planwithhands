// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void main() {
  html.document.body?.append(
    html.PreElement()
      ..style.whiteSpace = 'pre-wrap'
      ..style.fontFamily = 'monospace'
      ..text = 'IMPORT PROBE A1: OK (core + auth)',
  );
}
