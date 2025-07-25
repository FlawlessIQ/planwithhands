import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/services/web_optimized_firestore_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Centralized logout function that ensures proper navigation
  static Future<void> signOut(BuildContext context) async {
    try {
      // Clear any local caches
      WebOptimizedFirestoreService.clearCache();

      // Sign out from Firebase
      await _auth.signOut();

      // Force navigation to login page
      if (context.mounted) {
        // Clear the entire navigation stack and go to login
        context.go('/login');

        // Additional navigation clearing as fallback
        Future.delayed(const Duration(milliseconds: 200), () {
          if (context.mounted) {
            // Try to clear any remaining routes
            while (context.canPop()) {
              context.pop();
            }
            // Ensure we're on login page
            context.go('/login');
          }
        });
      }
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  /// Centralized account deletion function
  static Future<void> deleteAccount(
    BuildContext context,
    String password,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user currently signed in');
      }

      // Re-authenticate user before deletion
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Clear any local caches
      WebOptimizedFirestoreService.clearCache();

      // Delete user document from Firestore first
      await FirestoreEnforcer.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Delete user authentication account
      await user.delete();

      // Force navigation to login page
      if (context.mounted) {
        context.go('/login');

        // Clear navigation stack
        Future.delayed(const Duration(milliseconds: 200), () {
          if (context.mounted) {
            while (context.canPop()) {
              context.pop();
            }
            context.go('/login');
          }
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user is currently signed in
  static bool get isSignedIn => _auth.currentUser != null;

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Listen to auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
