/// Pricing constants for subscriptions
/// Current model: flat $49.99 per location monthly, 10% off annual
const String kPricePerLocation = 'price_1S2zhQFzroJ5o7DAEj914UgN'; // Monthly tiered pricing

/// Legacy display constants (kept for compatibility with old flows)
const double kFirstLocationUsd = 49.99;
const double kAdditionalLocationUsd = 49.99;

@Deprecated('Use PricingService.calcMonthly() for current flat pricing calculations')
const double kPerLocationUsd = 49.99;
