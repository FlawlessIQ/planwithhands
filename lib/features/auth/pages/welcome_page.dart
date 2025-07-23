import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  final String? email;
  final String? organizationId;
  final String? organizationName;

  const WelcomePage({
    super.key,
    this.email,
    this.organizationId,
    this.organizationName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Hands')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Welcome to Hands${organizationName != null ? ' at $organizationName' : ''}!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (email != null)
                Text(
                  'Hi, $email!',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              const SizedBox(height: 16),
              const Text(
                'You’re almost ready!\n\nWe’ve sent you a welcome email with a link to set your password.\n\nPlease check your inbox and follow the link to set your password and activate your Hands account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Open App Store
                      // You can use url_launcher here
                    },
                    icon: const Icon(Icons.apple),
                    label: const Text('App Store'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Open Play Store
                      // You can use url_launcher here
                    },
                    icon: const Icon(Icons.android),
                    label: const Text('Play Store'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
