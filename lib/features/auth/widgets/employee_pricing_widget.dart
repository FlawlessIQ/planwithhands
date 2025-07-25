import 'package:flutter/material.dart';

class EmployeePricingWidget extends StatefulWidget {
  final TextEditingController? controller;

  const EmployeePricingWidget({super.key, this.controller});

  @override
  _EmployeePricingWidgetState createState() => _EmployeePricingWidgetState();
}

class _EmployeePricingWidgetState extends State<EmployeePricingWidget> {
  late TextEditingController _controller;
  int _count = 0;

  final List<_Tier> _tiers = [
    _Tier(min: 1, max: 10, price: 49),
    _Tier(min: 11, max: 25, price: 99),
    _Tier(min: 26, max: 50, price: 179),
    _Tier(min: 51, max: 100, price: 299),
    _Tier(min: 101, max: null, price: 0), // custom
  ];

  _Tier get _currentTier {
    return _tiers.firstWhere(
      (t) => (t.max ?? double.infinity) >= _count && _count >= t.min,
      orElse: () => _tiers.last,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = _currentTier;
    final isCustom = tier.max == null;
    final monthly = isCustom ? '--' : '\$${tier.price.toStringAsFixed(0)}';
    final perEmp =
        isCustom
            ? 'Contact Us'
            : '\$${(tier.price / tier.max!).toStringAsFixed(2)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of Employees',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            final n = int.tryParse(v) ?? 0;
            setState(() => _count = n);
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _metricTile('Monthly', monthly, context),
            _metricTile('Per Employee', perEmp, context),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            child: const Text('View Pricing Details'),
            onPressed: () => _showPricingTable(context),
          ),
        ),
      ],
    );
  }

  Widget _metricTile(String label, String value, BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }

  void _showPricingTable(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Pricing Matrix'),
            content: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Employees')),
                  DataColumn(label: Text('Price / Month')),
                  DataColumn(label: Text('Per Employee')),
                ],
                rows:
                    _tiers.map((t) {
                      final empRange =
                          t.max == null ? '${t.min}+' : '${t.min}-${t.max}';
                      final priceText =
                          t.max == null
                              ? 'Custom Pricing'
                              : '\$${t.price.toStringAsFixed(0)}';
                      final perEmpText =
                          t.max == null
                              ? 'Contact Us'
                              : '\$${(t.price / t.max!).toStringAsFixed(2)}';
                      return DataRow(
                        cells: [
                          DataCell(Text(empRange)),
                          DataCell(Text(priceText)),
                          DataCell(Text(perEmpText)),
                        ],
                      );
                    }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}

class _Tier {
  final int min;
  final int? max;
  final double price;
  _Tier({required this.min, required this.max, required this.price});
}
