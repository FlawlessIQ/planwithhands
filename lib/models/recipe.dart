import 'package:flutter/material.dart';

enum AppRole { staff, manager, admin }

AppRole toAppRole(int userRole) {
  if (userRole == 2) return AppRole.admin;
  if (userRole == 1) return AppRole.manager;
  return AppRole.staff;
}

/// Data model for Help Center how-to guides
class Recipe {
  final String id;
  final String title;
  final AppRole role;
  final String category; // 'daily' | 'weekly' | 'setup' | 'web'
  final IconData icon;
  final String? duration; // e.g., '0:45'
  final String? videoUrl; // optional for later
  final List<String> steps; // 4–6 concise lines
  final List<String> troubleshoot; // 0–2 one-liners
  final String? ctaLabel; // null = no CTA
  final VoidCallback? onCta; // wired at build time
  final bool isFeatured; // for highlighting important guides

  const Recipe({
    required this.id,
    required this.title,
    required this.role,
    required this.category,
    required this.icon,
    this.duration,
    this.videoUrl,
    required this.steps,
    this.troubleshoot = const [],
    this.ctaLabel,
    this.onCta,
    this.isFeatured = false,
  });
}

/// Guide data provider with accurate Hands app content
class RecipeData {
  static List<Recipe> getAllRecipes() {
    return [
      // Staff guides - Essential daily tasks
      Recipe(
        id: 'start_shift',
        title: 'Start your shift & finish tasks',
        role: AppRole.staff,
        category: 'daily',
        icon: Icons.play_circle_outline,
        duration: '2 min',
        isFeatured: true,
        steps: [
          'Open Dashboard → tap Today\'s Shift.',
          'Open a checklist; swipe to view all tasks.',
          'Tap a task to complete; add a short note if needed.',
          'Photo icon shows? Take a picture or give a reason.',
          'Return to Dashboard and confirm All done badges.',
        ],
        troubleshoot: ['Can\'t see your location? An admin must assign you.'],
        ctaLabel: 'Open Dashboard',
      ),
      Recipe(
        id: 'photo_required_task',
        title: 'Submit a photo-required task',
        role: AppRole.staff,
        category: 'daily',
        icon: Icons.photo_camera_outlined,
        duration: '1 min',
        isFeatured: true,
        steps: [
          'Open the task with the camera icon.',
          'Tap Add photo → take a clear, well-lit shot.',
          'If not possible, tap Give reason (manager notified).',
          'Submit and continue with the checklist.',
        ],
        troubleshoot: ['Photo failing? Check camera permission and retry.'],
        ctaLabel: 'Open Dashboard',
      ),
      Recipe(
        id: 'training_docs',
        title: 'Find docs & training',
        role: AppRole.staff,
        category: 'daily',
        icon: Icons.menu_book_outlined,
        duration: '1 min',
        isFeatured: true,
        steps: [
          'Open Training to view SOPs, guides, and videos.',
          'PDFs work best for multi-page docs.',
          'Use search to quickly find specific topics.',
          'Bookmark frequently used documents.',
        ],
        ctaLabel: 'Open Training',
      ),
      Recipe(
        id: 'clock_in_out',
        title: 'Clock in/out for shifts',
        role: AppRole.staff,
        category: 'daily',
        icon: Icons.access_time_rounded,
        duration: '30 sec',
        steps: [
          'Open the app at your workplace.',
          'Ensure location services are enabled.',
          'Tap the Clock In/Out button.',
          'Confirm your location is correct.',
          'Your time will be automatically recorded.',
        ],
        troubleshoot: ['Location not working? Enable GPS and try again.'],
      ),
      Recipe(
        id: 'view_notifications',
        title: 'Check team messages',
        role: AppRole.staff,
        category: 'daily',
        icon: Icons.notifications_outlined,
        duration: '1 min',
        steps: [
          'Open the Notifications section.',
          'Read messages from managers.',
          'Mark important items as read.',
          'Contact manager if clarification needed.',
        ],
      ),
      Recipe(
        id: 'update_profile',
        title: 'Update your profile',
        role: AppRole.staff,
        category: 'setup',
        icon: Icons.person_rounded,
        duration: '3 min',
        steps: [
          'Go to Settings from the main menu.',
          'Tap on Profile Information.',
          'Update your personal details.',
          'Change your profile photo if needed.',
          'Save your changes.',
        ],
      ),

      // Manager guides - Team oversight and communication
      Recipe(
        id: 'manager_overview_today',
        title: 'Monitor today\'s shifts',
        role: AppRole.manager,
        category: 'daily',
        icon: Icons.assignment_turned_in_outlined,
        duration: '3 min',
        isFeatured: true,
        steps: [
          'Open Manager Dashboard to see active shifts.',
          'Tap a shift → open a checklist to review progress.',
          'Check Missed or Bypassed photo items for follow-up.',
          'Contact staff if urgent items need attention.',
        ],
        troubleshoot: ['Not seeing all locations? Check your assigned areas.'],
        ctaLabel: 'Open Manager Dashboard',
      ),
      Recipe(
        id: 'send_notification',
        title: 'Send a targeted broadcast',
        role: AppRole.manager,
        category: 'daily',
        icon: Icons.campaign_outlined,
        duration: '2 min',
        isFeatured: true,
        steps: [
          'Open Communications → Broadcasts.',
          'Pick everyone, a saved audience, or a location.',
          'Add a short headline and a clear message, then send.',
          'Confirm delivery and check read receipts.',
        ],
        troubleshoot: [
          'Push notifications off? Users still see messages in-app.',
        ],
        ctaLabel: 'New Broadcast',
      ),
      Recipe(
        id: 'schedule_management',
        title: 'Manage team schedules',
        role: AppRole.manager,
        category: 'weekly',
        icon: Icons.schedule_rounded,
        duration: '10 min',
        isFeatured: true,
        steps: [
          'Open the Scheduling section.',
          'View current team assignments.',
          'Drag and drop to reassign tasks.',
          'Set shift times and break periods.',
          'Notify team of any schedule changes.',
          'Save and publish the updated schedule.',
        ],
        ctaLabel: 'Open Manager Dashboard',
      ),
      Recipe(
        id: 'manage_groups',
        title: 'Create & manage audiences',
        role: AppRole.manager,
        category: 'setup',
        icon: Icons.group_outlined,
        duration: '5 min',
        steps: [
          'Open Communications → Audiences.',
          'Name clearly (e.g., "Bar – Weeknights").',
          'Add the right team members to each audience.',
          'Use saved audiences when sending broadcasts.',
          'Update audience membership as needed.',
        ],
      ),
      Recipe(
        id: 'share_document',
        title: 'Share training documents',
        role: AppRole.manager,
        category: 'weekly',
        icon: Icons.upload_file_outlined,
        duration: '5 min',
        steps: [
          'Training → Upload to add SOPs or guides.',
          'Use descriptive titles (e.g., "Dishwasher – Closing SOP").',
          'Organize documents by department or role.',
          'Notify team when new materials are added.',
        ],
        ctaLabel: 'Open Training',
      ),
      Recipe(
        id: 'review_performance',
        title: 'Review team performance',
        role: AppRole.manager,
        category: 'weekly',
        icon: Icons.analytics_rounded,
        duration: '10 min',
        steps: [
          'Open the Analytics section.',
          'Select time period to review.',
          'View completion rates by team member.',
          'Check task performance metrics.',
          'Identify areas for improvement.',
          'Schedule follow-ups with staff as needed.',
        ],
      ),

      // Admin guides - System configuration and oversight
      Recipe(
        id: 'admin_start_web',
        title: 'Manage locations & billing',
        role: AppRole.admin,
        category: 'web',
        icon: Icons.public_outlined,
        duration: '5 min',
        isFeatured: true,
        steps: [
          'Web Portal → Settings → Manage Locations.',
          'Add new sites as your business grows.',
          'Update subscription for additional locations.',
          'Configure location-specific settings.',
        ],
        troubleshoot: ['Billing questions? Contact support for assistance.'],
        ctaLabel: 'Open Web Portal',
      ),
      Recipe(
        id: 'admin_checklists',
        title: 'Create comprehensive checklists',
        role: AppRole.admin,
        category: 'setup',
        icon: Icons.checklist_rtl,
        duration: '15 min',
        isFeatured: true,
        steps: [
          'Admin → Checklists → New.',
          'Keep tasks short and actionable (5–10 words).',
          'Toggle the camera on tasks that need verification.',
          '(Optional) Limit by Job Type to target visibility.',
          'Attach the checklist to Shift Templates to schedule it.',
          'Test with a pilot group before full rollout.',
        ],
        troubleshoot: [
          'Staff giving "reason" instead of photo? Check if tasks are clear.',
        ],
        ctaLabel: 'Open Admin Dashboard',
      ),
      Recipe(
        id: 'admin_shift_templates',
        title: 'Build efficient shift templates',
        role: AppRole.admin,
        category: 'setup',
        icon: Icons.calendar_today_outlined,
        duration: '10 min',
        isFeatured: true,
        steps: [
          'Create templates with appropriate start/end times.',
          'Set recurring weekday patterns.',
          'Attach relevant checklists for each shift type.',
          'Configure break periods and coverage.',
          'Publish so staff see the right lists at the right time.',
        ],
        ctaLabel: 'Open Admin Dashboard',
      ),
      Recipe(
        id: 'admin_users_access',
        title: 'Invite users & manage access',
        role: AppRole.admin,
        category: 'setup',
        icon: Icons.person_add_alt_1_outlined,
        duration: '8 min',
        steps: [
          'Invite new users with appropriate role levels.',
          'Assign users to their primary locations.',
          'Set job types for precise checklist filtering.',
          'Configure permissions for each role.',
          'Send welcome instructions to new team members.',
        ],
        ctaLabel: 'Open Admin Dashboard',
      ),
      Recipe(
        id: 'system_reports',
        title: 'Generate system reports',
        role: AppRole.admin,
        category: 'weekly',
        icon: Icons.assessment_rounded,
        duration: '10 min',
        steps: [
          'Navigate to Reports & Analytics.',
          'Select report type and date range.',
          'Filter by location, role, or task type.',
          'Generate comprehensive performance reports.',
          'Export data for external analysis.',
          'Schedule recurring reports for stakeholders.',
        ],
        ctaLabel: 'Open Admin Dashboard',
      ),
      Recipe(
        id: 'admin_notifications_audit',
        title: 'Organization-wide communications',
        role: AppRole.admin,
        category: 'weekly',
        icon: Icons.rule_folder_outlined,
        duration: '5 min',
        steps: [
          'Send org-wide announcements and updates.',
          'Target specific audiences or locations as needed.',
          'Review Missed/Bypassed photo tasks for coaching.',
          'Coordinate with managers on compliance issues.',
          'Document important communications for records.',
        ],
        ctaLabel: 'New Broadcast',
      ),
      Recipe(
        id: 'backup_management',
        title: 'Manage data backup & security',
        role: AppRole.admin,
        category: 'weekly',
        icon: Icons.backup_rounded,
        duration: '5 min',
        steps: [
          'Access Data Management section.',
          'Review backup status and schedules.',
          'Verify backup integrity and completion.',
          'Configure backup retention policies.',
          'Monitor system security and access logs.',
        ],
      ),
      Recipe(
        id: 'integration_setup',
        title: 'Configure system integrations',
        role: AppRole.admin,
        category: 'setup',
        icon: Icons.api_rounded,
        duration: '20 min',
        steps: [
          'Navigate to Integration Settings.',
          'Review available API endpoints.',
          'Generate secure API keys for integrations.',
          'Configure webhook endpoints for real-time data.',
          'Set up data synchronization with external systems.',
          'Test all integration connections thoroughly.',
          'Monitor API usage and performance metrics.',
        ],
      ),
    ];
  }

  static List<Recipe> getRecipesForRole(AppRole role) {
    final allRecipes = getAllRecipes();
    return allRecipes.where((recipe) => recipe.role == role).toList();
  }

  static List<Recipe> getFeaturedRecipes(AppRole role) {
    final roleRecipes = getRecipesForRole(role);
    return roleRecipes.where((recipe) => recipe.isFeatured).toList();
  }

  static List<AppRole> getVisibleTabs(AppRole role) {
    switch (role) {
      case AppRole.staff:
        return [AppRole.staff];
      case AppRole.manager:
        return [AppRole.manager, AppRole.staff];
      case AppRole.admin:
        return [AppRole.admin, AppRole.manager, AppRole.staff];
    }
  }

  static String getRoleDisplayName(AppRole role) {
    switch (role) {
      case AppRole.staff:
        return 'Staff';
      case AppRole.manager:
        return 'Manager';
      case AppRole.admin:
        return 'Admin';
    }
  }

  static String getOverviewText(AppRole role) {
    switch (role) {
      case AppRole.staff:
        return 'Staff: view today\'s shifts, complete checklists with photos/reasons, read the inbox, and access Training.';
      case AppRole.manager:
        return 'Managers: track shift progress, send broadcasts, manage audiences, and upload training docs.';
      case AppRole.admin:
        return 'Admins: full system access, manage locations, create checklists and shift templates, invite users.';
    }
  }

  /// Quick troubleshooting tips for common issues
  static List<String> getQuickTroubleshootingTips() {
    return [
      'No push alerts? Enable push in device settings',
      'Camera denied? Grant camera permission',
      'Location issues? Check GPS/location services',
      'Can\'t login? Try reset password or check internet',
      'App won\'t load? Force close and restart app',
      'Photos not uploading? Check camera permissions',
      'Not getting notifications? Enable notifications in phone settings',
      'Shifts not showing? Contact your manager or admin',
      'Tasks missing? Pull down to refresh the screen',
      'Location switching? Use menu button (top right)',
    ];
  }
}
