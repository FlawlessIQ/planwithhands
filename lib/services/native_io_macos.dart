import 'dart:io';

bool get nativeIsMacOS => Platform.isMacOS;

Future<List<int>> nativeReadFileBytes(String path) async {
  final file = File(path);
  return await file.readAsBytes();
}

Future<String?> nativeWriteTempFile(List<int> bytes) async {
  final dir = Directory.systemTemp;
  final file = await File('${dir.path}/hands_temp_${DateTime.now().millisecondsSinceEpoch}.jpg').create();
  await file.writeAsBytes(bytes);
  return file.path;
}
