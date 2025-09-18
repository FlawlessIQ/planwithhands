import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:hands_app/services/stripe_web_helpers_stub.dart'
    if (dart.library.html) 'package:hands_app/services/stripe_web_helpers.dart'
    as web_helpers;

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

  /// Create subscription using Stripe Elements (embedded payment)
  static Future<Map<String, dynamic>> createSubscriptionElements({
    required String orgId,
    required String priceId,
    required int quantity,
    required String email,
    int? trialDays,
    String? couponId,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'orgId': orgId,
        'priceId': priceId,
        'quantity': quantity,
        'email': email,
        if (trialDays != null) 'trialDays': trialDays,
        if (couponId != null && couponId.isNotEmpty) 'couponId': couponId,
      };
      final response = await _call('createSubscriptionElements', payload);
      return response;
    } catch (e) {
      debugPrint('Error creating subscription with Elements: $e');
      rethrow;
    }
  }

  /// WEB ONLY: Start Stripe Embedded Checkout in the same tab.
  static Future<void> startEmbeddedCheckoutWeb({
    required String orgId,
    required String priceId,
    int quantity = 1,
    int? trialDays,
    String? couponId,
  }) async {
    assert(kIsWeb, 'startEmbeddedCheckoutWeb should only be called on web');
    // Use compile-time variable for the publishable key.
    // This avoids the CORS issue with the Cloud Function.
    const publishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    if (publishableKey.isNotEmpty) {
      web_helpers.setStripePkForEmbedded(publishableKey);
    } else {
      // It's recommended to always have a key.
      debugPrint('[StripeService] WARNING: STRIPE_PUBLISHABLE_KEY is not set. Stripe may not work.');
    }

    final resp = await _call('createEmbeddedCheckoutSession', {
      'orgId': orgId,
      'priceId': priceId,
      'quantity': quantity,
      'returnBaseUrl': web_helpers.currentOrigin(),
      if (couponId != null && couponId.isNotEmpty) 'couponId': couponId,
      if (trialDays != null) 'trialDays': trialDays,
    });
    final clientSecret = resp['client_secret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw Exception('Missing client_secret from createEmbeddedCheckoutSession');
    }
    if (publishableKey.isNotEmpty) {
      web_helpers.navigateToEmbeddedCheckoutWithPk(clientSecret, publishableKey);
    } else {
      web_helpers.navigateToEmbeddedCheckout(clientSecret);
    }
  }

  /// Start Stripe Checkout for per-location price, returning the session URL.
  /// NOT SUPPORTED ON WEB - use createSubscriptionElements instead.
  ///
  /// Use per-location price IDs (flat pricing):
  /// - Monthly: kStripePriceMonthly (flat per-location)
  /// - Annual: kStripePriceAnnual (flat per-location with annual discount)
  ///
  /// The quantity parameter must be the number of locations.
  static Future<String> startCheckout({
    required String orgId,
    required String email,
    required String priceId,
    required int quantity,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('startCheckout is not supported on web. Use createSubscriptionElements instead.');
    }

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
  /// NOT SUPPORTED ON WEB - use createSubscriptionElements instead.
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
    if (kIsWeb) {
      throw UnsupportedError('startCheckoutAndLaunch is not supported on web. Use createSubscriptionElements instead.');
    }

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

  /// Get subscription data, hydrating from Stripe if Firestore shows missing or 'incomplete' status.
  /// Also persists a minimal status/quantity update back to Firestore for consistency.
  static Future<Map<String, dynamic>?> getSubscriptionDataHydrated(String orgId) async {
    final fsData = await getSubscriptionData(orgId);
    final status = fsData != null ? (fsData['status'] as String?) : null;
    final qty = fsData != null ? (fsData['quantity'] as int?) : null;
    final missingOrInvalidQuantity = (qty == null || qty <= 0);
    final needsHydration = (status == null || status.isEmpty || status == 'incomplete' || missingOrInvalidQuantity);

    if (!needsHydration) return fsData;

    try {
      final live = await _call('getSubscriptionData', {'orgId': orgId});
      if (live.isNotEmpty) {
        // Write back minimal fields to Firestore to fix stale status
        try {
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('stripe')
              .doc('subscription')
              .set({
                if (live['status'] != null) 'status': live['status'],
                if (live['quantity'] != null) 'quantity': live['quantity'],
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        } catch (persistErr) {
          debugPrint('[StripeService] Failed to write hydrated status: $persistErr');
        }
        // Merge live into fs snapshot for richer data where present
        return {if (fsData != null) ...fsData, ...Map<String, dynamic>.from(live)};
      }
    } catch (e) {
      debugPrint('[StripeService] Hydration call failed: $e');
    }
    return fsData;
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
    if (kIsWeb) {
      throw UnsupportedError(
        'redirectToStripeCheckout is not supported on web. Use createSubscriptionElements instead.',
      );
    }

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

  /// Validates a coupon code with Stripe and returns coupon details
  static Future<Map<String, dynamic>?> validateCoupon(String couponCode) async {
    try {
      debugPrint('[StripeService] Validating coupon: $couponCode');
      final result = await _call('validateCoupon', {'couponCode': couponCode.trim().toUpperCase()});
      debugPrint('[StripeService] Coupon validation result: $result');

      // Accept multiple backend response shapes: { success, coupon }, { valid, promotion }, etc.
      final success = (result['success'] == true) || (result['valid'] == true);
      final raw =
          (result['coupon'] is Map)
              ? Map<String, dynamic>.from(result['coupon'])
              : (result['promotion'] is Map)
              ? Map<String, dynamic>.from(result['promotion'])
              : (result['promotionCode'] is Map)
              ? Map<String, dynamic>.from(result['promotionCode'])
              : (result['data'] is Map)
              ? Map<String, dynamic>.from(result['data'])
              : result.isNotEmpty
              ? result
              : null;

      debugPrint('[StripeService] Success: $success, Raw data: $raw');

      if (success && raw != null) {
        // Normalize numeric fields to int to satisfy UI expectations
        final num? percentOffNum = (raw['percent_off'] ?? raw['percentOff']) as num?;
        final num? amountOffNum = (raw['amount_off'] ?? raw['amountOff']) as num?;

        final validatedCoupon = {
          'valid': true,
          'id': raw['id'] ?? raw['code'],
          'percentOff': percentOffNum?.round(),
          'amountOff': amountOffNum?.round(),
          'currency': raw['currency'],
          'name': raw['name'] ?? raw['code'] ?? raw['id'],
          'duration': raw['duration'],
          'durationInMonths': raw['duration_in_months'] ?? raw['durationInMonths'],
          'timesRedeemed': raw['times_redeemed'] ?? raw['timesRedeemed'],
          'maxRedemptions': raw['max_redemptions'] ?? raw['maxRedemptions'],
          'redeemBy': raw['redeem_by'] ?? raw['redeemBy'],
          'isValid': raw['valid'] ?? true,
        };
        debugPrint('[StripeService] Returning validated coupon: $validatedCoupon');
        return validatedCoupon;
      }

      debugPrint('[StripeService] Coupon validation failed');
      return {'valid': false, 'error': result['error'] ?? 'Invalid coupon code'};
    } catch (e) {
      debugPrint('[StripeService] Error validating coupon: $e');
      return {'valid': false, 'error': 'Failed to validate coupon. Please try again.'};
    }
  }

  /// Get checkout session status
  static Future<Map<String, dynamic>> getCheckoutSessionStatus(String sessionId) async {
    try {
      final result = await _call('getCheckoutSessionStatus', {'sessionId': sessionId});
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error getting checkout session status: $e');
      rethrow;
    }
  }
}
