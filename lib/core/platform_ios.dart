// lib/core/platform_ios.dart
import 'package:flutter/foundation.dart';

/// True only when running on iOS devices (not web).
bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
