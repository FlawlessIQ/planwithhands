import 'package:flutter/foundation.dart';

// Platform-safe utilities
class PlatformUtils {
  // Web-safe file operations stub
  static dynamic createFile(String path) {
    if (kIsWeb) {
      throw UnsupportedError('File operations not supported on web');
    }
    // This will only be called on non-web platforms where dart:io is available
    return null; // Implementation should be done in calling code with proper imports
  }

  // Web-safe HTTP client stub  
  static dynamic createHttpClient() {
    if (kIsWeb) {
      throw UnsupportedError('HttpClient not supported on web');
    }
    // This will only be called on non-web platforms where dart:io is available
    return null; // Implementation should be done in calling code with proper imports
  }
}
