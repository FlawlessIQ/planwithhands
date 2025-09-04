import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/core/providers/crashlytics_provider.dart';
import 'package:hands_app/routing/router_provider.dart';
import 'package:hands_app/services/local_storage_service.dart';
import 'package:hands_app/services/daily_background_service.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:async';

import 'package:hands_app/services/firebase_initializer.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/debug/firebase_init_test.dart'; // Import Firebase test page
import 'package:firebase_core/firebase_core.dart';
import 'package:hands_app/firebase_options.dart';
// No longer need web platform page since we're allowing direct web access
// import 'package:hands_app/pages/web_platform_page.dart';
// No longer checking user agent for mobile browsers
// import 'platform/user_agent_stub.dart' if (dart.library.html) 'platform/user_agent_web.dart';
import 'config/release_config.dart';

// Mobile browser detection removed - now allowing all browsers to access web app
// This enables seamless access from marketing site to app for both desktop and mobile users

// Special parameter to enable Firebase debug mode
const String FIREBASE_DEBUG_PARAM = 'firebaseDebug';

void main() async {
  // Set URL strategy early to ensure proper URL handling
  usePathUrlStrategy();

  // If we should show the Firebase debug page, short-circuit and show it now.
  if (kIsWeb && Uri.base.queryParameters.containsKey(FIREBASE_DEBUG_PARAM)) {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(MaterialApp(debugShowCheckedModeBanner: false, home: SafeArea(child: FirebaseInitTest())));
    return;
  }

  // Run the app inside a guarded zone and ensure the Flutter binding is
  // initialized inside that same zone to avoid the "Zone mismatch" error.
  runZonedGuarded<Future<void>>(
    () async {
      // Ensure the Widgets binding is initialized inside this zone before
      // using any platform channels or calling runApp. This prevents the
      // "Zone mismatch" assertion by keeping ensureInitialized and runApp
      // in the same zone.
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Firebase early here so it's done inside the guarded zone.
      try {
        if (kIsWeb) {
          debugPrint('[MAIN] Direct Firebase initialization on web');
          await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
        } else {
          debugPrint('[MAIN] Direct Firebase initialization on native');
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
        debugPrint('[MAIN] Firebase initialized, allowing all browsers to access web app');
      } catch (e) {
        debugPrint('[MAIN] CRITICAL ERROR initializing Firebase: $e');
        // Let FirebaseInitializer attempt initialization later as a fallback.
      }

      tz.initializeTimeZones();

      // Wrap critical startup in a try/catch so we can show a friendly
      // error UI if something fails during initialization.
      try {
        Future<void> runStep(String name, FutureOr<void> Function() fn) async {
          debugPrint('== Startup STEP BEGIN: $name');
          try {
            await fn();
            debugPrint('== Startup STEP OK: $name');
          } catch (e) {
            debugPrint('== Startup STEP FAIL: $name -> $e');
            // Re-throw so outer catch can show unified error UI tagged with step name.
            throw Exception('[STEP $name] $e');
          }
        }

        // Initialize our "safe" local storage service.
        await runStep('localStorage', () async {
          try {
            await LocalStorageService.init();
          } catch (e) {
            // Non-critical; log and continue (do NOT wrap in Exception to avoid halting app)
            debugPrint('LocalStorage init failed (non-critical): $e');
          }
        });

        // Firebase core initialization
        await runStep('firebaseCore', () async {
          await FirebaseInitializer().initialize();
        });

        // Push notifications (tolerated failure on web)
        await runStep('pushNotifications', () async {
          try {
            await PushNotificationService().initialize();
          } catch (e) {
            debugPrint('Push notification init failed (non-critical): $e');
          }
        });

        // Daily background service (non-critical)
        await runStep('dailyBackgroundService', () async {
          try {
            DailyBackgroundService.initialize();
          } catch (e) {
            debugPrint('Background service init failed (non-critical): $e');
          }
        });

        // Add lifecycle observer
        await runStep('lifecycleObserver', () async {
          final lifecycleObserver = _AppLifecycleObserver();
          WidgetsBinding.instance.addObserver(lifecycleObserver);
        });
      } catch (e, st) {
        // If any of the above critical services fail, show an error UI and stop.
        // Log full stack trace for debugging.
        debugPrint('Critical startup error: $e');
        debugPrint('Stack trace:\n${st.toString()}');
        runApp(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'App Initialization Error',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SelectableText('Error: $e', textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        const Text('If this persists, screenshot & report.'),
                        const SizedBox(height: 12),
                        SizedBox(height: 300, child: SingleChildScrollView(child: SelectableText(st.toString()))),
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
          ),
        );
        return; // Halt execution of the zone callback.
      }

      bool crashlyticsEnabled = false;
      // Allow RELEASE_SCREENSHOTS to behave like a non-debug release for
      // privacy / overlay disabling when capturing store screenshots.
      final bool treatAsRelease = !kDebugMode || RELEASE_SCREENSHOTS;
      if (!kIsWeb && treatAsRelease) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
        crashlyticsEnabled = true;
      }

      runApp(
        ProviderScope(
          overrides: [crashlyticsEnabledProvider.overrideWith((_) => crashlyticsEnabled)],
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

// WebHandsApp class removed - no longer needed as all browsers now use the main HandsApp

class HandsApp extends ConsumerWidget {
  const HandsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Hands',
      theme: handsTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// Add app lifecycle observer to properly dispose services
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      DailyBackgroundService.dispose();
    }
  }
}
