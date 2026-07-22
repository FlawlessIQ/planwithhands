import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hands_app/theme/theme.dart';

class StripeCardTestPage extends StatefulWidget {
  const StripeCardTestPage({super.key});

  @override
  State<StripeCardTestPage> createState() => _StripeCardTestPageState();
}

class _StripeCardTestPageState extends State<StripeCardTestPage> {
  CardFieldInputDetails? _card;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stripe Card Test')),
        body: const Center(child: Text('This test is only available on web platform.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stripe Card Test'),
        backgroundColor: HandsColors.scaffoldBackground,
        foregroundColor: HandsColors.white,
      ),
      backgroundColor: HandsColors.scaffoldBackground,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Stripe CardField Integration',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: HandsColors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            Text(
              'Card Information',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: HandsColors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Card input field
            Container(
              decoration: BoxDecoration(
                color: HandsColors.cardTertiary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HandsColors.white12),
              ),
              padding: const EdgeInsets.all(16),
              child: CardField(
                onCardChanged: (card) {
                  setState(() {
                    _card = card;
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            // Debug information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HandsColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HandsColors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Information',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: HandsColors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Card Complete: ${_card?.complete ?? false}',
                    style: TextStyle(color: HandsColors.white70, fontSize: 14, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Card Brand: ${_card?.brand?.toString() ?? 'Unknown'}',
                    style: TextStyle(color: HandsColors.white70, fontSize: 14, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last 4 Digits: ${_card?.last4 ?? 'None'}',
                    style: TextStyle(color: HandsColors.white70, fontSize: 14, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Expiry Month: ${_card?.expiryMonth ?? 'None'}',
                    style: TextStyle(color: HandsColors.white70, fontSize: 14, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Expiry Year: ${_card?.expiryYear ?? 'None'}',
                    style: TextStyle(color: HandsColors.white70, fontSize: 14, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Test button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_card?.complete ?? false)
                        ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Card is complete and ready for payment!'),
                              backgroundColor: HandsColors.sageGreen,
                            ),
                          );
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HandsColors.handsOrange,
                  foregroundColor: HandsColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Test Payment Ready', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HandsColors.sageGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HandsColors.sageGreen.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: HandsColors.sageGreen, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Test Instructions',
                        style: TextStyle(color: HandsColors.sageGreen, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use test card: 4242 4242 4242 4242\nExpiry: Any future date\nCVC: Any 3 digits',
                    style: TextStyle(color: HandsColors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
