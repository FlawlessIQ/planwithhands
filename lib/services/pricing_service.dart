class PricingService {
  // Pricing constants for tiered billing
  static const double kBaseMonthly = 69.99;
  static const double kAddlMonthly = 49.99;
  static const double kBaseAnnual = 755.90;
  static const double kAddlAnnual = 539.90;

  /// Calculate monthly cost with tiered pricing:
  /// $69.99 for the first location, $49.99 for each additional
  static double calcMonthly(int locations) {
    final n = locations < 0 ? 0 : locations;
    if (n == 0) return 0.0;
    if (n == 1) return kBaseMonthly;
    return kBaseMonthly + ((n - 1) * kAddlMonthly);
  }

  /// Calculate annual cost with tiered pricing:
  /// $755.90 for the first location, $539.90 for each additional
  static double calcAnnual(int locations) {
    final n = locations < 0 ? 0 : locations;
    if (n == 0) return 0.0;
    if (n == 1) return kBaseAnnual;
    return kBaseAnnual + ((n - 1) * kAddlAnnual);
  }

  @Deprecated('Legacy tiered-pricing API. Migrate to per-location billing and remove this call.')
  static Map<String, String> getPricingTierInfo(int employeeCount) {
    // Minimal shim to keep legacy calls compiling; returns a neutral message.
    final price =
        employeeCount <= 0
            ? 'Free'
            : '\$${kBaseMonthly.toStringAsFixed(2)} for first location, \$${kAddlMonthly.toStringAsFixed(2)} each additional';
    return {
      'price': price,
      'range': 'Tiered per-location billing',
      'description':
          'Billing is now tiered per-location. \$${kBaseMonthly.toStringAsFixed(2)} for first location, \$${kAddlMonthly.toStringAsFixed(2)} for each additional.',
    };
  }
}
