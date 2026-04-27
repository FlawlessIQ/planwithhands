import 'package:flutter/material.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/services/pricing_service.dart';

class UpgradeLocationSheet extends StatefulWidget {
  final String orgId;
  final String subscriptionId;
  final int currentQuantity;
  const UpgradeLocationSheet({
    super.key,
    required this.orgId,
    required this.subscriptionId,
    required this.currentQuantity,
  });

  @override
  State<UpgradeLocationSheet> createState() => _UpgradeLocationSheetState();
}

class _UpgradeLocationSheetState extends State<UpgradeLocationSheet> {
  int _delta = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final newQuantity = widget.currentQuantity + _delta;
    final totalPrice =
        PricingService.calcMonthly(newQuantity) -
        PricingService.calcMonthly(widget.currentQuantity);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_business, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.upgradeLocationsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.upgradeLocationsQuantity),
                Row(
                  children: [
                    IconButton(
                      onPressed:
                          _delta > 1 ? () => setState(() => _delta -= 1) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$_delta',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _delta += 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.upgradeLocationsSummary(
                _delta,
                '\$${totalPrice.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final newQty = widget.currentQuantity + _delta;
                  try {
                    // First, update the subscription quantity
                    await StripeService.updateSubscriptionQuantity(
                      orgId: widget.orgId,
                      subscriptionId: widget.subscriptionId,
                      newQuantity: newQty,
                    );
                    // Then, send the user to Stripe to review charges / add payment method if required
                    await StripeService.openBillingPortal(widget.orgId);
                    if (context.mounted) Navigator.of(context).pop(newQty);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.upgradeLocationsFailed(e.toString()),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text(l10n.upgradeLocationsAction),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
