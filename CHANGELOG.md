# CHANGELOG.md

## [1.1.5] - 2025-09-04

### FCM Token Storage Fixes
- **BREAKING CHANGE**: FCM tokens now stored in user-specific subcollections (`users/{uid}/deviceTokens/`) instead of top-level `deviceTokens` collection
- Fixed Firebase Security Rules violations caused by global token collection writes
- Added automatic cleanup of old/inactive tokens per user
- Updated cloud functions to read from new user-specific token paths with legacy fallback
- Added `lastFcmToken` field to user documents for quick debugging access
- Enhanced push notification service with better error handling and logging
- Updated debug tools to verify new token storage paths
- Backward compatible with existing tokens during migration period

### Cloud Functions Updates
- Updated `messagingNotifications.ts` to query user-specific token subcollections
- Added fallback support for legacy top-level token collection
- Enhanced token cleanup functions to handle both new and legacy storage formats
- Built and ready for deployment

## [Unreleased]

### Native Permission Handling
- Integrated `permission_handler` package (v11.3.1) for native permission dialogs
- Created `AppPermissionService` to manage photo, calendar, and notification permissions
- Updated iOS Info.plist with required permission usage descriptions:
  - NSPhotoLibraryAddUsageDescription for task photo documentation
  - NSCalendarsUsageDescription for schedule synchronization
  - NSCameraUsageDescription for photo capture functionality
- Updated Android AndroidManifest.xml with modern permission declarations:
  - READ_MEDIA_IMAGES for Android 13+ photo access
  - WRITE_CALENDAR and READ_CALENDAR for schedule integration
  - POST_NOTIFICATIONS for push notification support
  - CAMERA for photo capture
  - Backwards compatibility permissions for older Android versions
- Implemented permission request flow that triggers only when users interact with features
- Added graceful fallbacks with SnackBar rationales and settings redirect
- Updated photo upload dialogs to request camera/photo permissions before image selection
- Enhanced notification settings with native permission request for push notifications
- Added comprehensive unit tests covering permission service functionality
- Created `AppPermissionUtils` utility class for easy permission handling across the app

### Input UX
- All TextField/TextFormField widgets now use the best-match keyboardType (e.g., email, number, url, password).
- Added textInputAction: TextInputAction.next or .done as appropriate.
- Focus traversal is chained using FocusNode and onFieldSubmitted for seamless keyboard navigation.
- Enabled sentence auto-capitalization unless the field is all-caps (e.g., promo codes).
- All form fields are wrapped in Form widgets with GlobalKey<FormState> and provide inline validators.
- Validation errors are shown below fields but do not block the Next key.
- Date, time, and number fields use native pickers instead of free-text entry.
- All custom buttons and IconButtons have a minimum tap target (48x48 or MaterialTapTargetSize.padded).
- Added widget test: test/widget/form_input_test.dart to verify focus movement and validation error display.
