import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:hands_app/features/dashboard/pages/user_dashboard_page.dart';
import 'package:hands_app/features/dashboard/pages/admin_dashboard_page.dart';
import 'package:hands_app/features/dashboard/pages/WEB_admin_dashboard_page.dart'
    show WEBAdminDashboardPage, WebAdminTab;
import 'package:hands_app/features/dashboard/pages/manager_dashboard_page.dart';
import 'package:hands_app/features/dashboard/pages/WEB_manager_dashboard_page.dart' as web_manager;
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
import 'package:hands_app/core/logging/logger.dart';

// Helper function to build the appropriate admin setup page based on platform
Widget _buildAdminSetupPage(BuildContext ctx, {required String organizationId, String? tab}) {
  // Check if we should use the web version based on screen size and device characteristics
  final mediaQuery = MediaQuery.of(ctx);
  final screenWidth = mediaQuery.size.width;
  final screenHeight = mediaQuery.size.height;
  final isLargeScreen = screenWidth >= 1024; // Desktop/large tablet threshold
  final aspectRatio = screenWidth / screenHeight;
  final isLandscapeDesktop = aspectRatio > 1.3 && screenWidth >= 1024;

  // Use web version for desktop-like environments (large screens in landscape)
  // Use mobile version for mobile devices, even when accessing via web
  // Allow forcing the web layout via ?forceWeb=true in the browser URL (useful for debugging)
  final forceWeb = Uri.base.queryParameters['forceWeb'] == 'true';
  final useWebVersion = forceWeb || (kIsWeb && (isLargeScreen || isLandscapeDesktop));

  debugPrint(
    'Admin route -> ${useWebVersion ? 'WEB' : 'MOBILE'} | width=$screenWidth height=$screenHeight ratio=${aspectRatio.toStringAsFixed(2)} | orgId=$organizationId tab=$tab',
  );

  // Convert string tab to WebAdminTab enum for web version
  WebAdminTab? webAdminTab;
  if (forceWeb) {
    debugPrint('[ROUTES] forceWeb=true -> forcing WEB admin layout');
  }
  if (tab != null && useWebVersion) {
    switch (tab.toLowerCase()) {
      case 'shifts':
        webAdminTab = WebAdminTab.shifts;
        break;
      case 'checklists':
        webAdminTab = WebAdminTab.checklists;
        break;
      case 'users':
        webAdminTab = WebAdminTab.users;
        break;
      case 'locations':
        webAdminTab = WebAdminTab.locations;
        break;
    }
  }

  return useWebVersion
      ? WEBAdminDashboardPage(organizationId: organizationId, initialTab: webAdminTab)
      : AdminDashboardPage();
}

// Helper function to build the appropriate manager dashboard page based on platform
Widget _buildManagerDashboardPage(BuildContext ctx, {required String organizationId}) {
  // Check if we should use the web version based on screen size and device characteristics
  final mediaQuery = MediaQuery.of(ctx);
  final screenWidth = mediaQuery.size.width;
  final screenHeight = mediaQuery.size.height;
  final isLargeScreen = screenWidth >= 1024; // Desktop/large tablet threshold
  final aspectRatio = screenWidth / screenHeight;
  final isLandscapeDesktop = aspectRatio > 1.3 && screenWidth >= 1024;

  // Use web version for desktop-like environments (large screens in landscape)
  // Use mobile version for mobile devices, even when accessing via web
  final useWebVersion = kIsWeb && (isLargeScreen || isLandscapeDesktop);

  debugPrint(
    'Manager route -> ${useWebVersion ? 'WEB' : 'MOBILE'} | width=$screenWidth height=$screenHeight ratio=${aspectRatio.toStringAsFixed(2)} | orgId=$organizationId',
  );

  return useWebVersion
      ? web_manager.ManagerDashboardPage(organizationId: organizationId)
      : ManagerDashboardPage(organizationId: organizationId);
}

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
  adminPage('/admin'),
  setupPage('/setup'),
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
            return _buildManagerDashboardPage(context, organizationId: orgId);
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
        logger.d('[AUTH_GATE_ADMIN] stream state=${authSnap.connectionState} userPresent=${authSnap.data != null}');
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = authSnap.data;
        if (user == null) {
          logger.d('[AUTH_GATE_ADMIN] No user -> LoginPage');
          return const LoginPage();
        }
        // now fetch org ID and check admin access
        return FutureBuilder<DocumentSnapshot>(
          future: FirestoreEnforcer.instance.collection(FirestoreCollectionNames.users).doc(user.uid).get(),
          builder: (context, snap) {
            logger.d(
              '[AUTH_GATE_ADMIN] user=${user.uid} future state=${snap.connectionState} hasData=${snap.hasData} exists=${snap.data?.exists}',
            );
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!snap.hasData || !snap.data!.exists) {
              logger.d('[AUTH_GATE_ADMIN] Missing user doc -> LoginPage');
              return const LoginPage();
            }

            final userData = snap.data!.data() as Map<String, dynamic>?;
            if (userData == null) {
              logger.d('[AUTH_GATE_ADMIN] Null userData -> LoginPage');
              return const LoginPage();
            }

            final userRole = userData['userRole'] as int? ?? 0;
            final orgId = userData['organizationId'] as String?;
            logger.d('[AUTH_GATE_ADMIN] role=$userRole orgId=$orgId');

            // Check if user is admin and has organization
            if (userRole != 2 || orgId == null) {
              logger.d('[AUTH_GATE_ADMIN] Not admin or missing org; rerouting');
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

            logger.d('[AUTH_GATE_ADMIN] Authorized admin -> routing to guarded setup');
            // Use our new guarded route to ensure web gets WEB page
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go(AppRoutes.setupPage.path, extra: orgId);
            });
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

// Unified AuthGate for all admin routes that handles web/mobile conditional rendering
class AuthGateForAdminSetup extends ConsumerWidget {
  final String? initialTab;

  const AuthGateForAdminSetup({this.initialTab, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        logger.d(
          '[AUTH_GATE_ADMIN_SETUP] stream state=${authSnap.connectionState} userPresent=${authSnap.data != null}',
        );
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = authSnap.data;
        if (user == null) {
          logger.d('[AUTH_GATE_ADMIN_SETUP] No user -> LoginPage');
          return const LoginPage();
        }
        // Fetch org ID and check admin access
        return FutureBuilder<DocumentSnapshot>(
          future: FirestoreEnforcer.instance.collection(FirestoreCollectionNames.users).doc(user.uid).get(),
          builder: (context, snap) {
            logger.d(
              '[AUTH_GATE_ADMIN_SETUP] user=${user.uid} future state=${snap.connectionState} hasData=${snap.hasData} exists=${snap.data?.exists}',
            );
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (!snap.hasData || !snap.data!.exists) {
              logger.d('[AUTH_GATE_ADMIN_SETUP] Missing user doc -> LoginPage');
              return const LoginPage();
            }

            final userData = snap.data!.data() as Map<String, dynamic>?;
            if (userData == null) {
              logger.d('[AUTH_GATE_ADMIN_SETUP] Null userData -> LoginPage');
              return const LoginPage();
            }

            final userRole = userData['userRole'] as int? ?? 0;
            final orgId = userData['organizationId'] as String?;
            logger.d('[AUTH_GATE_ADMIN_SETUP] role=$userRole orgId=$orgId initialTab=$initialTab');

            // Check if user is admin and has organization
            if (userRole != 2 || orgId == null) {
              logger.d('[AUTH_GATE_ADMIN_SETUP] Not admin or missing org; rerouting');
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

            logger.d('[AUTH_GATE_ADMIN_SETUP] Authorized admin -> Admin setup page (web: $kIsWeb)');
            // Use the helper function to build the appropriate page
            return _buildAdminSetupPage(context, organizationId: orgId, tab: initialTab);
          },
        );
      },
    );
  }
}

final router = GoRouter(
  navigatorKey: PushNotificationService.navigatorKey,
  redirect: (context, state) {
    // Debug logging for ALL routing
    logger.d('[ROUTER] ===============================');
    logger.d('[ROUTER] TESTING - Current path: ${state.matchedLocation}');
    logger.d('[ROUTER] TESTING - URI path: ${state.uri.path}');
    logger.d('[ROUTER] TESTING - Full path: ${state.fullPath}');
    logger.d('[ROUTER] TESTING - Query params: ${state.uri.queryParameters}');
    logger.d('[ROUTER] TESTING - Raw URI: ${state.uri.toString()}');
    logger.d('[ROUTER] TESTING - Browser URL: ${Uri.base.toString()}');
    logger.d('[ROUTER] ===============================');

    // AGGRESSIVE BROWSER URL PARSING
    final browserUri = Uri.base;
    final routerPath = state.uri.path;

    logger.d('[ROUTER] Browser path: ${browserUri.path}');
    logger.d('[ROUTER] Router path: $routerPath');

    // If browser shows welcome but router doesn't, force welcome navigation
    if (browserUri.path == '/welcome' && routerPath != '/welcome') {
      logger.d('[ROUTER] *** FORCING WELCOME NAVIGATION ***');
      final email = browserUri.queryParameters['email'];
      final orgId = browserUri.queryParameters['orgId'];
      final inviteId = browserUri.queryParameters['inviteId'];

      if (email != null && orgId != null) {
        final welcomeUrl = '/welcome?email=$email&orgId=$orgId&inviteId=${inviteId ?? ''}';
        logger.d('[ROUTER] Redirecting to: $welcomeUrl');
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
    GoRoute(
      path: AppRoutes.adminDashboardPage.path,
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        return AuthGateForAdminSetup(initialTab: tab);
      },
    ),
    GoRoute(
      path: AppRoutes.adminPage.path,
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        return AuthGateForAdminSetup(initialTab: tab);
      },
    ),
    GoRoute(
      path: AppRoutes.setupPage.path,
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab']; // 'shifts' | 'checklists' | 'users' | 'locations'
        return AuthGateForAdminSetup(initialTab: tab);
      },
    ),
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
