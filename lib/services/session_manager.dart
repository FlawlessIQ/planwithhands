import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/services/web_optimized_firestore_service.dart';

/// Session manager that handles Firebase Auth token validation and refresh
/// Ensures users stay authenticated with valid tokens for optimal app functionality
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _sessionCheckTimer;
  DateTime? _lastTokenRefresh;
  
  // Configuration constants
  static const Duration _sessionCheckInterval = Duration(minutes: 15);
  static const Duration _tokenRefreshCooldown = Duration(minutes: 5);
  
  bool _isInitialized = false;
  StreamSubscription<User?>? _authStateSubscription;

  /// Initialize session management
  /// Should be called once during app startup
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    logger.d('[SessionManager] Initializing session management');
    
    // Listen to auth state changes
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _startSessionMonitoring();
      } else {
        _stopSessionMonitoring();
      }
    });
    
    // If user is already signed in, start monitoring
    if (_auth.currentUser != null) {
      await _validateCurrentSession();
      _startSessionMonitoring();
    }
    
    _isInitialized = true;
    logger.d('[SessionManager] Session management initialized');
  }

  /// Start periodic session monitoring
  void _startSessionMonitoring() {
    _stopSessionMonitoring(); // Ensure no duplicate timers
    
    _sessionCheckTimer = Timer.periodic(_sessionCheckInterval, (timer) async {
      await _validateCurrentSession();
    });
    
    logger.d('[SessionManager] Started session monitoring');
  }

  /// Stop session monitoring
  void _stopSessionMonitoring() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = null;
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
      // Check if we should refresh the token
      if (_shouldRefreshToken()) {
        logger.d('[SessionManager] Refreshing auth token');
        
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
          logger.d('[SessionManager] Current token is valid');
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
    
    final result = await validateSession();
    if (!result.isValid) {
      logger.w('[SessionManager] Session invalid on app resume: ${result.message}');
      
      // Clear any cached data that might be stale
      WebOptimizedFirestoreService.clearCache();
      
      // Don't force logout immediately - let the user try to use the app
      // The auth controller and other services will handle the invalid state
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

enum SessionValidationStatus {
  valid,
  invalid,
  notAuthenticated,
  networkError,
}