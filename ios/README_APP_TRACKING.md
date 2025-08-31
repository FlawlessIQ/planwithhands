App Tracking Transparency (ATT) guidance for this project

Current state:
- `Info.plist` already contains `NSUserTrackingUsageDescription`.
- The project uses Stripe (web checkout) but does not include AppTrackingTransparency SDKs explicitly.

Recommendations:
1) If you DO NOT use third-party advertising or marketing SDKs that require IDFA, remove `NSUserTrackingUsageDescription` from `Info.plist` to avoid prompting users.

2) If you DO use tracking (analytics/ads):
   - Add the `AppTrackingTransparency` package and request permission where appropriate:
     import 'package:app_tracking_transparency/app_tracking_transparency.dart';
     final status = await AppTrackingTransparency.requestTrackingAuthorization();

   - Ensure you add `NSUserTrackingUsageDescription` to `Info.plist` (already present) with an accurate message.

3) Podfile guidance: keep use_frameworks! disabled unless a plugin requires it. To opt-out of SKAdNetwork or limit trackers, coordinate with SDK vendor docs.

This file is informational only; apply changes only after deciding whether your app performs cross-app tracking or serves personalized ads.
