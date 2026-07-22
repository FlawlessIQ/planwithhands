void navigateToEmbeddedCheckout(String clientSecret) {
  throw UnsupportedError('Embedded checkout navigation is web-only');
}

void navigateToEmbeddedCheckoutWithPk(String clientSecret, String publishableKey) {
  throw UnsupportedError('Embedded checkout navigation is web-only');
}

void setStripePkForEmbedded(String pk) {
  // no-op on non-web
}

String currentOrigin() => '';
