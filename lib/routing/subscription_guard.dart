import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/features/auth/pages/login_page.dart';
import 'package:hands_app/billing/embedded_payment_page.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/config/feature_flags.dart';
import 'package:hands_app/services/subscription_access_service.dart';

/// Subscription guard that ensures users have valid subscription before accessing app features
///
/// This guard checks:
/// 1. User is authenticated
/// 2. User has organization ID
/// 3. Organization has valid subscription status (active, trialing, trial)
/// 4. If not, redirects to embedded payment page
class SubscriptionGuard extends ConsumerWidget {
  final Widget child;

  const SubscriptionGuard({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        logger.d(
          '[SubscriptionGuard] Auth state: ${authSnap.connectionState}, user: ${authSnap.data?.uid}',
        );

        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;
        if (user == null) {
          logger.d('[SubscriptionGuard] No user, redirecting to login');
          return const LoginPage();
        }

        // Fetch user data to get organization ID
        return FutureBuilder<DocumentSnapshot>(
          future:
              FirestoreEnforcer.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
          builder: (context, userSnap) {
            logger.d(
              '[SubscriptionGuard] User doc state: ${userSnap.connectionState}, exists: ${userSnap.data?.exists}',
            );

            if (userSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnap.hasData || !(userSnap.data?.exists ?? false)) {
              logger.w(
                '[SubscriptionGuard] User document not found, redirecting to login',
              );
              return const LoginPage();
            }

            final userData = userSnap.data?.data() as Map<String, dynamic>?;
            if (userData == null) {
              logger.w(
                '[SubscriptionGuard] User data is null, redirecting to login',
              );
              return const LoginPage();
            }

            final orgId = userData['organizationId'] as String?;
            final userEmail = userData['email'] as String? ?? user.email ?? '';

            if (orgId == null) {
              logger.w(
                '[SubscriptionGuard] No organization ID found, redirecting to login',
              );
              return const LoginPage();
            }

            logger.d(
              '[SubscriptionGuard] User has orgId: $orgId, checking subscription...',
            );

            // Check subscription status
            return FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait([
                FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(orgId)
                    .get(),
                FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(orgId)
                    .collection('stripe')
                    .doc('subscription')
                    .get(),
              ]),
              builder: (context, accessSnap) {
                logger.d(
                  '[SubscriptionGuard] Access state: ${accessSnap.connectionState}',
                );

                if (accessSnap.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final organizationData =
                    accessSnap.data?[0].data() as Map<String, dynamic>?;
                final subscriptionData =
                    accessSnap.data?[1].data() as Map<String, dynamic>?;
                if (!SubscriptionAccessService.hasAccess(
                  organizationData: organizationData,
                  subscriptionData: subscriptionData,
                )) {
                  logger.w(
                    '[SubscriptionGuard] No active billing or valid trial, redirecting to payment',
                  );
                  return _buildPaymentRedirect(orgId: orgId, email: userEmail);
                }

                logger.d(
                  '[SubscriptionGuard] Subscription is valid, allowing access',
                );
                // Subscription is valid, show the protected content
                return child;
              },
            );
          },
        );
      },
    );
  }

  /// Helper method to get the appropriate quantity for payment redirect
  static Future<int> _getQuantityForPayment(String orgId) async {
    try {
      // First try to get the organization document to check for intended quantity
      final orgDoc =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .get();

      if (orgDoc.exists) {
        final orgData = orgDoc.data();
        final intendedQuantity = orgData?['intendedLocationQuantity'] as int?;

        if (intendedQuantity != null && intendedQuantity > 0) {
          logger.d(
            '[SubscriptionGuard] Using intended location quantity: $intendedQuantity',
          );
          return intendedQuantity;
        }
      }

      // Fallback to counting existing locations for existing organizations
      final locationQuery =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(orgId)
              .collection('locations')
              .get();

      final locationCount = locationQuery.size;
      final quantity = locationCount > 0 ? locationCount : 1;

      logger.d(
        '[SubscriptionGuard] No intended quantity found, using location count: $quantity',
      );
      return quantity;
    } catch (e) {
      logger.e('[SubscriptionGuard] Error getting quantity for payment: $e');
      return 1; // Safe fallback
    }
  }

  Widget _buildPaymentRedirect({required String orgId, required String email}) {
    return FutureBuilder<int>(
      future: SubscriptionGuard._getQuantityForPayment(orgId),
      builder: (context, quantitySnap) {
        if (quantitySnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final quantity = quantitySnap.data ?? 1;
        logger.d('[SubscriptionGuard] Using quantity: $quantity');

        return EmbeddedPaymentPage(
          orgId: orgId,
          email: email,
          priceIdMonthly: kStripePriceMonthly,
          priceIdAnnual: kStripePriceAnnual,
          quantity: quantity,
        );
      },
    );
  }
}

/// Subscription guard specifically for routes that need valid subscription
class SubscriptionGuardWithContext extends ConsumerWidget {
  final Widget child;

  const SubscriptionGuardWithContext({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnap.data;
        if (user == null) {
          // Use context.go for navigation-based redirects
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(AppRoutes.loginPage.path);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Fetch user data to get organization ID
        return FutureBuilder<DocumentSnapshot>(
          future:
              FirestoreEnforcer.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
          builder: (context, userSnap) {
            if (userSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnap.hasData || !(userSnap.data?.exists ?? false)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go(AppRoutes.loginPage.path);
                }
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userData = userSnap.data?.data() as Map<String, dynamic>?;
            if (userData == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go(AppRoutes.loginPage.path);
                }
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final orgId = userData['organizationId'] as String?;
            final userEmail = userData['email'] as String? ?? user.email ?? '';

            if (orgId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go(AppRoutes.loginPage.path);
                }
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Check subscription status
            return FutureBuilder<List<DocumentSnapshot>>(
              future: Future.wait([
                FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(orgId)
                    .get(),
                FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(orgId)
                    .collection('stripe')
                    .doc('subscription')
                    .get(),
              ]),
              builder: (context, accessSnap) {
                if (accessSnap.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final organizationData =
                    accessSnap.data?[0].data() as Map<String, dynamic>?;
                final subscriptionData =
                    accessSnap.data?[1].data() as Map<String, dynamic>?;
                if (!SubscriptionAccessService.hasAccess(
                  organizationData: organizationData,
                  subscriptionData: subscriptionData,
                )) {
                  // Get appropriate quantity before redirecting
                  SubscriptionGuard._getQuantityForPayment(orgId).then((
                    quantity,
                  ) {
                    if (context.mounted) {
                      context.go(
                        '${AppRoutes.embeddedPaymentPage.path}?orgId=$orgId&email=$userEmail&quantity=$quantity',
                      );
                    }
                  });
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // Subscription is valid, show the protected content
                return child;
              },
            );
          },
        );
      },
    );
  }
}

/// Subscription guard for admin dashboard routes with specific admin setup logic
class SubscriptionGuardWithAdminSetup extends ConsumerWidget {
  final String? initialTab;

  const SubscriptionGuardWithAdminSetup({this.initialTab, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SubscriptionGuard(
      child: AuthGateForAdminSetup(initialTab: initialTab),
    );
  }
}

/// Subscription guard for manager dashboard routes
class SubscriptionGuardForManager extends ConsumerWidget {
  const SubscriptionGuardForManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SubscriptionGuard(child: AuthGateWithOrgForManager());
  }
}
