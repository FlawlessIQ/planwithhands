import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/shared/components/shared_components.dart';

/// Utility class for handling session-related errors in UI components
/// Provides graceful handling when tokens expire or become invalid
class SessionErrorHandler {
  /// Handle errors that might indicate session expiration
  /// Returns true if the error was a session-related error and was handled
  static bool handleError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onSessionExpired,
  }) {
    final errorString = error.toString().toLowerCase();

    // Check for various authentication-related error patterns
    final isSessionError =
        errorString.contains('unauthenticated') ||
        errorString.contains('permission-denied') ||
        errorString.contains('session expired') ||
        errorString.contains('token') ||
        errorString.contains('auth');

    if (isSessionError) {
      logger.w('[SessionErrorHandler] Session error detected: $error');

      // Show user-friendly message
      _showSessionExpiredDialog(context, onSessionExpired);
      return true;
    }

    return false;
  }

  /// Show a dialog informing the user their session has expired
  static void _showSessionExpiredDialog(
    BuildContext context,
    VoidCallback? onSessionExpired,
  ) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return HandsDialog(
          title: 'Session Expired',
          isDismissible: false,
          maxWidth: 440,
          actions: [
            HandsPrimaryButton(
              text: 'Sign In',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onSessionExpired?.call();

                // Navigate to login page
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
          child: Text(
            'Your session has expired for security reasons. Please sign in again to continue.',
            style: HandsModalTokens.bodyStyle,
          ),
        );
      },
    );
  }

  /// Wrapper function for async operations that might fail due to session expiration
  /// Automatically handles session errors and shows appropriate UI
  static Future<T?> executeWithSessionHandling<T>(
    BuildContext context,
    Future<T> Function() operation, {
    VoidCallback? onSessionExpired,
    bool showLoadingIndicator = false,
  }) async {
    try {
      if (showLoadingIndicator && context.mounted) {
        // Show loading indicator for longer operations
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return const Center(child: CircularProgressIndicator());
          },
        );
      }

      final result = await operation();

      if (showLoadingIndicator && context.mounted) {
        Navigator.of(context).pop(); // Close loading indicator
      }

      return result;
    } catch (error) {
      if (showLoadingIndicator && context.mounted) {
        Navigator.of(context).pop(); // Close loading indicator
      }

      if (handleError(context, error, onSessionExpired: onSessionExpired)) {
        return null; // Session error was handled
      }

      // Re-throw non-session errors
      rethrow;
    }
  }

  /// Check if an error appears to be session-related
  static bool isSessionError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    return errorString.contains('unauthenticated') ||
        errorString.contains('permission-denied') ||
        errorString.contains('session expired') ||
        errorString.contains('token') ||
        errorString.contains('auth');
  }
}
