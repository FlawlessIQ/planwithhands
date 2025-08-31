Release screenshots guide

To run the app with dev-overlays and debug banners disabled for store screenshots, run with the Dart define:

flutter run --dart-define=RELEASE_SCREENSHOTS=true

For CI or local builds (iOS / Android) use the same `--dart-define` on `flutter build` commands.

This toggles a runtime constant and avoids changing build flavors or schemes. For stricter isolation create platform specific schemes/flavors in Xcode/Gradle and pass the same `--dart-define` during build.
