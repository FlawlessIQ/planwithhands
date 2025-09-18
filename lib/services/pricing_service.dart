class PricingService {
  // Flat per-location pricing constants
  static const double kPerLocationMonthly = 49.99;
  static const double kAnnualDiscountRate = 0.10; // 10% off annual

  /// Calculate monthly cost with flat per-location pricing
  static double calcMonthly(int locations) {
    final n = locations < 0 ? 0 : locations;
    return n * kPerLocationMonthly;
  }

  /// Calculate annual cost with flat per-location pricing and 10% discount
  static double calcAnnual(int locations) {
    final monthly = calcMonthly(locations);
    return monthly * 12 * (1 - kAnnualDiscountRate);
  }

  @Deprecated('Legacy tiered-pricing API. Kept for back-compat only.')
  static Map<String, String> getPricingTierInfo(int employeeCount) {
    // Minimal shim to keep legacy calls compiling; returns flat pricing message.
    final price = employeeCount <= 0 ? 'Free' : '\$${kPerLocationMonthly.toStringAsFixed(2)} per location/month';
    return {
      'price': price,
      'range': 'Flat per-location billing',
      'description':
          'Billing is flat per-location at \$${kPerLocationMonthly.toStringAsFixed(2)} per month. Annual saves 10%.',
    };
  }
}
