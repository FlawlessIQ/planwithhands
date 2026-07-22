// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// import-only

void main() {
  final pre = html.PreElement()
    ..style.whiteSpace = 'pre-wrap'
    ..style.fontFamily = 'monospace'
    ..text = 'IMPORT PROBE B: OK (firebase_messaging_web imported)';
  html.document.body?.append(pre);
}
