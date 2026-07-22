import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/core/logging/logger.dart';

/// Service to handle session timeout notifications and graceful logout
class SessionNotificationService {
  static final SessionNotificationService _instance =
      SessionNotificationService._internal();
  factory SessionNotificationService() => _instance;
  SessionNotificationService._internal();

  BuildContext? _context;

  /// Set the current context for showing notifications
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Show session timeout notification with re-login option
  Future<void> showSessionTimeoutNotification() async {
    final context = _context;
    if (context == null) {
      logger.w(
        '[SessionNotificationService] No context available for timeout notification',
      );
      return;
    }

    // Don't show if already on login screen
    final currentLocation = GoRouterState.of(context).fullPath;
    if (currentLocation?.contains('/login') == true) {
      return;
    }

    logger.d(
      '[SessionNotificationService] Showing session timeout notification',
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false, // Prevent dismissing with back button
          child: HandsDialog(
            title: 'Session Expired',
            isDismissible: false,
            maxWidth: 480,
            actions: [
              HandsPrimaryButton(
                text: 'Sign In Again',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _navigateToLogin(context);
                },
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your session has expired due to inactivity. You\'ll need to sign in again to continue.',
                  style: HandsModalTokens.bodyStyle.copyWith(
                    color: HandsModalTokens.text,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HandsModalTokens.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      HandsModalTokens.compactControlRadius,
                    ),
                    border: Border.all(
                      color: HandsModalTokens.accent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: HandsModalTokens.accent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'You can adjust session timeout in Settings',
                          style: TextStyle(
                            color: HandsModalTokens.accent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Show session warning (e.g., 30 minutes before timeout)
  Future<void> showSessionWarning({required Duration timeRemaining}) async {
    final context = _context;
    if (context == null) {
      logger.w(
        '[SessionNotificationService] No context available for session warning',
      );
      return;
    }

    // Don't show if already on login screen
    final currentLocation = GoRouterState.of(context).fullPath;
    if (currentLocation?.contains('/login') == true) {
      return;
    }

    final minutesRemaining = timeRemaining.inMinutes;

    logger.d(
      '[SessionNotificationService] Showing session warning: $minutesRemaining minutes remaining',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.orange.withOpacity(0.9),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            Icon(Icons.timer, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Session expires in $minutesRemaining minutes. Tap anywhere to stay active.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Stay Active',
          textColor: Colors.white,
          onPressed: () {
            // This will be handled by activity tracking
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Navigate to login screen
  void _navigateToLogin(BuildContext context) {
    try {
      final router = GoRouter.of(context);
      router.go('/login');
      logger.d('[SessionNotificationService] Navigated to login screen');
    } catch (e) {
      logger.e('[SessionNotificationService] Failed to navigate to login: $e');
    }
  }

  /// Clear context when no longer needed
  void clearContext() {
    _context = null;
  }
}

/// Mixin for pages that want to handle session notifications
mixin SessionNotificationMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    // Set context for notifications when this widget is active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SessionNotificationService().setContext(context);
    });
  }

  @override
  void dispose() {
    // Clear context when this widget is disposed
    SessionNotificationService().clearContext();
    super.dispose();
  }
}
