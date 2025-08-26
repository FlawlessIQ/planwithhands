// Stub for platforms without dart:io (web)
bool get nativeIsMacOS => false;

Future<List<int>> nativeReadFileBytes(String path) async {
  throw UnsupportedError('native IO not available on this platform');
}

Future<String?> nativeWriteTempFile(List<int> bytes) async {
  throw UnsupportedError('native IO not available on this platform');
}
