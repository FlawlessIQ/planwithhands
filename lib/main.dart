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
import 'package:hands_app/pages/web_platform_page.dart';
import 'config/release_config.dart';

void main() async {
  // On web, show simplified app without Firebase complexity
  if (kIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
    usePathUrlStrategy();
    runApp(const WebHandsApp());
    return;
  }

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
        Future<void> runStep(String name, FutureOr<void> Function() fn) async {
          debugPrint('== Startup STEP BEGIN: ' + name);
          try {
            await fn();
            debugPrint('== Startup STEP OK: ' + name);
          } catch (e) {
            debugPrint('== Startup STEP FAIL: ' + name + ' -> ' + e.toString());
            // Re-throw so outer catch can show unified error UI tagged with step name.
            throw Exception('[STEP ' + name + '] ' + e.toString());
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
                        SelectableText('Error: ' + e.toString(), textAlign: TextAlign.center),
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

class WebHandsApp extends StatelessWidget {
  const WebHandsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plan with Hands',
      theme: handsTheme,
      debugShowCheckedModeBanner: false,
      home: const WebPlatformPage(),
    );
  }
}

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
