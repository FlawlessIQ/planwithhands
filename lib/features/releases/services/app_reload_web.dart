// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> reloadCurrentApp() async {
  html.window.location.reload();
}
