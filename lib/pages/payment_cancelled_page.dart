import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';

class PaymentCancelledPage extends StatelessWidget {
  const PaymentCancelledPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cancel,
                color: Colors.orange,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Payment Cancelled',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your payment was cancelled. You can try again or contact support if you need assistance.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  context.go(AppRoutes.loginPage.path);
                },
                child: const Text('Back to Login'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // You could add logic here to retry payment
                  context.go(AppRoutes.accountCreationPage.path);
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}