// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ActivityTrackerPlatformBindings {
  static html.EventListener? _activityListener;
  static html.EventListener? _visibilityListener;
  static DateTime? _lastActivityAt;

  static void installGlobalWebListeners({void Function()? onUserActivity, void Function()? onVisibilityGained}) {
    // Avoid double-registration
    removeGlobalWebListeners();

    // Throttle activity callback to once per 5 seconds to reduce churn
    void safeActivity() {
      final now = DateTime.now();
      if (_lastActivityAt == null || now.difference(_lastActivityAt!).inSeconds >= 5) {
        _lastActivityAt = now;
        onUserActivity?.call();
      }
    }

    _activityListener = (event) => safeActivity();
    _visibilityListener = (event) {
      final hidden = html.document.hidden ?? false;
      if (!hidden) {
        onVisibilityGained?.call();
      }
    };

    html.window.addEventListener('mousemove', _activityListener);
    html.window.addEventListener('mousedown', _activityListener);
    html.window.addEventListener('keydown', _activityListener);
    html.window.addEventListener('touchstart', _activityListener);
    html.window.addEventListener('scroll', _activityListener, true);
    html.document.addEventListener('visibilitychange', _visibilityListener);
  }

  static void removeGlobalWebListeners() {
    if (_activityListener != null) {
      html.window.removeEventListener('mousemove', _activityListener);
      html.window.removeEventListener('mousedown', _activityListener);
      html.window.removeEventListener('keydown', _activityListener);
      html.window.removeEventListener('touchstart', _activityListener);
      html.window.removeEventListener('scroll', _activityListener, true);
      _activityListener = null;
    }
    if (_visibilityListener != null) {
      html.document.removeEventListener('visibilitychange', _visibilityListener);
      _visibilityListener = null;
    }
  }
}
