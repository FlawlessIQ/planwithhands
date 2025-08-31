import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/core/providers/crashlytics_provider.dart';
import 'package:hands_app/routing/router_provider.dart';
import 'package:hands_app/services/local_storage_service.dart';
import 'package:hands_app/services/daily_background_service.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:async';

import 'firebase_options.dart';
import 'config/release_config.dart';

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
        await LocalStorageService.init();
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

        // Initialize daily background service for automated summaries
        DailyBackgroundService.initialize();

        // Set up app lifecycle observer for proper cleanup
        final lifecycleObserver = _AppLifecycleObserver();
        WidgetsBinding.instance.addObserver(lifecycleObserver);
      } catch (e, st) {
        // If any of the above critical services fail, show an error UI and stop.
        print('Critical startup error: $e\n$st');
        runApp(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'A critical error occurred during app initialization:\n\n$e',
                    textAlign: TextAlign.center,
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
