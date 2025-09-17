import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeProbePage extends StatefulWidget {
  const StripeProbePage({super.key});

  @override
  State<StripeProbePage> createState() => _StripeProbePageState();
}

class _StripeProbePageState extends State<StripeProbePage> {
  bool _complete = false;
  String _pk = '';

  @override
  void initState() {
    super.initState();
    // Try to read the publishable key (may be empty if not initialized yet)
    try {
      _pk = Stripe.publishableKey;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stripe Probe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Publishable key set: ${_pk.isNotEmpty}'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: CardField(onCardChanged: (d) => setState(() => _complete = d?.complete ?? false)),
            ),
            const SizedBox(height: 12),
            Text('Card complete: $_complete'),
          ],
        ),
      ),
    );
  }
}
