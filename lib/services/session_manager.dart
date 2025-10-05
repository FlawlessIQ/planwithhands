import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/services/web_optimized_firestore_service.dart';
import 'package:hands_app/services/session_notification_service.dart';
import 'package:hands_app/services/local_storage_service.dart';

/// Session manager that handles Firebase Auth token validation and refresh
/// Ensures users stay authenticated with valid tokens for optimal app functionality
/// Includes configurable session timeout with activity-based renewal
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _sessionCheckTimer;
  Timer? _sessionTimeoutTimer;
  DateTime? _lastTokenRefresh;
  DateTime? _lastActivity;

  // Configuration constants
  static const Duration _sessionCheckInterval = Duration(minutes: 15);
  static const Duration _tokenRefreshCooldown = Duration(minutes: 5);

  // Session timeout options
  static const Map<String, Duration> sessionTimeoutOptions = {
    '2_hours': Duration(hours: 2),
    '4_hours': Duration(hours: 4),
    '8_hours': Duration(hours: 8),
    '24_hours': Duration(hours: 24),
  };

  // Default session timeout (auto-logout after 2 hours of inactivity)
  static const Duration _defaultSessionTimeout = Duration(hours: 2);

  // Callbacks for session events
  VoidCallback? _onSessionExpired;
  VoidCallback? _onSessionWarning;

  // Session timeout preference (in-memory for now)
  String _sessionTimeoutKey = '2_hours';

  bool _isInitialized = false;
  StreamSubscription<User?>? _authStateSubscription;

  /// Initialize session management
  /// Should be called once during app startup
  Future<void> initialize() async {
    if (_isInitialized) return;

    logger.d('[SessionManager] Initializing session management');

    // Load last activity from local storage (to survive web refresh)
    try {
      final stored = LocalStorageService.getString('session_last_activity_at');
      if (stored != null && stored.isNotEmpty) {
        _lastActivity = DateTime.tryParse(stored);
        logger.d('[SessionManager] Restored last activity from storage: $_lastActivity');
      }
    } catch (e) {
      logger.w('[SessionManager] Failed to restore last activity: $e');
    }

    // Listen to auth state changes
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _startSessionMonitoring();
        _recordActivity(); // Mark login as activity
      } else {
        _stopSessionMonitoring();
      }
    });

    // If user is already signed in, start monitoring
    if (_auth.currentUser != null) {
      // Check if session expired based on last activity and timeout
      final now = DateTime.now();
      if (_lastActivity != null) {
        final timeoutDuration = _getSessionTimeout();
        final elapsed = now.difference(_lastActivity!);
        if (elapsed >= timeoutDuration) {
          logger.w('[SessionManager] Session expired on app launch, logging out');
          SessionNotificationService().showSessionTimeoutNotification();
          await _forceLogout();
          _isInitialized = true;
          return;
        }
      }
      await _validateCurrentSession();
      _startSessionMonitoring();
      _recordActivity(); // Mark app startup as activity
    }

    _isInitialized = true;
    logger.d('[SessionManager] Session management initialized');
  }

  /// Record user activity to reset session timeout
  void _recordActivity() {
    _lastActivity = DateTime.now();
    // Persist to local storage so refresh respects inactivity window
    try {
      LocalStorageService.saveString('session_last_activity_at', _lastActivity!.toIso8601String());
    } catch (_) {}
    _resetSessionTimeout();
    logger.d('[SessionManager] Activity recorded, session timeout reset');
  }

  /// Record user activity (public method for app-wide usage)
  void recordActivity() {
    if (!_isInitialized || _auth.currentUser == null) return;
    _recordActivity();
  }

  /// Get current session timeout duration
  Duration _getSessionTimeout() {
    return sessionTimeoutOptions[_sessionTimeoutKey] ?? _defaultSessionTimeout;
  }

  /// Set session timeout preference
  void setSessionTimeout(String timeoutKey) {
    if (!sessionTimeoutOptions.containsKey(timeoutKey)) {
      logger.w('[SessionManager] Invalid timeout key: $timeoutKey');
      return;
    }

    _sessionTimeoutKey = timeoutKey;
    logger.d('[SessionManager] Session timeout set to: $timeoutKey');

    // Reset current timeout timer with new duration
    if (_auth.currentUser != null) {
      _resetSessionTimeout();
    }
  }

  /// Reset session timeout timer
  void _resetSessionTimeout() {
    _sessionTimeoutTimer?.cancel();

    final timeoutDuration = _getSessionTimeout();
    _sessionTimeoutTimer = Timer(timeoutDuration, () {
      _handleSessionTimeout();
    });

    // Set up warning timer (30 minutes before expiration)
    final warningTime = timeoutDuration - const Duration(minutes: 30);
    if (warningTime.isNegative == false && warningTime.inMinutes > 0) {
      Timer(warningTime, () {
        _handleSessionWarning();
      });
    }

    logger.d('[SessionManager] Session timeout reset to ${timeoutDuration.inHours} hours');
  }

  /// Handle session warning (30 minutes before timeout)
  void _handleSessionWarning() {
    final remaining = timeUntilTimeout;
    if (remaining != null && remaining.inMinutes > 0) {
      logger.d('[SessionManager] Showing session warning: ${remaining.inMinutes} minutes remaining');

      // Show warning notification
      SessionNotificationService().showSessionWarning(timeRemaining: remaining);

      // Call warning callback if set
      _onSessionWarning?.call();
    }
  }

  /// Handle session timeout expiration
  void _handleSessionTimeout() {
    logger.w('[SessionManager] Session timeout expired, logging out user');

    // Show timeout notification
    SessionNotificationService().showSessionTimeoutNotification();

    // Call timeout callback if set
    _onSessionExpired?.call();

    // Force logout after a brief delay to allow notification to show
    Timer(const Duration(milliseconds: 500), () {
      _forceLogout();
    });
  }

  /// Force logout and cleanup
  Future<void> _forceLogout() async {
    try {
      await _auth.signOut();
      _stopSessionMonitoring();
      WebOptimizedFirestoreService.clearCache();
      logger.d('[SessionManager] Force logout completed');
    } catch (e) {
      logger.e('[SessionManager] Error during force logout: $e');
    }
  }

  /// Set callback for session expiration
  void setSessionExpiredCallback(VoidCallback callback) {
    _onSessionExpired = callback;
  }

  /// Set callback for session warning (e.g., 30 minutes before expiration)
  void setSessionWarningCallback(VoidCallback callback) {
    _onSessionWarning = callback;
  }

  /// Start periodic session monitoring
  void _startSessionMonitoring() {
    _stopSessionMonitoring(); // Ensure no duplicate timers

    _sessionCheckTimer = Timer.periodic(_sessionCheckInterval, (timer) async {
      await _validateCurrentSession();
    });

    // Start session timeout timer
    _resetSessionTimeout();

    logger.d('[SessionManager] Started session monitoring');
  }

  /// Stop session monitoring
  void _stopSessionMonitoring() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = null;
    _sessionTimeoutTimer?.cancel();
    _sessionTimeoutTimer = null;
    logger.d('[SessionManager] Stopped session monitoring');
  }

  /// Validate current session and refresh token if needed
  /// Returns true if session is valid, false if user needs to re-authenticate
  Future<bool> _validateCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      logger.d('[SessionManager] No current user - session invalid');
      return false;
    }

    try {
      // Check if there was a long period of inactivity
      final inactiveDuration =
          _lastActivity != null
              ? DateTime.now().difference(_lastActivity!)
              : const Duration(hours: 999); // Assume very long if no activity recorded

      // Force refresh after 1+ hour of inactivity OR if cooldown expired
      final shouldForceRefresh = inactiveDuration >= const Duration(hours: 1) || _shouldRefreshToken();

      if (shouldForceRefresh) {
        logger.d(
          '[SessionManager] Refreshing auth token (inactive: ${inactiveDuration.inHours}h ${inactiveDuration.inMinutes.remainder(60)}m, last refresh: ${_lastTokenRefresh != null ? DateTime.now().difference(_lastTokenRefresh!).inMinutes : "never"}m ago)',
        );

        // Force token refresh
        final token = await user.getIdToken(true);
        if (token != null && token.isNotEmpty) {
          _lastTokenRefresh = DateTime.now();
          logger.d('[SessionManager] Token refreshed successfully');
          return true;
        }
      } else {
        // Just validate the current token
        final token = await user.getIdToken(false);
        if (token != null && token.isNotEmpty) {
          logger.d('[SessionManager] Current token is valid (inactive: ${inactiveDuration.inMinutes}m)');
          return true;
        }
      }
    } catch (e) {
      logger.w('[SessionManager] Token validation/refresh failed: $e');

      // If token refresh fails, the user might need to re-authenticate
      // However, we don't force logout immediately - let the app handle this gracefully
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        // Network issues - don't invalidate session
        logger.d('[SessionManager] Network issue detected, keeping session valid');
        return true;
      }

      // Token might be genuinely invalid
      logger.w('[SessionManager] Session appears invalid, may need re-authentication');
      return false;
    }

    return false;
  }

  /// Check if token should be refreshed based on cooldown
  bool _shouldRefreshToken() {
    if (_lastTokenRefresh == null) return true;

    final timeSinceRefresh = DateTime.now().difference(_lastTokenRefresh!);
    return timeSinceRefresh >= _tokenRefreshCooldown;
  }

  /// Manually validate session (can be called by app lifecycle events)
  /// Returns SessionValidationResult with detailed status
  Future<SessionValidationResult> validateSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      return SessionValidationResult.notAuthenticated();
    }

    try {
      // Try to get a fresh token to ensure user is still valid
      final token = await user.getIdToken(true);
      if (token != null && token.isNotEmpty) {
        _lastTokenRefresh = DateTime.now();
        logger.d('[SessionManager] Manual session validation successful');
        return SessionValidationResult.valid();
      } else {
        logger.w('[SessionManager] Manual session validation failed - empty token');
        return SessionValidationResult.invalid('Empty authentication token');
      }
    } catch (e) {
      logger.w('[SessionManager] Manual session validation failed: $e');

      if (e.toString().contains('network')) {
        return SessionValidationResult.networkError(e.toString());
      }

      return SessionValidationResult.invalid(e.toString());
    }
  }

  /// Handle app resume - validate session when app comes back from background
  Future<void> handleAppResume() async {
    logger.d('[SessionManager] Handling app resume');

    // Record activity on app resume
    _recordActivity();

    final result = await validateSession();
    if (!result.isValid) {
      logger.w('[SessionManager] Session invalid on app resume: ${result.message}');

      // Clear any cached data that might be stale
      WebOptimizedFirestoreService.clearCache();

      // If session is truly invalid (not just network), consider logout
      if (result.status == SessionValidationStatus.invalid) {
        logger.w('[SessionManager] Session validation failed, may need logout');
        // Let the UI handle this gracefully rather than forcing immediate logout
      }
    }
  }

  /// Clean up resources
  void dispose() {
    logger.d('[SessionManager] Disposing session manager');
    _stopSessionMonitoring();
    _authStateSubscription?.cancel();
    _isInitialized = false;
  }

  /// Check if session manager is actively monitoring
  bool get isMonitoring => _sessionCheckTimer?.isActive ?? false;

  /// Get last token refresh time (for debugging)
  DateTime? get lastTokenRefresh => _lastTokenRefresh;

  /// Get last activity time
  DateTime? get lastActivity => _lastActivity;

  /// Get current session timeout setting
  String get currentTimeoutSetting => _sessionTimeoutKey;

  /// Get time remaining until session timeout (null if not authenticated)
  Duration? get timeUntilTimeout {
    if (_lastActivity == null || _auth.currentUser == null) return null;

    final timeoutDuration = _getSessionTimeout();
    final elapsed = DateTime.now().difference(_lastActivity!);
    final remaining = timeoutDuration - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Check if session is about to expire (within 30 minutes)
  bool get isSessionNearExpiry {
    final remaining = timeUntilTimeout;
    return remaining != null && remaining.inMinutes <= 30;
  }
}

/// Result of session validation with detailed status
class SessionValidationResult {
  final bool isValid;
  final String? message;
  final SessionValidationStatus status;

  const SessionValidationResult._(this.isValid, this.message, this.status);

  factory SessionValidationResult.valid() {
    return const SessionValidationResult._(true, null, SessionValidationStatus.valid);
  }

  factory SessionValidationResult.invalid(String message) {
    return SessionValidationResult._(false, message, SessionValidationStatus.invalid);
  }

  factory SessionValidationResult.notAuthenticated() {
    return const SessionValidationResult._(false, 'User not authenticated', SessionValidationStatus.notAuthenticated);
  }

  factory SessionValidationResult.networkError(String message) {
    return SessionValidationResult._(false, message, SessionValidationStatus.networkError);
  }
}

enum SessionValidationStatus { valid, invalid, notAuthenticated, networkError }
