import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global service to persist the user's currently selected location
/// across navigation and app restarts. Uses SharedPreferences for persistence.
class LocationSelectionService {
  LocationSelectionService._();
  static final LocationSelectionService instance = LocationSelectionService._();

  static const String _preferenceKey = 'selected_location_id';
  static const String _preferenceNameKey = 'selected_location_name';

  /// Persists to SharedPreferences for cross-session persistence
  final ValueNotifier<String?> _currentLocationId = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _currentLocationName = ValueNotifier<String?>(null);
  // Monotonic session counter: increments every time the location changes.
  // Useful to ignore stale async/stream updates from a previous location.
  final ValueNotifier<int> _session = ValueNotifier<int>(0);

  ValueListenable<String?> get listenable => _currentLocationId;
  ValueListenable<String?> get nameListenable => _currentLocationName;
  String? get currentLocationId => _currentLocationId.value;
  String? get currentLocationName => _currentLocationName.value;
  ValueListenable<int> get sessionListenable => _session;
  int get session => _session.value;

  /// Initialize by loading saved location from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocationId = prefs.getString(_preferenceKey);
      final savedLocationName = prefs.getString(_preferenceNameKey);
      if (savedLocationId != null && savedLocationId.isNotEmpty) {
        _currentLocationId.value = savedLocationId;
        _currentLocationName.value = savedLocationName; // May be null for legacy data
      }
    } catch (e) {
      // Ignore errors during initialization, just use null
    }
  }

  void setLocation(String? locationId, {String? locationName}) {
    if (_currentLocationId.value == locationId) return;

    debugPrint('[LocationService] 🚀 SETTING LOCATION: ${_currentLocationId.value} → $locationId');
    _currentLocationId.value = locationId;
    _currentLocationName.value = locationName;
    _session.value = _session.value + 1;
    debugPrint('[LocationService] 🚀 ValueNotifier updated, triggering listeners');

    // Persist to SharedPreferences asynchronously (fire and forget)
    _persistToSharedPreferences(locationId, locationName);
  }

  Future<void> setLocationAsync(String? locationId, {String? locationName}) async {
    if (_currentLocationId.value == locationId) return;

    debugPrint('[LocationService] 🚀 SETTING LOCATION ASYNC: ${_currentLocationId.value} → $locationId');
    _currentLocationId.value = locationId;
    _currentLocationName.value = locationName;
    _session.value = _session.value + 1;
    debugPrint('[LocationService] 🚀 ValueNotifier updated, triggering listeners');

    // Persist to SharedPreferences and wait
    await _persistToSharedPreferences(locationId, locationName);
  }

  Future<void> _persistToSharedPreferences(String? locationId, String? locationName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locationId != null && locationId.isNotEmpty) {
        await prefs.setString(_preferenceKey, locationId);
        if (locationName != null && locationName.isNotEmpty) {
          await prefs.setString(_preferenceNameKey, locationName);
        } else {
          await prefs.remove(_preferenceNameKey);
        }
      } else {
        await prefs.remove(_preferenceKey);
        await prefs.remove(_preferenceNameKey);
      }
    } catch (e) {
      // Log but don't fail if SharedPreferences isn't available
      debugPrint('Failed to persist location selection: $e');
    }
  }

  /// Clear the saved location (useful for logout)
  Future<void> clearLocation() async {
    await setLocationAsync(null, locationName: null);
  }
}
