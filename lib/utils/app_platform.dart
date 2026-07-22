import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

bool get isWeb => kIsWeb;
bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
