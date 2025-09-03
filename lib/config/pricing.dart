/// Pricing constants for subscriptions
/// Tiered pricing: $69.99 for first location, $49.99 for additional locations
const String kPricePerLocation = 'price_1S2zhQFzroJ5o7DAEj914UgN'; // Monthly tiered pricing

/// Tiered pricing constants (for display/estimates)
const double kFirstLocationUsd = 69.99;
const double kAdditionalLocationUsd = 49.99;

@Deprecated('Use PricingService.calcMonthly() for tiered pricing calculations')
const double kPerLocationUsd = 49.99;
