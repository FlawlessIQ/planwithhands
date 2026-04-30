import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/features/crm/services/crm_service.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

enum _CrmAccountFilter { active, recentCanceled, inactive, all }

extension _CrmAccountFilterLabel on _CrmAccountFilter {
  String get label {
    switch (this) {
      case _CrmAccountFilter.active:
        return 'Active only';
      case _CrmAccountFilter.recentCanceled:
        return 'Recent cancels';
      case _CrmAccountFilter.inactive:
        return 'Inactive/old';
      case _CrmAccountFilter.all:
        return 'All accounts';
    }
  }
}

class CrmDashboardPage extends StatefulWidget {
  const CrmDashboardPage({super.key});

  @override
  State<CrmDashboardPage> createState() => _CrmDashboardPageState();
}

class _CrmDashboardPageState extends State<CrmDashboardPage> {
  final CrmService _service = const CrmService();
  final TextEditingController _searchController = TextEditingController();
  Future<Map<String, dynamic>>? _dashboardFuture;
  Map<String, dynamic>? _selectedCustomer;
  Map<String, dynamic>? _selectedDetail;
  List<Map<String, dynamic>> _promotionCodes = const [];
  bool _loadingDetail = false;
  bool _showArchived = false;
  _CrmAccountFilter _accountFilter = _CrmAccountFilter.active;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _service.getDashboard();
    _loadPromotionCodes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboardFuture = _service.getDashboard(includeArchived: _showArchived);
      _selectedDetail = null;
    });
    await _loadPromotionCodes();
  }

  Future<void> _exitCrm() async {
    var destination = AppRoutes.adminDashboardPage.path;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        context.go(AppRoutes.loginPage.path);
        return;
      }

      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final userData = userDoc.data();
      final role = (userData?['userRole'] as num?)?.toInt() ?? 2;

      if (role >= 2) {
        destination = AppRoutes.adminDashboardPage.path;
      } else if (role >= 1) {
        destination = AppRoutes.managerDashboardPage.path;
      } else {
        destination = AppRoutes.userDashboardPage.path;
      }
    } catch (_) {
      destination = AppRoutes.adminDashboardPage.path;
    }

    if (!mounted) return;
    context.go(destination);
  }

  Future<void> _loadPromotionCodes() async {
    try {
      final codes = await _service.listPromotionCodes();
      if (mounted) setState(() => _promotionCodes = codes);
    } catch (_) {
      if (mounted) setState(() => _promotionCodes = const []);
    }
  }

  Future<void> _selectCustomer(Map<String, dynamic> customer) async {
    final organizationId = customer['organizationId']?.toString() ?? '';
    if (organizationId.isEmpty) return;
    setState(() {
      _selectedCustomer = customer;
      _loadingDetail = true;
      _selectedDetail = null;
    });
    try {
      final detail = await _service.getOrganization(organizationId);
      if (mounted) {
        setState(() {
          _selectedDetail = detail;
          _loadingDetail = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDetail = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load account: $e')));
    }
  }

  Future<void> _createPromotionCode() async {
    final codeController = TextEditingController();
    final campaignController = TextEditingController(text: 'Launch');
    final percentController = TextEditingController(text: '20');
    final maxController = TextEditingController();

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: HandsColors.cardPrimary,
          title: const Text('Generate promo code'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: campaignController,
                  decoration: const InputDecoration(labelText: 'Campaign'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: percentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Percent off'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max redemptions',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (shouldCreate != true) return;
    try {
      await _service.createPromotionCode(
        code: codeController.text.trim(),
        campaign: campaignController.text.trim(),
        percentOff: int.tryParse(percentController.text.trim()) ?? 0,
        maxRedemptions: int.tryParse(maxController.text.trim()),
      );
      await _loadPromotionCodes();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Promo code created')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create promo code: $e')),
      );
    }
  }

  Future<void> _setShowArchived(bool value) async {
    setState(() {
      _showArchived = value;
      _dashboardFuture = _service.getDashboard(includeArchived: value);
      _selectedCustomer = null;
      _selectedDetail = null;
    });
  }

  Future<void> _updateCustomerFlags({
    required Map<String, dynamic> customer,
    bool? archived,
    bool? excludeFromMrr,
    bool? excludeFromMetrics,
    String? accountType,
    String? reason,
  }) async {
    final organizationId = customer['organizationId']?.toString() ?? '';
    if (organizationId.isEmpty) return;
    try {
      await _service.updateOrganizationFlags(
        organizationId: organizationId,
        archived: archived,
        excludeFromMrr: excludeFromMrr,
        excludeFromMetrics: excludeFromMetrics,
        accountType: accountType,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CRM account flags updated')),
      );
      setState(() {
        _selectedCustomer = null;
        _selectedDetail = null;
        _dashboardFuture = _service.getDashboard(
          includeArchived: _showArchived,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update account: $e')));
    }
  }

  Future<void> _confirmArchiveCustomer(Map<String, dynamic> customer) async {
    final reasonController = TextEditingController(text: 'Never really used');
    final archived = customer['crmArchived'] == true;
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: HandsColors.cardPrimary,
            title: Text(archived ? 'Unarchive account?' : 'Archive account?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  archived
                      ? 'This will return the account to the default CRM list and metrics.'
                      : 'This hides the account from the default CRM list and excludes it from customer, user, location, and MRR totals. It does not delete data or cancel Stripe.',
                ),
                if (!archived) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Reason'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(archived ? 'Unarchive' : 'Archive'),
              ),
            ],
          ),
    );
    if (shouldUpdate != true) return;
    await _updateCustomerFlags(
      customer: customer,
      archived: !archived,
      excludeFromMetrics: !archived,
      excludeFromMrr: !archived,
      accountType: archived ? 'customer' : 'archived',
      reason: archived ? null : reasonController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        leading: IconButton(
          tooltip: 'Exit CRM',
          onPressed: _exitCrm,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          'Hands CRM',
          style: GoogleFonts.comfortaa(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton.icon(
            onPressed: _exitCrm,
            icon: const Icon(Icons.home_work_outlined),
            label: const Text('Exit CRM'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final customers =
              (data['customers'] as List<dynamic>? ?? const [])
                  .whereType<Map>()
                  .map((value) => Map<String, dynamic>.from(value))
                  .toList();
          final filteredByStatus =
              customers.where((customer) {
                final health = customer['healthStatus']?.toString() ?? '';
                final subscription =
                    customer['subscriptionStatus']?.toString() ?? '';
                final oldInactive = customer['oldInactive'] == true;
                final recentCancel = customer['recentlyCanceled'] == true;
                final canceled =
                    health.contains('canceled') ||
                    subscription == 'canceled' ||
                    subscription == 'cancelled';
                switch (_accountFilter) {
                  case _CrmAccountFilter.active:
                    return !oldInactive && !recentCancel && !canceled;
                  case _CrmAccountFilter.recentCanceled:
                    return recentCancel;
                  case _CrmAccountFilter.inactive:
                    return oldInactive || health == 'inactive' || canceled;
                  case _CrmAccountFilter.all:
                    return true;
                }
              }).toList();
          final query = _searchController.text.trim().toLowerCase();
          final filtered =
              query.isEmpty
                  ? filteredByStatus
                  : filteredByStatus.where((customer) {
                    final haystack =
                        [
                          customer['organizationName'],
                          customer['ownerEmail'],
                          customer['subscriptionStatus'],
                          customer['healthStatus'],
                          customer['crmAccountType'],
                        ].join(' ').toLowerCase();
                    return haystack.contains(query);
                  }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              final content = [
                _MetricsGrid(data: data),
                const SizedBox(height: 10),
                _Toolbar(
                  controller: _searchController,
                  onChanged: () => setState(() {}),
                  onCreateCode: _createPromotionCode,
                  showArchived: _showArchived,
                  onShowArchivedChanged: _setShowArchived,
                  accountFilter: _accountFilter,
                  onAccountFilterChanged:
                      (value) => setState(() => _accountFilter = value),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _CustomerTable(
                    customers: filtered,
                    selectedOrgId:
                        _selectedCustomer?['organizationId']?.toString(),
                    onSelect: _selectCustomer,
                  ),
                ),
              ];

              if (!wide) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ...content,
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 520,
                        child: _CustomerDetailPanel(
                          customer: _selectedCustomer,
                          detail: _selectedDetail,
                          promotionCodes: _promotionCodes,
                          loading: _loadingDetail,
                          onArchive: _confirmArchiveCustomer,
                          onExcludeFromMrr:
                              (customer, exclude) => _updateCustomerFlags(
                                customer: customer,
                                excludeFromMrr: exclude,
                                accountType: exclude ? 'test' : 'customer',
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(flex: 7, child: Column(children: content)),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: _CustomerDetailPanel(
                        customer: _selectedCustomer,
                        detail: _selectedDetail,
                        promotionCodes: _promotionCodes,
                        loading: _loadingDetail,
                        onArchive: _confirmArchiveCustomer,
                        onExcludeFromMrr:
                            (customer, exclude) => _updateCustomerFlags(
                              customer: customer,
                              excludeFromMrr: exclude,
                              accountType: exclude ? 'test' : 'customer',
                            ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MetricsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Customers', data['totalCustomers']?.toString() ?? '0'),
      ('Active', data['activeCustomers']?.toString() ?? '0'),
      ('Billable MRR', data['mrrLabel']?.toString() ?? r'$0'),
      ('Users', data['totalUsers']?.toString() ?? '0'),
      ('Locations', data['totalLocations']?.toString() ?? '0'),
      ('Issues', data['paymentIssues']?.toString() ?? '0'),
      ('Recent cancels', data['recentlyCanceled']?.toString() ?? '0'),
      ('Inactive', data['oldInactive']?.toString() ?? '0'),
      ('Archived', data['archivedCustomers']?.toString() ?? '0'),
      ('Excluded', data['excludedFromMrrCustomers']?.toString() ?? '0'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 155,
        mainAxisExtent: 58,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return _CrmCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                metric.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HandsColors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                metric.$2,
                style: GoogleFonts.comfortaa(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: HandsColors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onCreateCode;
  final bool showArchived;
  final ValueChanged<bool> onShowArchivedChanged;
  final _CrmAccountFilter accountFilter;
  final ValueChanged<_CrmAccountFilter> onAccountFilterChanged;

  const _Toolbar({
    required this.controller,
    required this.onChanged,
    required this.onCreateCode,
    required this.showArchived,
    required this.onShowArchivedChanged,
    required this.accountFilter,
    required this.onAccountFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                prefixIconConstraints: BoxConstraints(minWidth: 38),
                hintText: 'Search accounts',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onCreateCode,
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          icon: const Icon(Icons.confirmation_number_outlined, size: 17),
          label: const Text('Promo'),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 42,
          child: DropdownButton<_CrmAccountFilter>(
            value: accountFilter,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 13, color: HandsColors.white),
            onChanged: (value) {
              if (value != null) onAccountFilterChanged(value);
            },
            items:
                _CrmAccountFilter.values
                    .map(
                      (filter) => DropdownMenuItem(
                        value: filter,
                        child: Text(filter.label),
                      ),
                    )
                    .toList(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 42,
          child: FilterChip(
            visualDensity: VisualDensity.compact,
            selected: showArchived,
            label: const Text('Archived', style: TextStyle(fontSize: 12)),
            onSelected: onShowArchivedChanged,
          ),
        ),
      ],
    );
  }
}

class _CustomerTable extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final String? selectedOrgId;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _CustomerTable({
    required this.customers,
    required this.selectedOrgId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const _CrmCard(
        child: Center(child: Text('No customer accounts found')),
      );
    }
    return _CrmCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: customers.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final customer = customers[index];
          final orgId = customer['organizationId']?.toString();
          final selected = orgId == selectedOrgId;
          final lastUsed = _formatCrmShortDate(customer['lastActivityAt']);
          final archived = customer['crmArchived'] == true;
          final excluded = customer['excludedFromMrr'] == true;
          final recentCancel = customer['recentlyCanceled'] == true;
          final oldInactive = customer['oldInactive'] == true;
          final flags = <String>[
            '${customer['locationCount'] ?? 0} loc',
            '${customer['userCount'] ?? 0} users',
            'Last $lastUsed',
            if (recentCancel) 'Canceled',
            if (oldInactive) 'Inactive',
            if (excluded) 'Excluded',
            if (archived) 'Archived',
          ].join(' • ');
          return ListTile(
            dense: true,
            minVerticalPadding: 6,
            horizontalTitleGap: 8,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
            selected: selected,
            selectedTileColor: HandsColors.handsOrange.withValues(alpha: 0.08),
            tileColor:
                recentCancel
                    ? Colors.redAccent.withValues(alpha: 0.08)
                    : oldInactive
                    ? HandsColors.white.withValues(alpha: 0.03)
                    : null,
            title: Text(
              customer['organizationName']?.toString() ?? 'Unnamed restaurant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.comfortaa(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${customer['ownerEmail'] ?? 'No owner'} • $flags',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: HandsColors.white70),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusPill(
                  label:
                      archived
                          ? 'archived'
                          : customer['healthStatus']?.toString() ?? 'unknown',
                ),
                const SizedBox(height: 4),
                Text(
                  customer['mrrLabel']?.toString() ?? r'$0',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            onTap: () => onSelect(customer),
          );
        },
      ),
    );
  }
}

class _CustomerDetailPanel extends StatelessWidget {
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? detail;
  final List<Map<String, dynamic>> promotionCodes;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onArchive;
  final void Function(Map<String, dynamic> customer, bool exclude)
  onExcludeFromMrr;

  const _CustomerDetailPanel({
    required this.customer,
    required this.detail,
    required this.promotionCodes,
    required this.loading,
    required this.onArchive,
    required this.onExcludeFromMrr,
  });

  @override
  Widget build(BuildContext context) {
    if (customer == null) {
      return const _CrmCard(
        child: Center(child: Text('Select a restaurant account')),
      );
    }
    if (loading) {
      return const _CrmCard(child: Center(child: CircularProgressIndicator()));
    }

    final orgId = customer!['organizationId']?.toString() ?? '';
    final users =
        (detail?['users'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
    final locations =
        (detail?['locations'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
    final liveSubscription =
        detail?['liveSubscription'] is Map
            ? Map<String, dynamic>.from(detail!['liveSubscription'] as Map)
            : null;
    final nextInvoiceAt =
        liveSubscription?['currentPeriodEnd'] ?? customer!['nextInvoiceAt'];
    final trialEndsAt = customer!['trialEndsAt'];
    final latestInvoiceTotal = liveSubscription?['latestInvoiceTotal'];
    final archived = customer!['crmArchived'] == true;
    final excludedFromMrr = customer!['excludedFromMrr'] == true;
    final recentlyCanceled = customer!['recentlyCanceled'] == true;
    final oldInactive = customer!['oldInactive'] == true;

    return _CrmCard(
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  customer!['organizationName']?.toString() ?? 'Account',
                  style: GoogleFonts.comfortaa(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Manage account',
                onPressed:
                    orgId.isEmpty
                        ? null
                        : () => context.go('/crm/org/$orgId/admin'),
                icon: const Icon(Icons.admin_panel_settings_outlined),
              ),
              IconButton(
                tooltip: archived ? 'Unarchive account' : 'Archive account',
                onPressed: () => onArchive(customer!),
                icon: Icon(
                  archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatusPill(
            label:
                archived
                    ? 'archived'
                    : customer!['healthStatus']?.toString() ?? 'unknown',
          ),
          if (excludedFromMrr || archived) ...[
            const SizedBox(height: 8),
            _StatusPill(
              label: archived ? 'excluded from metrics' : 'MRR excluded',
            ),
          ],
          if (recentlyCanceled || oldInactive) ...[
            const SizedBox(height: 8),
            _StatusPill(
              label: recentlyCanceled ? 'recent cancellation' : 'inactive old',
            ),
          ],
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Exclude from billable MRR'),
            subtitle: const Text(
              'Use for test/free accounts that should stay visible but not count as revenue.',
            ),
            value: excludedFromMrr,
            onChanged:
                archived ? null : (value) => onExcludeFromMrr(customer!, value),
          ),
          const Divider(height: 24),
          _DetailRow('Owner', customer!['ownerEmail']?.toString() ?? 'Unknown'),
          _DetailRow(
            'Subscription',
            customer!['subscriptionStatus']?.toString() ?? 'Unknown',
          ),
          _DetailRow(
            'Billable MRR',
            customer!['mrrLabel']?.toString() ?? r'$0',
          ),
          _DetailRow(
            'Net Stripe MRR',
            customer!['netMrrLabel']?.toString() ?? r'$0',
          ),
          _DetailRow(
            'Gross Stripe MRR',
            customer!['grossMrrLabel']?.toString() ?? r'$0',
          ),
          if ((customer!['discountLabel'] ?? '').toString().isNotEmpty)
            _DetailRow('Discount', customer!['discountLabel'].toString()),
          _DetailRow(
            'Revenue source',
            customer!['billingSource'] == 'stripe_live'
                ? 'Stripe live'
                : 'Firestore snapshot',
          ),
          _DetailRow('Locations', locations.length.toString()),
          _DetailRow('Users', users.length.toString()),
          _DetailRow(
            'Templates',
            detail?['checklistTemplateCount']?.toString() ?? '0',
          ),
          const Divider(height: 28),
          _DetailRow('Joined', _formatCrmDate(customer!['createdAt'])),
          _DetailRow('Last used', _formatCrmDate(customer!['lastActivityAt'])),
          _DetailRow('Next invoice', _formatCrmDate(nextInvoiceAt)),
          if (customer!['canceledAt'] != null)
            _DetailRow('Canceled', _formatCrmDate(customer!['canceledAt'])),
          if (customer!['cancelAt'] != null)
            _DetailRow('Cancels on', _formatCrmDate(customer!['cancelAt'])),
          if (trialEndsAt != null)
            _DetailRow('Trial ends', _formatCrmDate(trialEndsAt)),
          if (customer!['latestInvoiceCreatedAt'] != null)
            _DetailRow(
              'Latest invoice',
              _formatCrmDate(customer!['latestInvoiceCreatedAt']),
            ),
          if (liveSubscription != null) ...[
            const Divider(height: 28),
            _DetailRow(
              'Stripe status',
              liveSubscription['status']?.toString() ?? 'Unknown',
            ),
            _DetailRow(
              'Billed locations',
              liveSubscription['quantity']?.toString() ?? 'Unknown',
            ),
            _DetailRow(
              'Stripe billable MRR',
              liveSubscription['netMrrLabel']?.toString() ??
                  customer!['mrrLabel']?.toString() ??
                  r'$0',
            ),
            _DetailRow(
              'Stripe gross MRR',
              liveSubscription['grossMrrLabel']?.toString() ?? r'$0',
            ),
            _DetailRow(
              'Current period',
              '${_formatCrmDate(liveSubscription['currentPeriodStart'])} - ${_formatCrmDate(liveSubscription['currentPeriodEnd'])}',
            ),
            if (latestInvoiceTotal != null)
              _DetailRow(
                'Invoice total',
                _formatCents(
                  latestInvoiceTotal,
                  liveSubscription['currency']?.toString() ?? 'usd',
                ),
              ),
            if ((liveSubscription['latestInvoiceUrl'] ?? '')
                .toString()
                .isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed:
                      () => _openUrl(
                        liveSubscription['latestInvoiceUrl'].toString(),
                      ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Open latest invoice'),
                ),
              ),
          ],
          const Divider(height: 28),
          Text('Recent users', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...users
              .take(8)
              .map(
                (user) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                            .trim()
                            .isEmpty
                        ? user['email']?.toString() ?? 'User'
                        : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                            .trim(),
                  ),
                  subtitle: Text(
                    '${user['email']?.toString() ?? ''}\nJoined ${_formatCrmDate(user['createdAt'])} • Last login ${_formatCrmDate(user['lastLogin'])}',
                  ),
                ),
              ),
          const Divider(height: 28),
          Text(
            'Promo code usage',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...promotionCodes
              .take(8)
              .map(
                (code) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    code['active'] == true
                        ? Icons.check_circle
                        : Icons.pause_circle,
                    color:
                        code['active'] == true
                            ? HandsColors.sageGreen
                            : HandsColors.white70,
                  ),
                  title: Text(code['code']?.toString() ?? ''),
                  subtitle: Text(_promoCodeSummary(code)),
                  trailing: Text(
                    code['redemptionLabel']?.toString() ?? '0 used',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }
}

int? _asMillis(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

String _formatCrmDate(dynamic value) {
  final millis = _asMillis(value);
  if (millis == null || millis <= 0) return 'Unknown';
  return DateFormat(
    'MMM d, yyyy',
  ).format(DateTime.fromMillisecondsSinceEpoch(millis).toLocal());
}

String _formatCrmShortDate(dynamic value) {
  final millis = _asMillis(value);
  if (millis == null || millis <= 0) return 'n/a';
  return DateFormat(
    'MMM d',
  ).format(DateTime.fromMillisecondsSinceEpoch(millis).toLocal());
}

String _formatCents(dynamic cents, String currency) {
  final value = _asMillis(cents) ?? 0;
  final symbol =
      currency.toUpperCase() == 'USD' ? r'$' : '${currency.toUpperCase()} ';
  return '$symbol${NumberFormat('#,##0').format(value / 100)}';
}

String _promoDiscountLabel(Map<String, dynamic> code) {
  if (code['percentOff'] != null) return '${code['percentOff']}% off';
  if (code['amountOff'] != null) {
    return '${_formatCents(code['amountOff'], code['currency']?.toString() ?? 'usd')} off';
  }
  return 'Discount';
}

String _promoCodeSummary(Map<String, dynamic> code) {
  final parts = <String>[
    _promoDiscountLabel(code),
    code['statusLabel']?.toString() ?? 'unknown',
    'Created ${_formatCrmDate(code['created'])}',
  ];
  if (code['expiresAt'] != null) {
    parts.add('Expires ${_formatCrmDate(code['expiresAt'])}');
  }
  if (code['remainingRedemptions'] != null) {
    parts.add('${code['remainingRedemptions']} remaining');
  }
  return parts.join(' • ');
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: HandsColors.white70),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final normalized = label.replaceAll('_', ' ');
    final color =
        label.contains('payment') ||
                label.contains('past') ||
                label.contains('unpaid') ||
                label.contains('cancel')
            ? Colors.redAccent
            : label.contains('archive') || label.contains('excluded')
            ? HandsColors.white70
            : label.contains('trial')
            ? Colors.amber
            : label.contains('inactive')
            ? HandsColors.white70
            : HandsColors.sageGreen;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          normalized,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CrmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _CrmCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HandsColors.cardPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HandsColors.white12),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _CrmCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 34),
            const SizedBox(height: 12),
            const Text('CRM dashboard unavailable'),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
