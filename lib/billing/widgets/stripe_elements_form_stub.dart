import 'package:flutter/material.dart';

typedef CompletionChanged = void Function(bool complete);

class StripeElementsWebForm extends StatelessWidget {
  final String publishableKey;
  final CompletionChanged onChanged;
  final EdgeInsets padding;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final String? clientSecretToConfirm;

  const StripeElementsWebForm({
    super.key,
    required this.publishableKey,
    required this.onChanged,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = const Color(0xFFF6F7F9),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.border,
    this.clientSecretToConfirm,
  });

  @override
  Widget build(BuildContext context) {
    // This stub should never be used on web; it's here for analyzer/other platforms
    return Container(
      alignment: Alignment.centerLeft,
      padding: padding,
      decoration: BoxDecoration(color: backgroundColor, borderRadius: borderRadius, border: border),
      child: const Text('Stripe Elements not supported on this platform.'),
    );
  }
}
