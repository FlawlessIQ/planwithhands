import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/pages/admin/send_notification_sheet.dart';

class HowToUsePage extends ConsumerWidget {
  const HowToUsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userStateProvider);
    final userRole = userState.userData?.userRole ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('How to use Hands')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with role chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('Quick guides for your role', style: Theme.of(context).textTheme.bodyMedium)],
                  ),
                ),
                RoleChip(userRole),
              ],
            ),
            const SizedBox(height: 24),

            // Quick actions row
            Wrap(spacing: 8, runSpacing: 8, children: _buildQuickActions(context, userRole)),
            const SizedBox(height: 32),

            // Guide cards grid
            ResponsiveGrid(children: _buildGuideCards(context, userRole)),
            const SizedBox(height: 32),

            // Troubleshooting section
            Text('Troubleshooting', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._buildTroubleshooting(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQuickActions(BuildContext context, int userRole) {
    switch (userRole) {
      case 0: // Staff
        return [
          QuickAction(
            icon: Icons.dashboard_outlined,
            label: 'Open Dashboard',
            onTap: () => Navigator.of(context).pushNamed('/dashboard'),
          ),
          QuickAction(
            icon: Icons.menu_book_outlined,
            label: 'Open Training',
            onTap: () => Navigator.of(context).pushNamed('/training'),
          ),
          QuickAction(
            icon: Icons.notifications_none,
            label: 'View Notifications',
            onTap: () => Navigator.of(context).pushNamed('/notifications'),
          ),
        ];
      case 1: // Manager
        return [
          QuickAction(
            icon: Icons.assignment_turned_in_outlined,
            label: 'Open Manager Dashboard',
            onTap: () => Navigator.of(context).pushNamed('/manager'),
          ),
          QuickAction(
            icon: Icons.campaign_outlined,
            label: 'Compose Notification',
            onTap:
                () => showModalBottomSheet(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (_) => const SendNotificationSheet(),
                ),
          ),
          QuickAction(
            icon: Icons.menu_book_outlined,
            label: 'Open Training',
            onTap: () => Navigator.of(context).pushNamed('/training'),
          ),
        ];
      case 2: // Admin
        return [
          QuickAction(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Open Admin Dashboard',
            onTap: () => Navigator.of(context).pushNamed('/admin'),
          ),
          QuickAction(
            icon: Icons.public_outlined,
            label: 'Web Portal (Locations & Billing)',
            onTap:
                () => launchUrl(
                  Uri.parse('https://portal.planwithhands.com/settings/locations'),
                  mode: LaunchMode.externalApplication,
                ),
          ),
          QuickAction(
            icon: Icons.campaign_outlined,
            label: 'Compose Notification',
            onTap:
                () => showModalBottomSheet(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (_) => const SendNotificationSheet(),
                ),
          ),
        ];
      default:
        return [];
    }
  }

  List<Widget> _buildGuideCards(BuildContext context, int userRole) {
    List<Widget> cards = [];

    switch (userRole) {
      case 0: // Staff only
        cards.addAll(_buildStaffCards(context));
        break;
      case 1: // Manager + Staff overview
        cards.addAll(_buildManagerCards(context));
        cards.add(_buildStaffOverviewCard());
        break;
      case 2: // Admin + Manager overview + Staff overview
        cards.addAll(_buildAdminCards(context));
        cards.add(_buildManagerOverviewCard());
        cards.add(_buildStaffOverviewCard());
        break;
    }

    return cards;
  }

  List<Widget> _buildStaffCards(BuildContext context) {
    return [
      RoleGuideCard(
        icon: Icons.play_circle_outline,
        title: 'Start your shift',
        bullets: ['Open Dashboard → pick today\'s shift.', 'Open a checklist to see tasks.'],
        ctaLabel: 'Open Dashboard',
        onCta: () => Navigator.of(context).pushNamed('/dashboard'),
      ),
      RoleGuideCard(
        icon: Icons.task_alt,
        title: 'Complete tasks',
        bullets: [
          'Tap a task to complete; add a note if needed.',
          'Tap the camera if photo is required. If skipped with a reason, managers are notified.',
        ],
      ),
      RoleGuideCard(
        icon: Icons.location_on_outlined,
        title: 'Switch locations',
        bullets: ['Tap the Location name in the top bar.', 'Don\'t see it? An admin must assign you.'],
      ),
      RoleGuideCard(
        icon: Icons.notifications_outlined,
        title: 'Notifications & training',
        bullets: ['New updates are in Notifications and via push.', 'Training shows SOPs, guides, and videos.'],
        ctaLabel: 'Open Training',
        onCta: () => Navigator.of(context).pushNamed('/training'),
      ),
    ];
  }

  List<Widget> _buildManagerCards(BuildContext context) {
    return [
      RoleGuideCard(
        icon: Icons.today_outlined,
        title: 'Today\'s overview',
        bullets: ['See active shifts and status on Manager Dashboard.', 'Open a shift to review progress.'],
        ctaLabel: 'Open Manager Dashboard',
        onCta: () => Navigator.of(context).pushNamed('/manager'),
      ),
      RoleGuideCard(
        icon: Icons.campaign_outlined,
        title: 'Send a notification',
        bullets: ['Menu → Send Notification.', 'Choose Everyone, Group, or Location; write, then send.'],
        ctaLabel: 'Compose Notification',
        onCta:
            () => showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (_) => const SendNotificationSheet(),
            ),
      ),
      RoleGuideCard(
        icon: Icons.group_outlined,
        title: 'Groups',
        bullets: ['Create/edit groups to target messages.', 'Name clearly (e.g., \'Bar – Weeknights\').'],
      ),
      RoleGuideCard(
        icon: Icons.description_outlined,
        title: 'Docs & training',
        bullets: ['Upload SOPs from Training.', 'Use clear titles (e.g., \'Dishwasher – Closing SOP\').'],
        ctaLabel: 'Open Training',
        onCta: () => Navigator.of(context).pushNamed('/training'),
      ),
    ];
  }

  List<Widget> _buildAdminCards(BuildContext context) {
    return [
      RoleGuideCard(
        icon: Icons.web_outlined,
        title: 'Start here (web)',
        bullets: ['Use Web Portal → Settings → Manage Locations.', 'Update subscription there too.'],
        ctaLabel: 'Open Web Portal',
        onCta:
            () => launchUrl(
              Uri.parse('https://portal.planwithhands.com/settings/locations'),
              mode: LaunchMode.externalApplication,
            ),
      ),
      RoleGuideCard(
        icon: Icons.checklist_outlined,
        title: 'Shifts & checklists',
        bullets: [
          'Create checklists; toggle camera to require photos.',
          'If photo is skipped with a reason, admins are notified.',
        ],
      ),
      RoleGuideCard(
        icon: Icons.schedule_outlined,
        title: 'Shift templates',
        bullets: ['Set start/end times and weekdays.', 'Attach checklists; publish for staff visibility.'],
      ),
      RoleGuideCard(
        icon: Icons.people_outlined,
        title: 'Users & access',
        bullets: ['Invite users; set job types and locations.', 'Checklists can filter by job type.'],
      ),
      RoleGuideCard(
        icon: Icons.security_outlined,
        title: 'Notifications & compliance',
        bullets: ['Send org-wide or targeted updates.', 'Review missed/bypassed tasks weekly.'],
        ctaLabel: 'Compose Notification',
        onCta:
            () => showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (_) => const SendNotificationSheet(),
            ),
      ),
      RoleGuideCard(
        icon: Icons.school_outlined,
        title: 'Docs & training',
        bullets: ['Upload org-wide policies; managers add site docs.', 'Keep a \'Start Here\' PDF for new hires.'],
        ctaLabel: 'Open Training',
        onCta: () => Navigator.of(context).pushNamed('/training'),
      ),
    ];
  }

  Widget _buildManagerOverviewCard() {
    return RoleGuideCard(
      icon: Icons.supervisor_account_outlined,
      title: 'What managers can do',
      bullets: ['Managers: track shift progress, send notifications, manage groups, upload training docs.'],
    );
  }

  Widget _buildStaffOverviewCard() {
    return RoleGuideCard(
      icon: Icons.person_outlined,
      title: 'What staff can do',
      bullets: [
        'Staff: view today\'s shifts, complete checklists with photos/reasons, read notifications, access Training.',
      ],
    );
  }

  List<Widget> _buildTroubleshooting(BuildContext context) {
    return [
      ExpansionTile(
        dense: true,
        title: Text('Can\'t switch locations?', style: Theme.of(context).textTheme.bodyMedium),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('You might not be assigned—ask an admin.', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
      ExpansionTile(
        dense: true,
        title: Text('Photo won\'t upload?', style: Theme.of(context).textTheme.bodyMedium),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text('Check camera permissions; try a smaller image.', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
      ExpansionTile(
        dense: true,
        title: Text('No push notifications?', style: Theme.of(context).textTheme.bodyMedium),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Enable push in device settings; messages still appear in-app.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      ExpansionTile(
        dense: true,
        title: Text('Billing/locations?', style: Theme.of(context).textTheme.bodyMedium),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Use the Web Portal → Settings → Manage Locations.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ];
  }
}

// Component Classes
class RoleChip extends StatelessWidget {
  final int userRole;

  const RoleChip(this.userRole, {super.key});

  @override
  Widget build(BuildContext context) {
    String roleText;
    switch (userRole) {
      case 0:
        roleText = 'Staff';
        break;
      case 1:
        roleText = 'Manager';
        break;
      case 2:
        roleText = 'Admin';
        break;
      default:
        roleText = 'Staff';
    }

    return Chip(
      label: Text('You are: $roleText'),
      labelStyle: Theme.of(context).textTheme.bodySmall,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickAction({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12))],
      ),
    );
  }
}

class RoleGuideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> bullets;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const RoleGuideCard({
    super.key,
    required this.icon,
    required this.title,
    required this.bullets,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + title
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),

            // Bullets (max 2)
            ...bullets
                .take(2)
                .map(
                  (bullet) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bullet,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

            // CTA button if provided
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonal(
                  onPressed: onCta,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: Text(ctaLabel!, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;

  const ResponsiveGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 3;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: children,
        );
      },
    );
  }
}
