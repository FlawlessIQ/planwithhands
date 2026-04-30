// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simple test setup to initialize test bindings and Firebase for widget tests.
Future<void> initTestBindings() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  // Initialize Firebase if it hasn't been initialized already.
  try {
    Firebase.app();
  } catch (_) {
    // In tests we can call initializeApp without options; this creates a default app.
    await Firebase.initializeApp();
  }
}
