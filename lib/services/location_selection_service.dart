import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global service to persist the user's currently selected location
/// across navigation and app restarts. Uses SharedPreferences for persistence.
class LocationSelectionService {
  LocationSelectionService._();
  static final LocationSelectionService instance = LocationSelectionService._();

  static const String _preferenceKey = 'selected_location_id';

  /// Persists to SharedPreferences for cross-session persistence
  final ValueNotifier<String?> _currentLocationId = ValueNotifier<String?>(null);

  ValueListenable<String?> get listenable => _currentLocationId;
  String? get currentLocationId => _currentLocationId.value;

  /// Initialize by loading saved location from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocationId = prefs.getString(_preferenceKey);
      if (savedLocationId != null && savedLocationId.isNotEmpty) {
        _currentLocationId.value = savedLocationId;
      }
    } catch (e) {
      // Ignore errors during initialization, just use null
    }
  }

  void setLocation(String? locationId) {
    if (_currentLocationId.value == locationId) return;

    _currentLocationId.value = locationId;

    // Persist to SharedPreferences asynchronously (fire and forget)
    _persistToSharedPreferences(locationId);
  }

  Future<void> setLocationAsync(String? locationId) async {
    if (_currentLocationId.value == locationId) return;

    _currentLocationId.value = locationId;

    // Persist to SharedPreferences and wait
    await _persistToSharedPreferences(locationId);
  }

  Future<void> _persistToSharedPreferences(String? locationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locationId != null && locationId.isNotEmpty) {
        await prefs.setString(_preferenceKey, locationId);
      } else {
        await prefs.remove(_preferenceKey);
      }
    } catch (e) {
      // Log but don't fail if SharedPreferences isn't available
      debugPrint('Failed to persist location selection: $e');
    }
  }

  /// Clear the saved location (useful for logout)
  Future<void> clearLocation() async {
    await setLocationAsync(null);
  }
}
