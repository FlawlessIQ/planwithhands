import 'package:hands_app/config/feature_flags.dart';

class PricingService {
  static double calcMonthly(int locations) {
    final n = locations < 0 ? 0 : locations;
    return n * kLocationPrice;
  }

  @Deprecated('Legacy tiered-pricing API. Migrate to per-location billing and remove this call.')
  static Map<String, String> getPricingTierInfo(int employeeCount) {
    // Minimal shim to keep legacy calls compiling; returns a neutral message.
    final price = employeeCount <= 0 ? 'Free' : '\$${kLocationPrice.toStringAsFixed(2)}/location';
    return {
      'price': price,
      'range': 'Per location billing',
      'description': 'Billing is now per-location. Contact support for details.',
    };
  }
}
