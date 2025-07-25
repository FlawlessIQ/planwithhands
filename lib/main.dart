import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/firebase_options.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/services/web_asset_service.dart';
import 'package:hands_app/services/stripe_service.dart';

// Global provider for Crashlytics availability
final crashlyticsEnabledProvider = StateProvider<bool>((ref) => false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Stripe only on supported platforms (iOS/Android)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    StripeService.initStripe();
  }

  // Initialize Crashlytics with a more defensive approach
  bool crashlyticsEnabled = false;

  try {
    // Only try to enable crashlytics in production mode
    if (!kDebugMode) {
      if (!kIsWeb) {
        // On mobile platforms, this should work reliably
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          true,
        );
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
            debugPrint('Crashlytics should be available on web');
          }
        } catch (webError) {
          debugPrint('Could not initialize Crashlytics on web: $webError');
          // Just continue without Crashlytics on web
        }
      }
    } else {
      debugPrint('Debug mode detected, disabling Crashlytics');
    }
  } catch (e) {
    debugPrint('Error during Crashlytics initialization: $e');
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
      debugPrint('Flutter error: ${details.exception}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Uncaught platform error: $error\n$stack');
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
    debugPrint('Running on web - applying performance optimizations');
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
