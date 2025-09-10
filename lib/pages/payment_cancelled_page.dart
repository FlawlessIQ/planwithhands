import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/config/feature_flags.dart';

class PaymentCancelledPage extends StatefulWidget {
  const PaymentCancelledPage({super.key});

  @override
  State<PaymentCancelledPage> createState() => _PaymentCancelledPageState();
}

class _PaymentCancelledPageState extends State<PaymentCancelledPage> {
  bool _isLoading = false;
  String? _userEmail;
  String? _organizationId;
  int _locationCount = 1;
  final bool _isAnnual = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data();
      final orgId = userData?['organizationId'] as String?;

      if (orgId != null) {
        final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(orgId).get();
        if (orgDoc.exists) {
          final orgData = orgDoc.data();
          setState(() {
            _userEmail = user.email;
            _organizationId = orgId;
            _locationCount = (orgData?['locations'] as int?) ?? 1;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _retryPayment() async {
    if (_organizationId == null || _userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to retry payment. Please start from the account creation page.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await StripeService.startCheckoutAndLaunch(
        orgId: _organizationId!,
        email: _userEmail!,
        priceId: _isAnnual ? kStripePriceAnnual : kStripePriceMonthly,
        quantity: _locationCount,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting payment: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
              Icon(Icons.cancel, color: Colors.orange, size: 80),
              const SizedBox(height: 24),
              Text(
                'Payment Cancelled',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your payment was cancelled. No charges were made to your account.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Show retry option if we have user data
              if (_organizationId != null && _userEmail != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Ready to try again?',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'ve saved your account information. You can retry payment now or complete it later.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text('$_locationCount location${_locationCount == 1 ? '' : 's'}'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (!_isLoading) ...[
                          FilledButton.icon(
                            onPressed: _retryPayment,
                            icon: const Icon(Icons.credit_card),
                            label: const Text('Try Payment Again'),
                          ),
                        ] else ...[
                          const CircularProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              ElevatedButton(
                onPressed: () {
                  context.go(AppRoutes.loginPage.path);
                },
                child: const Text('Back to Login'),
              ),
              const SizedBox(height: 16),

              // iOS platform check: Only show "Start Over" button on web or non-iOS platforms
              if (kIsWeb || !Platform.isIOS) ...[
                TextButton(
                  onPressed: () {
                    context.go(AppRoutes.accountCreationPage.path);
                  },
                  child: const Text('Start Account Creation Over'),
                ),
              ] else ...[
                Text(
                  'To create an account, please visit planwithhands.com in Safari or Chrome.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
