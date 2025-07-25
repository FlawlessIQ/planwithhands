import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/routing/routes.dart';
import 'dart:developer';
import 'package:hands_app/utils/firestore_enforcer.dart';

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({super.key});

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  bool _isLoading = true;
  bool _subscriptionActive = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get user's organization ID
      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDoc.exists) {
        setState(() {
          _errorMessage = 'User data not found';
          _isLoading = false;
        });
        return;
      }

      final orgId = userDoc.data()?['organizationId'] as String?;
      if (orgId == null) {
        setState(() {
          _errorMessage = 'No organization associated with user';
          _isLoading = false;
        });
        return;
      }

      // Check organization subscription status
      final orgDoc =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .get();

      if (!orgDoc.exists) {
        setState(() {
          _errorMessage = 'Organization not found';
          _isLoading = false;
        });
        return;
      }

      final subscriptionStatus =
          orgDoc.data()?['subscriptionStatus'] as String? ?? 'pending';

      log('Subscription status: $subscriptionStatus');

      if (subscriptionStatus == 'active' || subscriptionStatus == 'trialing') {
        setState(() {
          _subscriptionActive = true;
          _isLoading = false;
        });

        // Auto-navigate to admin dashboard after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            context.go(AppRoutes.adminDashboardPage.path);
          }
        });
      } else {
        // If not active yet, keep checking (webhook might still be processing)
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isLoading) {
            _checkSubscriptionStatus();
          }
        });
      }
    } catch (e) {
      log('Error checking subscription status: $e');
      setState(() {
        _errorMessage = 'Error verifying subscription: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Verifying your subscription...',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'This may take a few moments while we confirm your payment.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ] else if (_subscriptionActive) ...[
                Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 24),
                Text(
                  'Payment Successful!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your subscription is now active. Redirecting to your dashboard...',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    context.go(AppRoutes.adminDashboardPage.path);
                  },
                  child: const Text('Go to Dashboard'),
                ),
              ] else if (_errorMessage != null) ...[
                Icon(Icons.error, color: Colors.red, size: 80),
                const SizedBox(height: 24),
                Text(
                  'Verification Error',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _checkSubscriptionStatus();
                  },
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    context.go(AppRoutes.loginPage.path);
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
