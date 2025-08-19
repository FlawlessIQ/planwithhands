import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/dashboard/pages/user_dashboard_page.dart';
import 'package:hands_app/features/dashboard/pages/admin_dashboard_page.dart';
import 'package:hands_app/features/dashboard/pages/manager_dashboard_page.dart';
import 'package:hands_app/features/auth/pages/login_page.dart';
import 'package:hands_app/features/auth/pages/account_creation_page_simple_branded.dart' as branded;
// import 'package:hands_app/features/auth/pages/invitation_page.dart';
import 'package:hands_app/features/settings/pages/settings_page.dart';
import 'package:hands_app/features/training/pages/training_materials_page.dart';
import 'package:hands_app/pages/notifications_page.dart';
import 'package:hands_app/pages/messages_page.dart';
import 'package:hands_app/features/messaging/pages/message_thread_page.dart';
import 'package:hands_app/pages/sign_in_page.dart';
import 'package:hands_app/pages/welcome_page.dart';
import 'package:hands_app/pages/payment_success_page.dart';
import 'package:hands_app/pages/payment_cancelled_page.dart';
import 'package:hands_app/ui/schedule_page.dart';

// Make sure that the NotificationsPage class is defined in notifications_page.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/constants/firestore_names.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/services/push_notification_service.dart';

enum AppRoutes {
  homePage('/'),
  accountCreationPage('/create_account'),
  loginPage('/login'),
  signInPage('/sign_in'),
  welcomePage('/welcome'),
  // invitePage('/invite'),
  trainingMaterialsPage('/training_materials'),
  settingsPage('/settings'),
  userDashboardPage('/user_dashboard'),
  adminDashboardPage('/admin_dashboard'),
  managerDashboardPage('/manager_dashboard'),
  schedulePage('/schedule'),
  messagesPage('/messages'),
  threadPage('/threads/:threadId'),
  notificationsPage('/notifications'),
  paymentSuccessPage('/payment-success'),
  paymentCancelledPage('/payment-cancelled');

  final String path;
  const AppRoutes(this.path);
}

class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in, go to login
      return const LoginPage();
    } else {
      // Logged in, show the protected page
      return child;
    }
  }
}

// New AuthGate variant that loads the organization ID then shows UserDashboardPage
class AuthGateWithOrg extends ConsumerWidget {
  const AuthGateWithOrg({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = authSnap.data;
        if (user == null) {
          return const LoginPage();
        }
        // now fetch org ID
        return FutureBuilder<DocumentSnapshot>(
          future: FirestoreEnforcer.instance.collection(FirestoreCollectionNames.users).doc(user.uid).get(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const LoginPage();
            }

            final userData = snap.data!.data() as Map<String, dynamic>?;
            if (userData == null) {
              return const LoginPage();
            }

            final userRole = userData['userRole'] as int? ?? 0;

            // Route users to appropriate dashboard based on role
            if (userRole >= 2) {
              // Admin - redirect to admin dashboard
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRoutes.adminDashboardPage.path);
              });
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            } else if (userRole >= 1) {
              // Manager - redirect to manager dashboard
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRoutes.managerDashboardPage.path);
              });
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // Regular user - show user dashboard
            return const UserDashboardPage();
          },
        );
      },
    );
  }
}

// New AuthGate variant that loads the organization ID then shows ManagerDashboardPage
class AuthGateWithOrgForManager extends ConsumerWidget {
  const AuthGateWithOrgForManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = authSnap.data;
        if (user == null) {
          return const LoginPage();
        }
        // now fetch org ID
        return FutureBuilder<DocumentSnapshot>(
          future: FirestoreEnforcer.instance.collection(FirestoreCollectionNames.users).doc(user.uid).get(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const LoginPage();
            }
            final userData = snap.data!.data() as Map<String, dynamic>?;
            if (userData == null) {
              return const LoginPage();
            }

            final userRole = userData['userRole'] as int? ?? 0;
            final orgId = userData['organizationId'] as String? ?? '';

            // Only block access for non-managers
            if (userRole < 1 || orgId.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go(AppRoutes.userDashboardPage.path);
              });
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            // Allow both managers and admins to view this page
            return ManagerDashboardPage(organizationId: orgId);
          },
        );
      },
    );
  }
}

// New AuthGate variant that loads the organization ID then shows AdminDashboardPage
class AuthGateWithOrgForAdmin extends ConsumerWidget {
  const AuthGateWithOrgForAdmin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = authSnap.data;
        if (user == null) {
          return const LoginPage();
        }
        // now fetch org ID and check admin access
        return FutureBuilder<DocumentSnapshot>(
          future: FirestoreEnforcer.instance.collection(FirestoreCollectionNames.users).doc(user.uid).get(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!snap.hasData || !snap.data!.exists) {
              return const LoginPage();
            }

            final userData = snap.data!.data() as Map<String, dynamic>?;
            if (userData == null) {
              return const LoginPage();
            }

            final userRole = userData['userRole'] as int? ?? 0;
            final orgId = userData['organizationId'] as String?;

            // Check if user is admin and has organization
            if (userRole != 2 || orgId == null) {
              // Not an admin, redirect to appropriate dashboard
              if (userRole == 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  context.go(AppRoutes.managerDashboardPage.path);
                });
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  context.go(AppRoutes.userDashboardPage.path);
                });
              }
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            return const AdminDashboardPage();
          },
        );
      },
    );
  }
}

class _ThreadRouteGate extends ConsumerWidget {
  final String threadId;
  const _ThreadRouteGate({required this.threadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginPage();
    return FutureBuilder<DocumentSnapshot>(
      future: FirestoreEnforcer.instance.collection(FirestoreCollectionNames.users).doc(user.uid).get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData || !snap.data!.exists) return const LoginPage();
        final data = snap.data!.data() as Map<String, dynamic>?;
        final orgId = data?['organizationId'] as String?;
        if (orgId == null) return const LoginPage();
        return MessageThreadPage(orgId: orgId, threadId: threadId);
      },
    );
  }
}

final router = GoRouter(
  navigatorKey: PushNotificationService.navigatorKey,
  redirect: (context, state) {
    // Debug logging for ALL routing
    debugPrint('[ROUTER] ===============================');
    debugPrint('[ROUTER] TESTING - Current path: ${state.matchedLocation}');
    debugPrint('[ROUTER] TESTING - URI path: ${state.uri.path}');
    debugPrint('[ROUTER] TESTING - Full path: ${state.fullPath}');
    debugPrint('[ROUTER] TESTING - Query params: ${state.uri.queryParameters}');
    debugPrint('[ROUTER] TESTING - Raw URI: ${state.uri.toString()}');
    debugPrint('[ROUTER] TESTING - Browser URL: ${Uri.base.toString()}');
    debugPrint('[ROUTER] ===============================');

    // AGGRESSIVE BROWSER URL PARSING
    final browserUri = Uri.base;
    final routerPath = state.uri.path;

    debugPrint('[ROUTER] Browser path: ${browserUri.path}');
    debugPrint('[ROUTER] Router path: $routerPath');

    // If browser shows welcome but router doesn't, force welcome navigation
    if (browserUri.path == '/welcome' && routerPath != '/welcome') {
      debugPrint('[ROUTER] *** FORCING WELCOME NAVIGATION ***');
      final email = browserUri.queryParameters['email'];
      final orgId = browserUri.queryParameters['orgId'];
      final inviteId = browserUri.queryParameters['inviteId'];

      if (email != null && orgId != null) {
        final welcomeUrl = '/welcome?email=$email&orgId=$orgId&inviteId=${inviteId ?? ''}';
        debugPrint('[ROUTER] Redirecting to: $welcomeUrl');
        return welcomeUrl;
      }
    }

    // Stripe return/cancel legacy links: /dashboard?payment=success or /dashboard?payment=cancel
    if (routerPath == '/dashboard') {
      final paymentParam = state.uri.queryParameters['payment'];
      if (paymentParam == 'success') {
        return AppRoutes.paymentSuccessPage.path;
      } else if (paymentParam == 'cancel') {
        return AppRoutes.paymentCancelledPage.path;
      }
    }

    return null;
  },
  // Default to home, which will redirect to the appropriate dashboard
  initialLocation: AppRoutes.homePage.path,
  routes: [
    GoRoute(path: AppRoutes.homePage.path, builder: (context, state) => const AuthGateWithOrg()),
    // Invite route removed
    GoRoute(
      path: AppRoutes.accountCreationPage.path,
      builder: (context, state) {
        return const branded.SimpleSignUpPage();
      },
    ),
    GoRoute(path: AppRoutes.loginPage.path, builder: (context, state) => const LoginPage()),
    GoRoute(path: AppRoutes.signInPage.path, builder: (context, state) => const SignInPage()),
    GoRoute(
      path: AppRoutes.welcomePage.path,
      builder:
          (context, state) => WelcomePage(
            email: state.uri.queryParameters['email'],
            organizationId: state.uri.queryParameters['orgId'],
            inviteId: state.uri.queryParameters['inviteId'],
            mode: state.uri.queryParameters['mode'],
          ),
    ),
    GoRoute(path: AppRoutes.settingsPage.path, builder: (context, state) => const AuthGate(child: HandsSettingsPage())),
    GoRoute(
      path: AppRoutes.userDashboardPage.path,
      // Simple auth gate so admins and managers can navigate here directly
      builder: (context, state) => const AuthGate(child: UserDashboardPage()),
    ),
    GoRoute(path: AppRoutes.adminDashboardPage.path, builder: (context, state) => const AuthGateWithOrgForAdmin()),
    GoRoute(path: AppRoutes.managerDashboardPage.path, builder: (context, state) => const AuthGateWithOrgForManager()),
    GoRoute(path: AppRoutes.schedulePage.path, builder: (context, state) => const AuthGate(child: SchedulePage())),
    GoRoute(path: AppRoutes.messagesPage.path, builder: (context, state) => const AuthGate(child: MessagesPage())),
    GoRoute(
      path: AppRoutes.threadPage.path,
      builder: (context, state) {
        final threadId = state.pathParameters['threadId']!;
        return _ThreadRouteGate(threadId: threadId);
      },
    ),
    GoRoute(
      path: AppRoutes.notificationsPage.path,
      builder: (context, state) => const AuthGate(child: NotificationsPage()),
    ),
    GoRoute(
      path: AppRoutes.trainingMaterialsPage.path,
      builder: (context, state) {
        // Pass any extra data (like userRole) to the page
        return const AuthGate(child: ViewDocumentsPage());
      },
    ),
    GoRoute(path: AppRoutes.paymentSuccessPage.path, builder: (context, state) => const PaymentSuccessPage()),
    GoRoute(path: AppRoutes.paymentCancelledPage.path, builder: (context, state) => const PaymentCancelledPage()),
  ],
);
