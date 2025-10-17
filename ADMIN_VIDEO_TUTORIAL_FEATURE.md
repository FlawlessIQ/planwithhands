# Admin Video Tutorial Feature

**Date:** October 16, 2025  
**Status:** ✅ Implemented

## Overview

Added an admin tutorial video link that appears in two locations:
1. **Help Center Page (Recipe Help)** - Prominent banner below Quick Actions section (admin users only)
2. **Welcome Organization Dialog** - Tutorial section with "Watch Now" button

## Video Details

- **File:** `HandsAdminDemo.mp4` (11.02 MB)
- **Hosted:** Firebase Storage (`gs://plan-with-hands.firebasestorage.app/HandsAdminDemo.mp4`)
- **Public URL:** `https://firebasestorage.googleapis.com/v0/b/plan-with-hands.firebasestorage.app/o/HandsAdminDemo.mp4?alt=media&token=c7bc227b-590a-48ed-9631-bb1e440f6450`
- **Access:** Opens in new browser tab/window using `url_launcher` package
- **Token:** `c7bc227b-590a-48ed-9631-bb1e440f6450` (Firebase Storage download token)

## Implementation Details

### 1. Help Center Page (`lib/features/help/recipe_help_page.dart`)

**Changes:**
- Added constant: `_adminVideoUrl` with the Firebase Storage HTTPS URL (line 23)
- Added conditional UI: Admin-only banner below Quick Actions section
- Uses existing `url_launcher` import and `launchUrl()` method
- Implemented in all three responsive layouts: wide, medium, and mobile

**Access Control:**
- Only visible when `_currentRole == AppRole.admin` (userRole = 2)
- Uses existing `_currentRole` from widget state
- Banner shows after Quick Actions, before Featured Guides section

**Responsive Design:**
- **Wide screens:** Banner in Quick Actions container with 40px play icon
- **Medium screens:** Banner in Quick Actions container with 40px play icon  
- **Mobile screens:** Standalone banner card with 48px play icon
- All layouts use consistent styling with primary colors and Material InkWell

**UI Design:**
- Large play icon (48px) with primary theme color
- Title: "📹 Admin Tutorial Video"
- Subtitle: "Watch this video guide to learn how to manage your organization"
- "Open in new" icon to indicate external link
- Tappable card with rounded corners and border
- Uses theme colors for consistency

### 2. Welcome Organization Dialog (`lib/widgets/welcome_organization_dialog.dart`)

**Changes:**
- Added constant: `_adminVideoUrl` (same URL)
- Added new section with `_buildSection()` helper
- Added orange "Watch Now" button with play icon
- Positioned between "Account Management" and "Help & Support" sections

**UI Design:**
- Consistent with existing dialog sections
- Orange button matching brand color (`HandsColors.handsOrange`)
- Play arrow icon + "Watch Now" text
- Uses existing `_launchUrl()` method (already in the widget)
- Prominent placement in onboarding flow

## User Experience

### Admin Users (userRole = 2)

**Help Center Page:**
1. Navigate to Help Center (menu → Help Center)
2. See the tabbed interface: Admin / Manager / Staff tabs at top
3. Below "Quick Actions" section, see prominent video banner
4. Click anywhere on banner
5. Video opens in new browser tab/window
6. Can watch, pause, rewind using browser's video controls

**Visual Location:**
```
┌─────────────────────────────────────────┐
│ Help Center                             │
│ Step-by-step guides for every task     │
│ [Your role: Admin]                      │
├─────────────────────────────────────────┤
│ Admin | Manager | Staff                 │
├─────────────────────────────────────────┤
│                                         │
│ ⚡ Quick Actions                        │
│ [Action cards...]                       │
│                                         │
│ 🎬 📹 Admin Tutorial Video           ↗ │
│    Watch this video guide to learn...  │
│                                         │
│ ⭐ Featured Guides                      │
│ [Guide cards...]                        │
└─────────────────────────────────────────┘
```

**New Organization Setup:**
1. Complete organization creation
2. Welcome dialog appears
3. See "Watch Tutorial Video" section
4. Click orange "Watch Now" button
5. Video opens in new tab while dialog remains open
6. Can continue with setup after watching

### Non-Admin Users (userRole 0, 1)

- Help Center page does NOT show video banner
- Staff and Manager users see their own tabs but no video link
- Welcome dialog is only shown to admins during org setup
- No access to admin tutorial video (not relevant to their role)

## Technical Notes

### URL Format

Firebase Storage HTTPS URLs follow this pattern:
```
https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{filepath}?alt=media&token={downloadToken}
```

**Components:**
- `bucket`: `plan-with-hands.firebasestorage.app`
- `filepath`: `HandsAdminDemo.mp4` (URL-encoded if needed)
- `downloadToken`: `c7bc227b-590a-48ed-9631-bb1e440f6450`

### Browser Behavior

- **Desktop:** Opens video in new tab, plays inline with browser controls
- **Mobile:** May open in native video player or browser depending on device
- **Download:** Users can right-click → "Save video as..." to download

### URL Launcher Configuration

```dart
await launchUrl(uri, mode: LaunchMode.externalApplication);
```

- `LaunchMode.externalApplication`: Opens in device's default browser
- Ensures video opens in new context (not embedded in app)
- Works consistently across web, iOS, and Android platforms

## Updating the Video

If you need to replace the video file:

### Option 1: Upload New File with Same Name
1. Delete old file: `gsutil rm gs://plan-with-hands.firebasestorage.app/HandsAdminDemo.mp4`
2. Upload new file: `gsutil cp NewVideo.mp4 gs://plan-with-hands.firebasestorage.app/HandsAdminDemo.mp4`
3. Get new token: `gsutil ls -L gs://plan-with-hands.firebasestorage.app/HandsAdminDemo.mp4`
4. Update `_adminVideoUrl` constant in both files with new token
5. Rebuild and deploy

### Option 2: Use Firebase Console
1. Go to Firebase Console → Storage
2. Upload new video file
3. Click on file → Get download URL
4. Copy the full HTTPS URL
5. Update `_adminVideoUrl` constant in both files
6. Rebuild and deploy

### Option 3: YouTube/Vimeo (Alternative)
If you prefer hosted video service:
1. Upload video to YouTube (set to Unlisted) or Vimeo
2. Copy share URL (e.g., `https://youtu.be/abc123xyz`)
3. Update `_adminVideoUrl` constant with new URL
4. Video will embed/play in browser with platform's native player

## Files Modified

1. **`lib/features/help/recipe_help_page.dart`**
   - Line 23: Added `_adminVideoUrl` constant
   - Lines 638-689: Added admin video banner to wide screen layout
   - Lines 1062-1113: Added admin video banner to medium screen layout
   - Lines 1261-1321: Added admin video banner to mobile layout
   - Uses inline `launchUrl()` calls with `RecipeHelpPage._adminVideoUrl`

2. **`lib/widgets/welcome_organization_dialog.dart`**
   - Lines 8-9: Added `_adminVideoUrl` constant
   - Lines 96-133: Added video tutorial section with "Watch Now" button

## Testing

### Manual Test Steps

1. **Help Center Page Banner (Admin Only):**
   - [ ] Log in as admin user (userRole = 2)
   - [ ] Navigate to Help Center (menu → Help Center)
   - [ ] Verify you see Admin/Manager/Staff tabs
   - [ ] Scroll to Quick Actions section
   - [ ] Verify video banner appears immediately below Quick Actions
   - [ ] Click banner
   - [ ] Verify video opens in new tab
   - [ ] Verify video plays correctly
   - [ ] Log in as non-admin (userRole 0 or 1)
   - [ ] Navigate to Help Center
   - [ ] Verify video banner does NOT appear (even on Admin tab if accessible)

2. **Welcome Dialog:**
   - [ ] Create new organization as admin
   - [ ] Verify welcome dialog appears
   - [ ] Locate "Watch Tutorial Video" section (before "Help & Support")
   - [ ] Click orange "Watch Now" button
   - [ ] Verify video opens in new tab
   - [ ] Verify video plays correctly
   - [ ] Verify dialog remains open

3. **Responsive Testing:**
   - [ ] Test on wide screen (>1200px) - banner in Quick Actions container
   - [ ] Test on medium screen (800-1200px) - banner in Quick Actions container
   - [ ] Test on mobile (<800px) - standalone banner card
   - [ ] Test on Chrome (web)
   - [ ] Test on Safari (web)
   - [ ] Test on iOS device (if applicable)
   - [ ] Test on Android device (if applicable)

## Future Enhancements

- [ ] Add analytics tracking when video link is clicked
- [ ] Add video duration/length in UI text
- [ ] Create multiple tutorial videos for different topics
- [ ] Add video preview/thumbnail image
- [ ] Support multiple languages with separate video files
- [ ] Add closed captions/subtitles file
- [ ] Track video completion rate
- [ ] Add in-app video player (using `video_player` package)

## Related Documentation

- [Firebase Storage Documentation](https://firebase.google.com/docs/storage)
- [url_launcher Package](https://pub.dev/packages/url_launcher)
- [Recipe Help Page (Help Center)](lib/features/help/recipe_help_page.dart)
- [Welcome Dialog Flow](lib/widgets/welcome_organization_dialog.dart)

---

**Implementation Complete** ✅  
Ready for testing and deployment to production.

## Notes

- The video link is positioned strategically after Quick Actions to maximize visibility
- Three responsive layouts ensure consistent experience across all screen sizes
- Video banner uses Material InkWell for proper tap feedback
- External launch mode ensures video opens in device's default browser
- Admin-only access control prevents video from showing to non-admin users
