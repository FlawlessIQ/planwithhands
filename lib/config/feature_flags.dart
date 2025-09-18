/// Global feature flags for Hands App vNEXT
const bool enableScheduling = true;

/// Billing flags and constants
const bool kPerLocationBilling = true;

/// Pricing constants (legacy compatibility)
/// Current model: flat $49.99 per location monthly, 10% off annual
const double kFirstLocationPrice = 49.99; // legacy callers use this
const double kAdditionalLocationPrice = 49.99; // legacy callers use this

@Deprecated('Use PricingService.calcMonthly() for tiered pricing calculations')
const double kLocationPrice = 49.99;

/// Live Stripe Price IDs (Stripe tiers should be configured flat per location)
/// Monthly: $49.99 per location
/// Annual: 10% off the yearly total
///
/// These can be overridden at build/run time using Dart defines:
///   -DSTRIPE_PRICE_MONTHLY=price_XXXX  -DSTRIPE_PRICE_ANNUAL=price_YYYY
/// Example (web):
/// flutter run -d chrome --web-renderer html \
///   --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx \
///   --dart-define=STRIPE_PRICE_MONTHLY=price_XXXX \
///   --dart-define=STRIPE_PRICE_ANNUAL=price_YYYY
// Live defaults as of 2025-09-17 (prod_SpVvLXHRcgZ0yg)
const String kStripePriceMonthlyDefault = 'price_1RtqtYFzroJ5o7DAeT4jin9n'; // $49.99 monthly per location
const String kStripePriceAnnualDefault = 'price_1RtqtYFzroJ5o7DAqjkZzsDk'; // $539.98 annual per location (10% off)
const String kStripePriceMonthly = String.fromEnvironment(
  'STRIPE_PRICE_MONTHLY',
  defaultValue: kStripePriceMonthlyDefault,
);
const String kStripePriceAnnual = String.fromEnvironment(
  'STRIPE_PRICE_ANNUAL',
  defaultValue: kStripePriceAnnualDefault,
);

/// Back-compat alias used in existing code paths; defaults to monthly
const String kPricePerLocation = kStripePriceMonthly;

/// Google Places API key for address autocomplete.
/// Leave empty to disable network calls; the field will fall back to a plain TextField.
const String kGooglePlacesApiKey = 'AIzaSyAXlJw4FIK-L90ciE8lkBEouIcg6ylwdcg';
