// Simple lightweight logger wrapper to centralize debug/console output.
// Avoids direct `print` usage across the codebase so analyzer rules
// like `avoid_print` can be enforced and we can later swap to a
// fancier logger package if desired.
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class Logger {
  const Logger();

  void d(String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      developer.log(message, name: 'hands_app.debug', error: error, stackTrace: stack, level: 500);
    }
  }

  void i(String message, [Object? error, StackTrace? stack]) {
    developer.log(message, name: 'hands_app.info', error: error, stackTrace: stack, level: 800);
  }

  void w(String message, [Object? error, StackTrace? stack]) {
    developer.log(message, name: 'hands_app.warn', error: error, stackTrace: stack, level: 900);
  }

  void e(String message, [Object? error, StackTrace? stack]) {
    developer.log(message, name: 'hands_app.error', error: error, stackTrace: stack, level: 1000);
  }
}

/// Shared logger instance for the app. Import and call `logger.i(...)`,
/// `logger.d(...)`, `logger.w(...)`, or `logger.e(...)` instead of `print`.
const Logger logger = Logger();
