// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void main() {
  final pre =
      html.PreElement()
        ..style.whiteSpace = 'pre-wrap'
        ..style.fontFamily = 'monospace'
        ..text = 'IMPORT PROBE A: OK (core firebase web imports)';
  html.document.body?.append(pre);
}
