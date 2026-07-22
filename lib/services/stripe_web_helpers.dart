// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

void navigateToEmbeddedCheckout(String clientSecret) {
  String? pk;
  try {
    final storage = html.window.localStorage;
    final isLive = clientSecret.startsWith('cs_live_');
    final pkLive = storage['STRIPE_PUBLISHABLE_KEY_LIVE'] ?? '';
    final pkTest = storage['STRIPE_PUBLISHABLE_KEY_TEST'] ?? '';
    final pkAny = storage['STRIPE_PUBLISHABLE_KEY'] ?? '';
    pk =
        isLive
            ? (pkLive.isNotEmpty ? pkLive : (pkAny.isNotEmpty ? pkAny : null))
            : (pkTest.isNotEmpty ? pkTest : (pkAny.isNotEmpty ? pkAny : null));
  } catch (_) {}

  final pkQuery = (pk != null && pk.isNotEmpty) ? '&pk=${Uri.encodeComponent(pk)}' : '';
  final url = '/embedded-checkout.html?client_secret=$clientSecret$pkQuery';
  html.window.location.assign(url);
}

void navigateToEmbeddedCheckoutWithPk(String clientSecret, String publishableKey) {
  final encodedPk = Uri.encodeComponent(publishableKey);
  final url = '/embedded-checkout.html?client_secret=$clientSecret&pk=$encodedPk';
  html.window.location.assign(url);
}

void setStripePkForEmbedded(String pk) {
  try {
    html.window.localStorage['STRIPE_PUBLISHABLE_KEY'] = pk;
    if (pk.startsWith('pk_live_')) {
      html.window.localStorage['STRIPE_PUBLISHABLE_KEY_LIVE'] = pk;
    } else if (pk.startsWith('pk_test_')) {
      html.window.localStorage['STRIPE_PUBLISHABLE_KEY_TEST'] = pk;
    }
  } catch (_) {
    // ignore storage failures
  }
}

String currentOrigin() {
  try {
    return html.window.location.origin;
  } catch (_) {
    return '';
  }
}
