/// Global feature flags for Hands App vNEXT
const bool enableScheduling = true;

/// Billing flags and constants
const bool kPerLocationBilling = true;

/// Tiered pricing constants
const double kFirstLocationPrice = 69.99;
const double kAdditionalLocationPrice = 49.99;

@Deprecated('Use PricingService.calcMonthly() for tiered pricing calculations')
const double kLocationPrice = 49.99;

/// Live Stripe Price IDs for tiered per-location billing
/// Monthly: $69.99 for first location, $49.99 for additional
/// Annual: $755.90 for first location, $539.90 for additional
const String kStripePriceMonthly = 'price_1S2zhQFzroJ5o7DAEj914UgN';
const String kStripePriceAnnual = 'price_1S2ziQFzroJ5o7DANERaDZ9r';

/// Back-compat alias used in existing code paths; defaults to monthly
const String kPricePerLocation = kStripePriceMonthly;

/// Google Places API key for address autocomplete.
/// Leave empty to disable network calls; the field will fall back to a plain TextField.
const String kGooglePlacesApiKey = 'AIzaSyAXlJw4FIK-L90ciE8lkBEouIcg6ylwdcg';
