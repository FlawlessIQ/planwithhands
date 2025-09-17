import 'package:flutter/material.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void main() {
  runApp(const StripeTestApp());
}

class StripeTestApp extends StatelessWidget {
  const StripeTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Stripe Elements Test')),
        body: const Center(child: StripeTestWidget()),
      ),
    );
  }
}

class StripeTestWidget extends StatefulWidget {
  const StripeTestWidget({super.key});

  @override
  State<StripeTestWidget> createState() => _StripeTestWidgetState();
}

class _StripeTestWidgetState extends State<StripeTestWidget> {
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _testStripeInitialization();
  }

  Future<void> _testStripeInitialization() async {
    try {
      setState(() => _status = 'Waiting for Stripe.js...');

      // Wait for Stripe.js to be available
      await _waitForStripe();

      setState(() => _status = 'Stripe.js available, initializing...');

      // Initialize Stripe
      final stripeConstructor = globalContext['Stripe'] as JSFunction;
      final stripe =
          stripeConstructor
                  .callAsConstructor(
                    'pk_test_51Ro44jFzroJ5o7DAeL4Lr7vGqm4BoOEG3T4kjTf8hfF5EUZC3zCdF1qZU8r3a6nFhFoXqZzEbUveDYgQ2A6Tx8qF00Q4D9fGNh'
                        .toJS,
                  )
                  .dartify()
              as JSObject;

      setState(() => _status = 'Stripe initialized successfully!');

      // Create Elements instance
      final elements = stripe.callMethod('elements'.toJS).dartify() as JSObject;

      setState(() => _status = 'Elements created successfully!');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _waitForStripe() async {
    const maxAttempts = 50;
    const delayMs = 100;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final stripe = globalContext['Stripe'];
        if (stripe != null) {
          return;
        }
      } catch (e) {
        // Stripe not available yet
      }

      await Future.delayed(Duration(milliseconds: delayMs));
    }

    throw Exception('Stripe.js failed to load within timeout');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _testStripeInitialization, child: const Text('Test Again')),
      ],
    );
  }
}
