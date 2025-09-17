import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeCardDebugPage extends StatefulWidget {
  const StripeCardDebugPage({super.key});

  @override
  State<StripeCardDebugPage> createState() => _StripeCardDebugPageState();
}

class _StripeCardDebugPageState extends State<StripeCardDebugPage> {
  CardFieldInputDetails? _card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stripe Card Debug'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('CardField Test', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            CardField(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onCardChanged: (card) {
                setState(() {
                  _card = card;
                });
              },
            ),
            const SizedBox(height: 20),
            Text('Card Complete: ${_card?.complete ?? false}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            if (_card != null) ...[
              Text('Brand: ${_card!.brand}'),
              Text('Complete: ${_card!.complete}'),
              Text('Last 4: ${_card!.last4}'),
              Text('Exp Month: ${_card!.expiryMonth}'),
              Text('Exp Year: ${_card!.expiryYear}'),
              Text('Valid CVC: ${_card!.validCVC}'),
              Text('Valid Expiry: ${_card!.validExpiryDate}'),
              Text('Valid Number: ${_card!.validNumber}'),
            ],
            const SizedBox(height: 20),
            const Text('Test Card Numbers:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Visa: 4242424242424242'),
            const Text('Visa (debit): 4000056655665556'),
            const Text('Mastercard: 5555555555554444'),
            const Text('American Express: 378282246310005'),
            const Text('Use any future expiry date and any 3-4 digit CVC'),
          ],
        ),
      ),
    );
  }
}
