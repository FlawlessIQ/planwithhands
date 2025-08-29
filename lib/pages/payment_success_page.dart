import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/routing/routes.dart';
import 'dart:developer';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/widgets/responsive_appbar_title.dart';

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({super.key});

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  bool _isLoading = true;
  bool _subscriptionActive = false;
  String? _errorMessage;
  int? _checkCount;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      debugPrint('[PaymentSuccessPage] Starting subscription status check...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[PaymentSuccessPage] ERROR: User not authenticated');
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      debugPrint('[PaymentSuccessPage] User authenticated: ${user.uid}');

      // Get user's organization ID
      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        debugPrint('[PaymentSuccessPage] ERROR: User document not found');
        setState(() {
          _errorMessage = 'User data not found';
          _isLoading = false;
        });
        return;
      }

      final userData = userDoc.data();
      debugPrint('[PaymentSuccessPage] User data: $userData');

      final orgId = userData?['organizationId'] as String?;
      if (orgId == null) {
        debugPrint('[PaymentSuccessPage] ERROR: No organization ID found');
        setState(() {
          _errorMessage = 'No organization associated with user';
          _isLoading = false;
        });
        return;
      }

      debugPrint('[PaymentSuccessPage] Organization ID: $orgId');

      // Check organization subscription status
      final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(orgId).get();

      if (!orgDoc.exists) {
        debugPrint('[PaymentSuccessPage] ERROR: Organization document not found');
        setState(() {
          _errorMessage = 'Organization not found';
          _isLoading = false;
        });
        return;
      }

      final orgData = orgDoc.data();
      debugPrint('[PaymentSuccessPage] Organization data: $orgData');

      final subscriptionStatus = orgData?['subscriptionStatus'] as String? ?? 'pending';

      debugPrint('[PaymentSuccessPage] Subscription status: $subscriptionStatus');

      if (subscriptionStatus == 'active' || subscriptionStatus == 'trialing') {
        debugPrint('[PaymentSuccessPage] Subscription is active! Redirecting...');
        setState(() {
          _subscriptionActive = true;
          _isLoading = false;
        });

        // Auto-navigate to admin dashboard after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            debugPrint('[PaymentSuccessPage] Navigating to admin dashboard');
            // Add a query parameter to indicate this is a new user setup
            context.go('${AppRoutes.adminDashboardPage.path}?setup=true');
          }
        });
      } else if (subscriptionStatus == 'trial') {
        // If status is trial and we're on the payment success page,
        // the payment was successful but webhook hasn't updated status yet.
        // Allow progression since user reached this page after successful Stripe payment.
        debugPrint('[PaymentSuccessPage] Payment successful - webhook still processing. Proceeding...');
        setState(() {
          _subscriptionActive = true;
          _isLoading = false;
        });

        // Auto-navigate to admin dashboard after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            debugPrint('[PaymentSuccessPage] Navigating to admin dashboard (payment confirmed)');
            // Add a query parameter to indicate this is a new user setup
            context.go('${AppRoutes.adminDashboardPage.path}?setup=true');
          }
        });
      } else {
        debugPrint('[PaymentSuccessPage] Subscription not active yet, checking again in 2 seconds...');
        // If not active yet, keep checking (webhook might still be processing)
        // But limit the number of retries to prevent infinite loop
        setState(() {
          _checkCount = (_checkCount ?? 0) + 1;
        });

        if ((_checkCount ?? 0) < 10) {
          // Max 10 retries (20 seconds)
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _isLoading) {
              _checkSubscriptionStatus();
            }
          });
        } else {
          debugPrint('[PaymentSuccessPage] Max retries reached. Showing manual option.');
          setState(() {
            _errorMessage =
                'Payment verification is taking longer than expected. The webhook may still be processing your payment.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[PaymentSuccessPage] ERROR: Exception occurred: $e');
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
      appBar: AppBar(
        title: const ResponsiveAppBarTitle('Payment Status'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'This may take a few moments while we confirm your payment with Stripe.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text('Taking too long?', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    debugPrint('[PaymentSuccessPage] Manual navigation to admin dashboard');
                    // Add a query parameter to indicate this is a new user setup
                    context.go('${AppRoutes.adminDashboardPage.path}?setup=true');
                  },
                  child: const Text('Continue to Dashboard'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _checkSubscriptionStatus();
                  },
                  child: const Text('Check Again'),
                ),
              ] else if (_subscriptionActive) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 24),
                Text(
                  'Payment Successful!',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your subscription is now active. Redirecting to your dashboard...',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    // Add a query parameter to indicate this is a new user setup
                    context.go('${AppRoutes.adminDashboardPage.path}?setup=true');
                  },
                  child: const Text('Go to Dashboard'),
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(Icons.error, color: Colors.red, size: 80),
                const SizedBox(height: 24),
                Text(
                  'Verification Issue',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(_errorMessage!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _checkSubscriptionStatus();
                  },
                  child: const Text('Try Again'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    debugPrint('[PaymentSuccessPage] Manual navigation to admin dashboard (from error state)');
                    // Add a query parameter to indicate this is a new user setup
                    context.go('${AppRoutes.adminDashboardPage.path}?setup=true');
                  },
                  child: const Text('Continue to Dashboard Anyway'),
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
