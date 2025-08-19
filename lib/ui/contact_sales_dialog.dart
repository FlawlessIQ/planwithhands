import 'package:flutter/material.dart';

class ContactSalesDialog extends StatelessWidget {
  const ContactSalesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contact Sales'),
      content: const Text('For 5 or more locations, please contact our sales team for a customized plan.'),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
