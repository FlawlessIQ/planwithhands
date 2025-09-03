import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/config/feature_flags.dart';

class StripeService {
  // Injectable dependencies for testing
  // Invoker that calls a named Cloud Function with a payload and returns a Map response.
  static Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)? _invoke;
  // Launcher override for tests
  static Future<bool> Function(Uri url, {LaunchMode mode})? _launch;

  /// Configure test hooks. In production you don't need to call this.
  @visibleForTesting
  static void configureTestOverrides({
    Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)? invoke,
    Future<bool> Function(Uri url, {LaunchMode mode})? launch,
  }) {
    _invoke = invoke;
    _launch = launch;
  }

  static Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> payload) async {
    if (_invoke != null) return _invoke!(name, payload);
    final callable = FirebaseFunctions.instance.httpsCallable(name);
    final result = await callable.call(payload);
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    // If backend returns a non-map, wrap it
    return {'data': data};
  }

  static Future<void> _openUrlExternal(String url) async {
    final uri = Uri.parse(url);

    // On web, try multiple approaches to handle popup blockers
    if (kIsWeb) {
      try {
        // First try: Standard approach with _blank
        final success = await launchUrl(uri, webOnlyWindowName: '_blank');
        if (success) return;
      } catch (e) {
        debugPrint('[StripeService] Standard launch failed, trying fallback methods: $e');
      }

      try {
        // Second try: External application mode
        final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (success) return;
      } catch (e) {
        // Continue to next method
      }

      try {
        // Third try: Platform default
        final success = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (success) return;
      } catch (e) {
        // Continue to final attempt
      }

      // Final attempt with canLaunchUrl check
      try {
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          await launchUrl(uri);
        } else {
          throw Exception('URL cannot be launched on this platform');
        }
      } catch (e) {
        debugPrint('[StripeService] All URL launch methods failed: $e');
        throw Exception('Failed to open billing portal. Please check your browser popup settings.');
      }

      return;
    }

    // Mobile platforms
    final launcher = _launch ?? launchUrl;
    await launcher(uri, mode: LaunchMode.externalApplication);
  }

  /// Set Stripe publishable key (call this at app startup)
  static void initStripe() {
    Stripe.publishableKey =
        'pk_live_51QpYFkFzroJ5o7DACsVjbkUhzJ0fy8vLS2G517jlVJAwwKWtJDp0ZQAU3BY9ci5ItwPCfS1aF8dnu0zR26wAwl5R00wohDkexI';
  }

  /// Start Stripe Checkout for per-location price, returning the session URL.
  ///
  /// Use the tiered pricing price IDs:
  /// - Monthly: kStripePriceMonthly (price_1S2zhQFzroJ5o7DAEj914UgN)
  /// - Annual: kStripePriceAnnual (price_1S2ziQFzroJ5o7DANERaDZ9r)
  ///
  /// The quantity parameter should be the number of locations.
  /// Stripe will automatically apply tiered pricing:
  /// - $69.99 for first location, $49.99 for each additional (monthly)
  /// - $755.90 for first location, $539.90 for each additional (annual)
  static Future<String> startCheckout({
    required String orgId,
    required String email,
    required String priceId,
    required int quantity,
  }) async {
    try {
      final Map<String, dynamic> payload = {'orgId': orgId, 'email': email, 'priceId': priceId, 'quantity': quantity};
      final response = await _call('createCheckoutSession', payload);
      final sessionUrl = response['url'] as String?;
      if (sessionUrl == null) {
        throw Exception('No session URL returned from backend');
      }
      return sessionUrl;
    } catch (e) {
      debugPrint('Error starting Stripe checkout: $e');
      rethrow;
    }
  }

  /// Convenience wrapper that both creates and launches the Checkout URL.
  ///
  /// Example usage:
  /// ```dart
  /// await StripeService.startCheckoutAndLaunch(
  ///   orgId: orgId,
  ///   email: userEmail,
  ///   priceId: isAnnual ? kStripePriceAnnual : kStripePriceMonthly,
  ///   quantity: locationCount,
  /// );
  /// ```
  static Future<void> startCheckoutAndLaunch({
    required String orgId,
    required String email,
    required String priceId,
    required int quantity,
  }) async {
    final url = await startCheckout(orgId: orgId, email: email, priceId: priceId, quantity: quantity);
    await _openUrlExternal(url);
  }

  /// Open Stripe Billing Portal for the organization
  static Future<void> openBillingPortal(String orgId) async {
    debugPrint('[StripeService] Opening billing portal for organization: $orgId');

    try {
      final response = await _call('createBillingPortalSession', {'orgId': orgId});
      final portalUrl = response['url'];

      if (portalUrl != null) {
        debugPrint('[StripeService] Opening billing portal URL');
        await _openUrlExternal(portalUrl);
      } else {
        debugPrint('[StripeService] ERROR: No portal URL returned from backend');
        throw Exception('No portal URL returned from backend');
      }
    } catch (e) {
      debugPrint('[StripeService] Error opening billing portal: $e');
      rethrow;
    }
  }

  /// Get subscription status from Firestore
  static Future<String?> getSubscriptionStatus(String orgId) async {
    try {
      final doc =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('stripe')
              .doc('subscription')
              .get();
      return doc.data()?['status'] as String?;
    } catch (e) {
      debugPrint('Error fetching subscription status: $e');
      return null;
    }
  }

  /// Get full subscription data from Firestore
  static Future<Map<String, dynamic>?> getSubscriptionData(String orgId) async {
    try {
      final doc =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('stripe')
              .doc('subscription')
              .get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Error fetching subscription data: $e');
      return null;
    }
  }

  /// Cancel subscription at period end
  static Future<void> cancelSubscription(String orgId) async {
    try {
      final response = await _call('cancelSubscription', {'orgId': orgId});
      debugPrint('Subscription cancellation response: $response');
    } catch (e) {
      debugPrint('Error canceling subscription: $e');
      rethrow;
    }
  }

  /// Update subscription quantity (e.g., number of locations)
  static Future<void> updateSubscriptionQuantity({
    required String orgId,
    required String subscriptionId,
    required int newQuantity,
  }) async {
    try {
      await _call('updateSubscription', {'orgId': orgId, 'subscriptionId': subscriptionId, 'newQuantity': newQuantity});
    } catch (e) {
      debugPrint('Error updating subscription quantity: $e');
      rethrow;
    }
  }

  @Deprecated('Use startCheckoutAndLaunch with priceId and quantity (locations) instead')
  static Future<void> redirectToStripeCheckout({
    required String orgId,
    required String email,
    required int employeeCount,
  }) async {
    // Legacy method - redirects to the new per-location pricing
    debugPrint('[StripeService] WARNING: Using deprecated redirectToStripeCheckout method');
    try {
      await startCheckoutAndLaunch(
        orgId: orgId,
        email: email,
        priceId: kStripePriceMonthly, // Default to monthly tiered pricing
        quantity: 1, // Default to 1 location for legacy calls
      );
    } catch (e) {
      debugPrint('Error in legacy checkout redirect: $e');
      rethrow;
    }
  }

  /// Activates the free tier for an organization by updating its status in Firestore.
  static Future<void> activateFreeTier({required String orgId}) async {
    try {
      await FirestoreEnforcer.instance.collection('organizations').doc(orgId).update({
        'subscriptionStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error activating free tier: $e');
      rethrow;
    }
  }
}
