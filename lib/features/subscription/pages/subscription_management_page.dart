import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/utils/app_platform.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/services/pricing_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class SubscriptionManagementPage extends StatefulWidget {
  final String orgId;

  const SubscriptionManagementPage({super.key, required this.orgId});

  @override
  State<SubscriptionManagementPage> createState() => _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState extends State<SubscriptionManagementPage> {
  Map<String, dynamic>? _subscriptionData;
  bool _isLoadingSubscription = false;
  int? _actualLocationUsage;
  bool _isLoadingUsage = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingSubscription = true;
      _isLoadingUsage = true;
    });

    await Future.wait([_loadSubscriptionData(), _loadLocationUsage()]);
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final data = await StripeService.getSubscriptionDataHydrated(widget.orgId);
      if (!mounted) return;
      setState(() {
        _subscriptionData = data;
        _isLoadingSubscription = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSubscription = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load subscription: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _loadLocationUsage() async {
    try {
      final query =
          await FirestoreEnforcer.instance.collection('organizations').doc(widget.orgId).collection('locations').get();
      if (!mounted) return;
      setState(() {
        _actualLocationUsage = query.size;
        _isLoadingUsage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingUsage = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load usage: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _openBillingPortal() async {
    try {
      await StripeService.openBillingPortal(widget.orgId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open billing portal: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _cancelSubscription() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Cancel Subscription'),
                content: const Text(
                  'Are you sure you want to cancel your subscription? You\'ll continue to have access until the end of your current billing period or trial.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Subscription')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cancel Subscription'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await StripeService.cancelSubscription(widget.orgId);
      await _loadSubscriptionData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Subscription canceled successfully. You\'ll continue to have access until the end of your current period.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel subscription: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showQuantityManagementSheet() async {
    if (_subscriptionData == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No subscription found'), backgroundColor: Colors.red));
      return;
    }

    final subscriptionId = (_subscriptionData!['subscriptionId'] as String?) ?? '';
    final currentQuantity = (_subscriptionData!['quantity'] as int?) ?? 1;
    final currentUsage = _actualLocationUsage ?? 0;

    if (subscriptionId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Missing subscription ID'), backgroundColor: Colors.red));
      return;
    }

    final newQty = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: _QuantityManagementSheet(
              orgId: widget.orgId,
              subscriptionId: subscriptionId,
              currentQuantity: currentQuantity,
              currentUsage: currentUsage,
            ),
          ),
    );

    if (newQty != null) {
      await _loadSubscriptionData();
    }
  }

  // New concise subscription summary card with key details
  Widget _buildSubscriptionSummaryCard(BuildContext context) {
    if (_isLoadingSubscription) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Loading subscription data...', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    final status = _subscriptionData!['status'] as String?;
    final quantity = (_subscriptionData!['quantity'] as int?) ?? 1;
    final trialEnd = _subscriptionData!['trialEnd'] as int?;
    final cancellationRequested = _subscriptionData!['cancellationRequested'] as bool? ?? false;
    final monthlyTotal = PricingService.calcMonthly(quantity);

    String? trialText;
    if (status == 'trialing' && trialEnd != null) {
      trialText = 'Trial ends ${_formatDate(DateTime.fromMillisecondsSinceEpoch(trialEnd * 1000))}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Subscription',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subscribed locations:'),
                          Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (_actualLocationUsage != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Locations in use:'),
                            Text(
                              '$_actualLocationUsage',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _actualLocationUsage! <= quantity ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monthly cost:'),
                          Text(
                            '\$${monthlyTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (trialText != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.timer, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(trialText, style: const TextStyle(color: Colors.blue)),
                          ],
                        ),
                      ],
                      if (cancellationRequested) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 16, color: Colors.orange),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Cancellation scheduled at period end',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    SizedBox(
                      width: 180,
                      child: ElevatedButton.icon(
                        onPressed: _showQuantityManagementSheet,
                        icon: const Icon(Icons.tune),
                        label: const Text('Change Quantity'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 180,
                      child: OutlinedButton.icon(
                        onPressed: (kIsWeb || !isIOS) ? _openBillingPortal : null,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Billing & Invoices'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatusCard() {
    // kept for compatibility (unused by new layout)
    if (_isLoadingSubscription) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Loading subscription data...', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_subscriptionData == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Text(
                    'No Active Subscription',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('You don\'t currently have an active subscription.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final int quantity =
                        (_actualLocationUsage != null && _actualLocationUsage! > 0) ? _actualLocationUsage! : 1;
                    context.go('/embedded-payment?orgId=${widget.orgId}&email=&quantity=$quantity');
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Start Subscription'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final status = _subscriptionData!['status'] as String?;
    final quantity = (_subscriptionData!['quantity'] as int?) ?? 1;
    final trialEnd = _subscriptionData!['trialEnd'] as int?;
    final cancellationRequested = _subscriptionData!['cancellationRequested'] as bool? ?? false;
    final monthlyTotal = PricingService.calcMonthly(quantity);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusText = 'Active';
        statusIcon = Icons.check_circle;
        break;
      case 'trialing':
        statusColor = Colors.blue;
        statusText = 'Trial Period';
        statusIcon = Icons.timer;
        break;
      case 'canceled':
        statusColor = Colors.red;
        statusText = 'Canceled';
        statusIcon = Icons.cancel;
        break;
      case 'incomplete':
        statusColor = Colors.orange;
        statusText = 'Payment Required';
        statusIcon = Icons.payment;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status ?? 'Unknown';
        statusIcon = Icons.help;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  'Current Subscription',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Subscription details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subscribed Locations:'),
                      Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (_actualLocationUsage != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Locations in Use:'),
                        Text(
                          '$_actualLocationUsage',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _actualLocationUsage! <= quantity ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monthly Cost:'),
                      Text('\$${monthlyTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),

            // Trial information
            if (status == 'trialing' && trialEnd != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trial ends on ${_formatDate(DateTime.fromMillisecondsSinceEpoch(trialEnd * 1000))}',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Cancellation notice
            if (cancellationRequested) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subscription is scheduled for cancellation at the end of the current period',
                        style: TextStyle(color: Colors.orange[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    if (_subscriptionData == null) return const SizedBox.shrink();

    final cancellationRequested = _subscriptionData!['cancellationRequested'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Manage Quantity
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showQuantityManagementSheet,
                icon: const Icon(Icons.tune),
                label: const Text('Manage Subscription Quantity'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel/Reactivate Subscription
            if (!cancellationRequested) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelSubscription,
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Cancel Subscription'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openBillingPortal,
                  icon: const Icon(Icons.restore, color: Colors.green),
                  label: const Text('Reactivate Subscription'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillingManagementCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Billing Management',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Access your full billing history, update payment methods, and download invoices',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Billing Portal Access
            if (kIsWeb || !isIOS) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openBillingPortal,
                  icon: const Icon(Icons.launch),
                  label: const Text('Open Billing Portal'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'To manage billing, please visit https://planwithhands.com in Safari or Chrome and log in.',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsageInformationCard() {
    if (_isLoadingUsage) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Loading usage data...', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_subscriptionData == null || _actualLocationUsage == null) {
      return const SizedBox.shrink();
    }

    final quantity = (_subscriptionData!['quantity'] as int?) ?? 1;
    final usage = _actualLocationUsage!;
    final isOverUsage = usage > quantity;
    final remainingLocations = quantity - usage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Usage Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Usage Overview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOverUsage ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isOverUsage ? Colors.red[200]! : Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Locations Used:',
                        style: TextStyle(
                          color: isOverUsage ? Colors.red[700] : Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$usage of $quantity',
                        style: TextStyle(
                          color: isOverUsage ? Colors.red[700] : Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: usage / quantity,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(isOverUsage ? Colors.red : Colors.green),
                  ),
                  const SizedBox(height: 8),
                  if (isOverUsage) ...[
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700], size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'You\'re using ${usage - quantity} more location${usage - quantity == 1 ? '' : 's'} than your subscription allows.',
                            style: TextStyle(color: Colors.red[700], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showQuantityManagementSheet,
                        icon: const Icon(Icons.upgrade),
                        label: const Text('Increase Quantity to Match Usage'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ] else if (remainingLocations > 0) ...[
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'You have $remainingLocations location${remainingLocations == 1 ? '' : 's'} remaining.',
                            style: TextStyle(color: Colors.green[700], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription Management'), backgroundColor: HandsColors.cardPrimary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_subscriptionData == null) ...[
              _buildSubscriptionStatusCard(),
            ] else ...[
              _buildSubscriptionSummaryCard(context),
              const SizedBox(height: 12),
              _buildUsageInformationCard(),
              const SizedBox(height: 12),
              _buildQuickActionsCard(),
              const SizedBox(height: 12),
              _buildBillingManagementCard(),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _QuantityManagementSheet extends StatefulWidget {
  final String orgId;
  final String subscriptionId;
  final int currentQuantity;
  final int currentUsage;

  const _QuantityManagementSheet({
    required this.orgId,
    required this.subscriptionId,
    required this.currentQuantity,
    required this.currentUsage,
  });

  @override
  State<_QuantityManagementSheet> createState() => _QuantityManagementSheetState();
}

class _QuantityManagementSheetState extends State<_QuantityManagementSheet> {
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
  bool get _canIncrease => _newQuantity < 100;

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

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      await StripeService.updateSubscriptionQuantity(
        orgId: widget.orgId,
        subscriptionId: widget.subscriptionId,
        newQuantity: _newQuantity,
      );

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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                    'Manage Subscription Quantity',
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
                          'You cannot reduce below your current usage of ${widget.currentUsage} location${widget.currentUsage == 1 ? '' : 's'}.',
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
                          const Text('Monthly change:'),
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
                          const Text('New monthly total:'),
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
