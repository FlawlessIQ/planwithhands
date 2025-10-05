import 'package:flutter/widgets.dart';
import 'package:hands_app/services/session_manager.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:flutter/foundation.dart';

// Conditionally import dart:html for web to listen to user events safely
// ignore: avoid_web_libraries_in_flutter
import 'activity_tracker_stub.dart' if (dart.library.html) 'activity_tracker_web.dart';

/// Global activity tracker that monitors user interactions
/// and keeps sessions alive during active usage
class ActivityTracker {
  static final ActivityTracker _instance = ActivityTracker._internal();
  factory ActivityTracker() => _instance;
  ActivityTracker._internal();

  bool _isTracking = false;

  /// Initialize activity tracking
  void initialize() {
    if (_isTracking) return;

    _isTracking = true;
    logger.d('[ActivityTracker] Activity tracking initialized');

    // On web, subscribe to global user interaction and visibility events
    if (kIsWeb) {
      try {
        ActivityTrackerPlatformBindings.installGlobalWebListeners(
          onUserActivity: () {
            recordActivity(source: 'web_event');
          },
          onVisibilityGained: () {
            recordActivity(source: 'visibility_gained');
            // Also prompt a session validation on resume
            SessionManager().handleAppResume();
          },
        );
      } catch (e) {
        logger.w('[ActivityTracker] Failed to install web listeners: $e');
      }
    }
  }

  /// Record user activity - call this on any meaningful user interaction
  void recordActivity({String? source}) {
    if (!_isTracking) return;

    SessionManager().recordActivity();
    logger.d('[ActivityTracker] Activity recorded from: ${source ?? "unknown"}');
  }

  /// Dispose activity tracking
  void dispose() {
    _isTracking = false;
    logger.d('[ActivityTracker] Activity tracking disposed');

    if (kIsWeb) {
      try {
        ActivityTrackerPlatformBindings.removeGlobalWebListeners();
      } catch (_) {}
    }
  }
}

/// Mixin for widgets that want to automatically track user activity
mixin ActivityTrackingMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    // Record activity when widget initializes (user navigated to this screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ActivityTracker().recordActivity(source: widget.runtimeType.toString());
    });
  }
}

/// Widget wrapper that tracks tap activity
class ActivityTrackingWrapper extends StatelessWidget {
  final Widget child;
  final String? source;
  final VoidCallback? onTap;

  const ActivityTrackingWrapper({super.key, required this.child, this.source, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ActivityTracker().recordActivity(source: source ?? 'tap');
        onTap?.call();
      },
      onPanStart: (_) => ActivityTracker().recordActivity(source: source ?? 'pan'),
      onScaleStart: (_) => ActivityTracker().recordActivity(source: source ?? 'scale'),
      child: child,
    );
  }
}

/// Extension to add activity tracking to common widgets
extension ActivityTrackingExtension on Widget {
  Widget trackActivity({String? source}) {
    return ActivityTrackingWrapper(source: source, child: this);
  }
}
