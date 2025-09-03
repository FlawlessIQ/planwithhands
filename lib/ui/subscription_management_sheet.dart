import 'package:flutter/material.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/services/pricing_service.dart';

class SubscriptionManagementSheet extends StatefulWidget {
  final String orgId;
  final String subscriptionId;
  final int currentQuantity;
  final int currentUsage;

  const SubscriptionManagementSheet({
    super.key,
    required this.orgId,
    required this.subscriptionId,
    required this.currentQuantity,
    required this.currentUsage,
  });

  @override
  State<SubscriptionManagementSheet> createState() => _SubscriptionManagementSheetState();
}

class _SubscriptionManagementSheetState extends State<SubscriptionManagementSheet> {
  late int _newQuantity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newQuantity = widget.currentQuantity;
  }

  int get _delta => _newQuantity - widget.currentQuantity;
  double get _monthlyChange =>
      PricingService.calcMonthly(_newQuantity) - PricingService.calcMonthly(widget.currentQuantity);
  bool get _canDecrease => _newQuantity > widget.currentUsage && _newQuantity > 1;
  bool get _canIncrease => _newQuantity < 100; // reasonable upper limit

  void _increment() {
    if (_canIncrease) {
      setState(() => _newQuantity++);
    }
  }

  void _decrement() {
    if (_canDecrease) {
      setState(() => _newQuantity--);
    }
  }

  Future<void> _updateSubscription() async {
    if (_delta == 0) {
      Navigator.of(context).pop();
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      await StripeService.updateSubscriptionQuantity(
        orgId: widget.orgId,
        subscriptionId: widget.subscriptionId,
        newQuantity: _newQuantity,
      );

      // Open billing portal for user to see changes and update payment if needed
      await StripeService.openBillingPortal(widget.orgId);

      if (mounted) {
        Navigator.of(context).pop(_newQuantity);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_delta > 0 ? 'Subscription upgraded successfully!' : 'Subscription updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update subscription: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final isIncrease = _delta > 0;
    final changeText = isIncrease ? 'increase' : 'decrease';
    final monthlyChangeText =
        _monthlyChange >= 0
            ? '+\$${_monthlyChange.abs().toStringAsFixed(2)}'
            : '-\$${_monthlyChange.abs().toStringAsFixed(2)}';

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('${isIncrease ? 'Upgrade' : 'Downgrade'} Subscription'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You\'re about to $changeText your location subscription:'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('From:'), Text('${widget.currentQuantity} locations')],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('To:'), Text('$_newQuantity locations')],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monthly change:'),
                        Text(
                          '$monthlyChangeText/month',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isIncrease ? Colors.red : Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!isIncrease) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your new billing amount will take effect on your next billing cycle.',
                                style: TextStyle(color: Colors.orange[700], fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isIncrease ? Colors.blue : Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isIncrease ? 'Upgrade' : 'Downgrade'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 600),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.tune, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Manage Subscription',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),

              // Current status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Subscription',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subscribed locations:'),
                        Text('${widget.currentQuantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Locations in use:'),
                        Text(
                          '${widget.currentUsage}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: widget.currentUsage <= widget.currentQuantity ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monthly cost:'),
                        Text(
                          '\$${PricingService.calcMonthly(widget.currentQuantity).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quantity selector
              Text(
                'New Quantity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _canDecrease ? _decrement : null,
                    icon: Icon(Icons.remove_circle, size: 36, color: _canDecrease ? Colors.red : Colors.grey[300]),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_newQuantity',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: _canIncrease ? _increment : null,
                    icon: Icon(Icons.add_circle, size: 36, color: _canIncrease ? Colors.green : Colors.grey[300]),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Constraints info
              if (!_canDecrease && _newQuantity > 1) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    border: Border.all(color: Colors.amber[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You cannot reduce below your current usage of ${widget.currentUsage} location${widget.currentUsage == 1 ? '' : 's'}. To lower your subscription you must first delete or deactivate a location in your Admin Dashboard so that your active locations count drops below the subscription quantity.',
                          style: TextStyle(color: Colors.amber[700], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Change summary
              if (_delta != 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _delta > 0 ? Colors.blue[50] : Colors.orange[50],
                    border: Border.all(color: _delta > 0 ? Colors.blue[200]! : Colors.orange[200]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _delta > 0 ? Icons.trending_up : Icons.trending_down,
                            color: _delta > 0 ? Colors.blue[700] : Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _delta > 0 ? 'Subscription Upgrade' : 'Subscription Downgrade',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _delta > 0 ? Colors.blue[700] : Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Monthly change:'),
                          Text(
                            '${_monthlyChange >= 0 ? '+' : ''}\$${_monthlyChange.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _delta > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('New monthly total:'),
                          Text(
                            '\$${PricingService.calcMonthly(_newQuantity).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading || _delta == 0 ? null : _updateSubscription,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _delta > 0
                                ? Colors.blue
                                : _delta < 0
                                ? Colors.orange
                                : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                              : Text(
                                _delta == 0
                                    ? 'No Changes'
                                    : _delta > 0
                                    ? 'Upgrade Subscription'
                                    : 'Downgrade Subscription',
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
