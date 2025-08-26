import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/firebase_options.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/services/web_asset_service.dart';
import 'package:hands_app/services/stripe_service.dart';
import 'package:hands_app/services/daily_background_service.dart';
import 'package:hands_app/services/push_notification_service.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/debug/functions_connection_debug.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:hands_app/core/logging/logger.dart';

// Global provider for Crashlytics availability
final crashlyticsEnabledProvider = StateProvider<bool>((ref) => false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize time zone database once at startup
  tz.initializeTimeZones();

  // Set URL strategy for web to use path-based URLs
  if (kIsWeb) {
    usePathUrlStrategy();
    logger.d('[MAIN] Setting path URL strategy for web');
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Dev helper: when running the web app on localhost, point Storage to the local emulator
  // This avoids CORS issues during development and lets you test uploads locally.
  try {
    if (kIsWeb && (Uri.base.host.contains('localhost') || Uri.base.host.contains('127.0.0.1'))) {
      // Use explicit 127.0.0.1 so web SDK requests match the emulator binding
      FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
      logger.d('[MAIN] Using Firebase Storage emulator at 127.0.0.1:9199');
    }
  } catch (e) {
    logger.e('[MAIN] Failed to configure Storage emulator: $e', e);
  }

  // Initialize push notifications on mobile platforms
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize push notification service
    await PushNotificationService().initialize();
  }

  // In debug, connect Functions to local emulator so Places proxy works on web locally
  await connectFunctionsEmulatorIfNeeded();

  // Initialize Stripe only on supported platforms (iOS/Android)
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
    StripeService.initStripe();
  }

  // Initialize Crashlytics with a more defensive approach
  bool crashlyticsEnabled = false;

  try {
    // Only try to enable crashlytics in production mode
    if (!kDebugMode) {
      if (!kIsWeb) {
        // On mobile platforms, this should work reliably
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
        crashlyticsEnabled = true;
      } else {
        // On web, we need to be more careful as the plugin might not be fully initialized
        try {
          // Delay slightly to allow Firebase to initialize
          await Future.delayed(const Duration(milliseconds: 500));
          // Don't call setCrashlyticsCollectionEnabled on web as it's prone to race conditions
          // Instead just check if it's available without trying to set it
          if (Firebase.apps.isNotEmpty) {
            crashlyticsEnabled = true;
            logger.d('Crashlytics should be available on web');
          }
        } catch (webError) {
          logger.w('Could not initialize Crashlytics on web: $webError');
          // Just continue without Crashlytics on web
        }
      }
    } else {
      logger.d('Debug mode detected, disabling Crashlytics');
    }
  } catch (e) {
    logger.e('Error during Crashlytics initialization: $e', e);
  }

  // Set up error handlers based on Crashlytics availability
  if (crashlyticsEnabled) {
    // Use Crashlytics handlers on all platforms
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } else {
    // Use console logging for errors when Crashlytics is disabled
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logger.e('Flutter error: ${details.exception}', details.exception);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      logger.e('Uncaught platform error: $error', error, stack);
      return true;
    };
  }

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Web-specific optimizations
  if (kIsWeb) {
    // Configure web renderer for better performance
    logger.d('Running on web - applying performance optimizations');
  }

  // Initialize background services
  _initializeBackgroundServices();

  // Initialize location selection service to load saved location
  try {
    await LocationSelectionService.instance.initialize();
  } catch (e) {
    logger.e('Failed to initialize LocationSelectionService: $e', e);
  }

  runApp(
    ProviderScope(
      overrides: [
        // Make Crashlytics availability status globally accessible
        crashlyticsEnabledProvider.overrideWith((ref) => crashlyticsEnabled),
      ],
      child: const MyApp(),
    ),
  );
}

/// Initialize background services
void _initializeBackgroundServices() {
  try {
    logger.d('[MAIN] Initializing background services');

    // Initialize daily summary monitoring
    DailyBackgroundService.initialize();

    logger.d('[MAIN] Background services initialized successfully');
  } catch (e) {
    logger.e('[MAIN] Error initializing background services: $e', e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Hands App',
      theme: handsTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: kDebugMode,
      builder: (context, child) {
        // Preload critical assets for web performance
        Widget wrapped = child ?? const SizedBox.shrink();
        if (kIsWeb) {
          WebAssetService.preloadCriticalAssets(context);
        }
        return ResponsiveBreakpoints.builder(
          child: wrapped,
          breakpoints: [
            const Breakpoint(start: 0, end: 450, name: MOBILE),
            const Breakpoint(start: 451, end: 800, name: TABLET),
            const Breakpoint(start: 801, end: double.infinity, name: DESKTOP),
          ],
        );
      },
    );
  }
}
