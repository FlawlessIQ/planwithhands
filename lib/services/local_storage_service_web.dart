import 'dart:html' as html;

Future<void> probeIndexedDB() async {
  final indexedDB = html.window.indexedDB;
  if (indexedDB == null) {
    throw Exception('IndexedDB is not supported in this environment');
  }
  await indexedDB.open('test');
}
