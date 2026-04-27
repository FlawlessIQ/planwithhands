import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/core/providers/crashlytics_provider.dart';
import 'package:hands_app/features/releases/widgets/app_experience_coordinator.dart';
import 'package:hands_app/l10n/generated/app_localizations.dart';
import 'package:hands_app/routing/router_provider.dart';
import 'package:hands_app/services/local_storage_service.dart';
import 'package:hands_app/services/daily_background_service.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/state/app_locale_controller.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:async';

import 'package:hands_app/services/firebase_initializer_v6.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/services/session_manager.dart';
import 'package:hands_app/services/activity_tracker.dart';
import 'config/release_config.dart';

// Add Stripe import
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hands_app/services/stripe_web_helpers_stub.dart'
    if (dart.library.html) 'package:hands_app/services/stripe_web_helpers.dart'
    as web_helpers;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hands_app/services/pk_fetcher_stub.dart'
    if (dart.library.html) 'package:hands_app/services/pk_fetcher_web.dart'
    as pk_fetch;

Future<Map<String, dynamic>> _fetchStripePublishableKey() async {
  final callable = FirebaseFunctions.instance.httpsCallable(
    'getStripePublishableKey',
  );
  final result = await callable.call({});
  final data = result.data;
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return {'publishableKey': null};
}

void main() async {
  // Run the app inside a guarded zone and ensure the Flutter binding is
  // initialized inside that same zone to avoid the "Zone mismatch" error.
  runZonedGuarded<Future<void>>(
    () async {
      // Ensure the Widgets binding is initialized before using any
      // platform channels or WidgetsBinding.instance.
      WidgetsFlutterBinding.ensureInitialized();
      tz.initializeTimeZones();

      // Wrap critical startup in a try/catch so we can show a friendly
      // error UI if something fails during initialization.
      try {
        // Initialize our "safe" local storage service and Firebase.
        try {
          await LocalStorageService.init();
        } catch (e) {
          print('LocalStorage init failed (non-critical): $e');
          // Continue without local storage - the app can still function
        }

        await FirebaseInitializerV6().initialize();

        // Initialize location selection service to load persisted location
        try {
          await LocationSelectionService.instance.initialize();
        } catch (e) {
          print('LocationSelectionService init failed (non-critical): $e');
          // Continue without persisted location - the app can still function
        }

        // Let Flutter's generated plugin registrant handle web plugin registration.

        // Initialize Stripe on web before runApp
        try {
          if (kIsWeb) {
            // Try compile-time key first, then callable, then HTTP fallback
            String? pk = const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
            if (pk.isEmpty) {
              pk = null;
            }

            if (pk == null) {
              try {
                final pkResp = await _fetchStripePublishableKey();
                pk = pkResp['publishableKey'] as String?;
              } catch (e) {
                print(
                  '⚠️ [STRIPE] Failed to fetch publishable key from callable: $e',
                );
              }
            }

            if (pk == null || pk.isEmpty) {
              try {
                final projectId = Firebase.app().options.projectId;
                final fbPk = await pk_fetch.fetchPkHttpFallback(projectId);
                if (fbPk != null && fbPk.isNotEmpty) {
                  pk = fbPk;
                }
              } catch (e) {
                print(
                  '⚠️ [STRIPE] HTTP fallback for publishable key failed: $e',
                );
              }
            }

            if (pk != null && pk.isNotEmpty) {
              Stripe.publishableKey = pk;
              await Stripe.instance.applySettings();
              // Store pk for embedded checkout page consumption
              try {
                web_helpers.setStripePkForEmbedded(pk);
              } catch (_) {}
              print(
                '✅ [STRIPE] Web settings applied with key: ${pk.substring(0, 12)}...',
              );
            } else {
              print(
                '⚠️ [STRIPE] No publishable key available - Stripe disabled',
              );
            }
          }
        } catch (e) {
          print('⚠️ [STRIPE] Initialization failed: $e');
        }

        // Initialize push notifications (may fail on web in some browsers)
        try {
          await PushNotificationService().initialize();
        } catch (e) {
          print('Push notification init failed (non-critical): $e');
          // Continue without push notifications
        }

        // Initialize daily background service for automated summaries
        try {
          DailyBackgroundService.initialize();
        } catch (e) {
          print('Background service init failed (non-critical): $e');
          // Continue without background service
        }

        // Initialize session management for token refresh and validation
        try {
          await SessionManager().initialize();
        } catch (e) {
          print('Session manager init failed (non-critical): $e');
          // Continue without session management
        }

        // Initialize activity tracking for session management
        try {
          ActivityTracker().initialize();
        } catch (e) {
          print('Activity tracker init failed (non-critical): $e');
          // Continue without activity tracking
        }

        // Set up app lifecycle observer for proper cleanup
        final lifecycleObserver = _AppLifecycleObserver();
        WidgetsBinding.instance.addObserver(lifecycleObserver);
      } catch (e, st) {
        // If any of the above critical services fail, show an error UI and stop.
        print('Critical startup error: $e\n$st');
        runApp(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'App Initialization Error',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please refresh the page to try again.\n\nError: $e',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // On web, we can reload. On other platforms, this button won't appear anyway
                          if (kIsWeb) {
                            // Use JavaScript to reload the page
                            // ignore: avoid_web_libraries_in_flutter
                            //dart:html.window.location.reload();
                          }
                        },
                        child: const Text('Refresh Page'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return; // Halt execution of the zone callback.
      }

      if (kIsWeb) {
        usePathUrlStrategy();
      }

      bool crashlyticsEnabled = false;
      // Allow RELEASE_SCREENSHOTS to behave like a non-debug release for
      // privacy / overlay disabling when capturing store screenshots.
      final bool treatAsRelease = !kDebugMode || RELEASE_SCREENSHOTS;
      if (!kIsWeb && treatAsRelease) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          true,
        );
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        crashlyticsEnabled = true;
      }

      runApp(
        ProviderScope(
          overrides: [
            crashlyticsEnabledProvider.overrideWith((_) => crashlyticsEnabled),
          ],
          child: const HandsApp(),
        ),
      );
    },
    (error, stack) {
      if (!kIsWeb && !kDebugMode) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      print('Caught error in runZonedGuarded: $error');
    },
  );

  FlutterError.demangleStackTrace = (StackTrace stack) {
    if (stack is stack_trace.Trace) {
      return stack.vmTrace;
    }
    if (stack is stack_trace.Chain) {
      return stack.toTrace().vmTrace;
    }
    return stack;
  };
}

class HandsApp extends ConsumerStatefulWidget {
  const HandsApp({super.key});

  @override
  ConsumerState<HandsApp> createState() => _HandsAppState();
}

class _HandsAppState extends ConsumerState<HandsApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appLocaleControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final localeState = ref.watch(appLocaleControllerProvider);

    // Wrap entire app with global gesture detection for activity tracking
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => ActivityTracker().recordActivity(source: 'global_tap'),
      onScaleStart:
          (_) => ActivityTracker().recordActivity(source: 'global_interaction'),
      onScaleUpdate:
          (_) => ActivityTracker().recordActivity(source: 'global_interaction'),
      child: MaterialApp.router(
        title: 'Hands',
        locale: localeState.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: handsTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        builder:
            (context, child) => AppExperienceCoordinator(
              router: router,
              child: child ?? const SizedBox.shrink(),
            ),
      ),
    );
  }
}

// Add app lifecycle observer to properly dispose services
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      DailyBackgroundService.dispose();
      SessionManager().dispose();
      ActivityTracker().dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Validate session when app resumes from background
      SessionManager().handleAppResume();
      // Record activity on app resume
      ActivityTracker().recordActivity(source: 'app_resume');
    }
  }
}

// MARKER_003_123XYZ
