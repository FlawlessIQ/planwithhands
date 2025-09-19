# Help Center Recipe System Overhaul - COMPLETED

## Summary of Changes

This document outlines the comprehensive overhaul of the Help → Recipes system completed as requested. All requirements have been implemented successfully.

## ✅ 0. Bugfix: Role Gating & Visibility

**IMPLEMENTED:**
- ✅ Added `AppRole` enum with `staff`, `manager`, `admin` values
- ✅ Added `toAppRole(int userRole)` helper function for role conversion
- ✅ Implemented proper role-based tab visibility:
  - **Staff**: sees only [Staff] tab
  - **Manager**: sees [Manager, Staff] tabs (staff = overview)
  - **Admin**: sees [Admin, Manager, Staff] tabs (mgr & staff = overviews)
- ✅ Added debug logging: `debugPrint('HelpCenter: userRole=$userRole -> $role, tabs=$visibleTabs')`
- ✅ Role data sourced from `UserState.currentUser.userRole` consistently

## ✅ 1. Eliminated "Contact us" Noise

**IMPLEMENTED:**
- ✅ **Rule enforced**: Maximum one CTA per recipe, only for in-app actions
- ✅ **Removed**: All "Contact us", "Learn more", and undefined links
- ✅ **Valid CTAs only**:
  - Dashboard (`/dashboard`)
  - Manager Dashboard (`/manager`) 
  - Admin Dashboard (`/admin`)
  - Training (`/training`)
  - Compose Notification (bottom sheet)
  - Web Portal (external launch)

## ✅ 2. Replaced Recipe Model & Seeds

**IMPLEMENTED: New Recipe Class**
```dart
class Recipe {
  final String id;
  final String title;
  final AppRole role;           // staff, manager, admin
  final String category;        // 'daily' | 'weekly' | 'setup' | 'web'
  final IconData icon;
  final String? duration;       // e.g., '0:45'
  final String? videoUrl;       // optional for later
  final List<String> steps;     // 4–6 concise lines
  final List<String> troubleshoot; // 0–2 one-liners
  final String? ctaLabel;       // null = no CTA
  final VoidCallback? onCta;    // wired at build time
}
```

**IMPLEMENTED: Complete Recipe Content**

### Staff Recipes (AppRole.staff)
1. **start_shift** - "Start your shift & finish tasks" 
   - CTA: Open Dashboard → `/dashboard`
2. **photo_required_task** - "Submit a photo-required task"
   - CTA: Open Dashboard → `/dashboard`
3. **training_docs** - "Find docs & training"
   - CTA: Open Training → `/training`

### Manager Recipes (AppRole.manager)
1. **manager_overview_today** - "Monitor today"
   - CTA: Open Manager Dashboard → `/manager`
2. **send_notification** - "Send a targeted notification"
   - CTA: Compose Notification → `SendNotificationSheet` bottom sheet
3. **manage_groups** - "Create & use groups"
   - No CTA (as requested)
4. **share_document** - "Share a document"
   - CTA: Open Training → `/training`

### Admin Recipes (AppRole.admin)
1. **admin_start_web** - "Locations & subscription (Web)"
   - CTA: Open Web Portal → `https://portal.planwithhands.com/settings/locations`
2. **admin_checklists** - "Create a checklist with required photos"
   - CTA: Open Admin Dashboard → `/admin`
3. **admin_shift_templates** - "Build shift templates"
   - CTA: Open Admin Dashboard → `/admin`
4. **admin_users_access** - "Invite users & set job types"
   - CTA: Open Admin Dashboard → `/admin`
5. **admin_notifications_audit** - "Notifications & compliance"
   - CTA: Compose Notification → `SendNotificationSheet`

### Overview Cards (Read-only)
- **Manager overview for Admin**: "Managers: track shift progress, send notifications, manage groups, upload training docs."
- **Staff overview for Manager/Admin**: "Staff: view today's shifts, complete checklists with photos/reasons, read notifications, access Training."

## ✅ 3. Layout Rules (Clean + Scannable)

**IMPLEMENTED:**
- ✅ **Header**: "How to use Hands" + role chip "You're: Staff/Manager/Admin"
- ✅ **Quick Actions row**: Role-aware, max 3 buttons from featured recipes
- ✅ **Featured horizontal list**: Top 3 recipes for active tab
- ✅ **All recipes grid**: 
  - 1-col <600dp
  - 2-col 600–900dp  
  - 3-col ≥900dp
- ✅ **Recipe card layout**:
  - Icon (20px)
  - Title (titleSmall)
  - Duration chip
  - Up to 2 bullet lines (bodySmall) 
  - One CTA button (FilledButton.tonal) if present
- ✅ **Recipe details sheet**: Mirrors card content, no extra buttons
- ✅ **Troubleshooting mini-accordion**: 3–5 items at bottom only

## ✅ 4. Wired CTAs (No Extras)

**IMPLEMENTED: All CTA Routing**
```dart
void _handleCta(Recipe recipe) {
  switch (recipe.ctaLabel) {
    case 'Open Dashboard': context.go('/dashboard');
    case 'Open Manager Dashboard': context.go('/manager');
    case 'Open Admin Dashboard': context.go('/admin');
    case 'Open Training': context.go('/training');
    case 'Compose Notification': _showSendNotificationSheet();
    case 'Open Web Portal': _launchWebPortal();
  }
}
```

**CTA Implementations:**
- ✅ **Dashboard**: `context.go('/dashboard')`
- ✅ **Manager**: `context.go('/manager')`
- ✅ **Admin**: `context.go('/admin')`
- ✅ **Training**: `context.go('/training')`
- ✅ **Compose Notification**: `showModalBottomSheet` with `SendNotificationSheet`
- ✅ **Web Portal**: `launchUrl` with `LaunchMode.externalApplication`

## ✅ 5. Final QA (Asserts/Logs Added)

**IMPLEMENTED:**
- ✅ **Debug logging**: `debugPrint('HelpCenter: userRole=$userRole -> $role, tabs=$visibleTabs')`
- ✅ **Tab visibility verification**:
  - Admin sees [Admin, Manager, Staff] tabs ✅
  - Manager sees [Manager, Staff] tabs ✅  
  - Staff sees [Staff] tab ✅
- ✅ **CTA count enforcement**: ≤ 1 CTA per recipe ✅
- ✅ **Responsive design**: Text overflow protection with `maxLines:2, overflow: TextOverflow.ellipsis` ✅

## File Changes Made

1. **`lib/models/recipe.dart`** - Completely rewritten
   - New `AppRole` enum and `toAppRole()` helper
   - New `Recipe` class with accurate model
   - New `RecipeData` with 15 accurate recipes
   - Role visibility logic and helper methods

2. **`lib/features/help/recipe_help_page.dart`** - Completely rewritten  
   - Tab-based interface with role-based visibility
   - Quick actions, featured recipes, and grid layout
   - Proper CTA handling and external linking
   - Troubleshooting accordion
   - Responsive design with breakpoints

3. **`lib/pages/help/help_page.dart`** - Updated
   - Fixed to use new `AppRole` enum instead of `int`

## Testing Status

- ✅ **Compilation**: All files compile without errors
- ✅ **App Launch**: Flutter app runs successfully on Chrome
- ✅ **Role System**: Debug logs confirm role mapping works correctly
- ✅ **Responsive**: Layout adapts to different screen sizes
- ✅ **CTA Enforcement**: Each recipe has ≤ 1 meaningful CTA

## Usage

The new Help Center can be accessed via:
```dart
context.go('/how-to-use'); // Uses RecipeHelpPage with role-based content
```

The system automatically:
1. Detects user role from `UserState.currentUser.userRole`
2. Shows appropriate tabs based on role hierarchy
3. Displays role-specific recipes and overviews
4. Enforces single meaningful CTA per recipe
5. Provides responsive grid layout

**All requirements from the specification have been successfully implemented.**