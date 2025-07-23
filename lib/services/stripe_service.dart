import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  /// Set Stripe publishable key (call this at app startup)
  static void initStripe() {
    Stripe.publishableKey = 'pk_live_51QpYFkFzroJ5o7DACsVjbkUhzJ0fy8vLS2G517jlVJAwwKWtJDp0ZQAU3BY9ci5ItwPCfS1aF8dnu0zR26wAwl5R00wohDkexI';
  }

  /// Start Stripe Checkout for a given tier/price
  static Future<void> startCheckout({
    required String orgId,
    required String email,
    required String priceId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
      final response = await callable.call({
        'orgId': orgId,
        'email': email,
        'priceId': priceId,
      });
      final sessionUrl = response.data['url'];
      if (sessionUrl != null) {
        await launchUrl(Uri.parse(sessionUrl), mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No session URL returned from backend');
      }
    } catch (e) {
      debugPrint('Error starting Stripe checkout: $e');
      rethrow;
    }
  }

  /// Open Stripe Billing Portal for the organization
  static Future<void> openBillingPortal(String orgId) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createBillingPortalSession');
      final response = await callable.call({'orgId': orgId});
      final portalUrl = response.data['url'];
      if (portalUrl != null) {
        await launchUrl(Uri.parse(portalUrl), mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No portal URL returned from backend');
      }
    } catch (e) {
      debugPrint('Error opening billing portal: $e');
      rethrow;
    }
  }

  /// Get subscription status from Firestore
  static Future<String?> getSubscriptionStatus(String orgId) async {
    try {
      final doc = await FirebaseFirestore.instance
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
      final doc = await FirebaseFirestore.instance
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
      final callable = FirebaseFunctions.instance.httpsCallable('cancelSubscription');
      final response = await callable.call({'orgId': orgId});
      debugPrint('Subscription cancellation response: ${response.data}');
    } catch (e) {
      debugPrint('Error canceling subscription: $e');
      rethrow;
    }
  }

  /// Start Stripe Checkout for employee count change
  static Future<void> redirectToStripeCheckout({
    required String orgId,
    required String email,
    required int employeeCount,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
      final response = await callable.call({
        'orgId': orgId,
        'email': email,
        'employeeCount': employeeCount,
      });
      final sessionUrl = response.data['url'];
      if (sessionUrl != null) {
        await launchUrl(Uri.parse(sessionUrl), mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No session URL returned from backend');
      }
    } catch (e) {
      debugPrint('Error starting Stripe checkout: $e');
      rethrow;
    }
  }

  /// Activates the free tier for an organization by updating its status in Firestore.
  static Future<void> activateFreeTier({required String orgId}) async {
    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .update({
        'subscriptionStatus': 'active',
        'employeeCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error activating free tier: $e');
      rethrow;
    }
  }
}
