/// Global feature flags for Hands App vNEXT
const bool enableScheduling = true;

/// Billing flags and constants
const bool kPerLocationBilling = true;
const double kLocationPrice = 49.99;

/// Live Stripe Price IDs for per-location billing
const String kStripePriceMonthly = 'price_1RtqtYFzroJ5o7DAeT4jin9n';
const String kStripePriceAnnual = 'price_1RtqtYFzroJ5o7DAqjkZzsDk';

/// Back-compat alias used in existing code paths; defaults to monthly
const String kPricePerLocation = kStripePriceMonthly;

/// Google Places API key for address autocomplete.
/// Leave empty to disable network calls; the field will fall back to a plain TextField.
const String kGooglePlacesApiKey = 'AIzaSyAXlJw4FIK-L90ciE8lkBEouIcg6ylwdcg';
