import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// Conditional import for web-specific functionality
import 'local_storage_service_stub.dart' if (dart.library.html) 'local_storage_service_web.dart';

class LocalStorageService {
  static SharedPreferences? _preferences;

  static Future<void> init() async {
    if (kIsWeb) {
      try {
        // Probe IndexedDB availability by trying to open a dummy database.
        // This will fail in environments where IndexedDB is disabled, like Safari private mode.
        await probeIndexedDB();
      } catch (e) {
        // If it fails, log the error and, most importantly, return without
        // trying to initialize SharedPreferences.
        print('IndexedDB is not available. Skipping SharedPreferences init. Error: $e');
        return;
      }
    }
    // If not on web or if IndexedDB is available, proceed with initialization.
    _preferences = await SharedPreferences.getInstance();
  }

  static Future<void> saveString(String key, String value) async {
    await _preferences?.setString(key, value);
  }

  static String? getString(String key) {
    return _preferences?.getString(key);
  }

  static Future<void> saveInt(String key, int value) async {
    await _preferences?.setInt(key, value);
  }

  static int? getInt(String key) {
    return _preferences?.getInt(key);
  }
}
