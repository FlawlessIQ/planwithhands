import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/pages/admin/send_notification_sheet.dart';
import 'package:hands_app/pages/admin/create_group_sheet.dart';
import 'package:hands_app/pages/help/help_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/state/notification_state.dart';

class UnifiedMenuButton extends ConsumerWidget {
  final int? userRole;
  const UnifiedMenuButton({super.key, this.userRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);

    final hasUnread = unreadCountAsync.maybeWhen(
      data: (count) {
        // Debug logging to help identify red indicator issues
        if (kDebugMode) {
          print('[UnifiedMenuButton] Unread count: $count, hasUnread: ${count > 0}');
        }
        return count > 0;
      },
      loading: () {
        if (kDebugMode) {
          print('[UnifiedMenuButton] Provider loading...');
        }
        return false;
      },
      error: (error, stack) {
        if (kDebugMode) {
          print('[UnifiedMenuButton] Provider error: $error');
        }
        return false;
      },
      orElse: () => false,
    );

    if (kDebugMode) {
      print('[UnifiedMenuButton] Final hasUnread: $hasUnread');
    }
    return PopupMenuButton<_MenuAction>(
      icon: Stack(
        children: [
          const Icon(Icons.menu),
          if (hasUnread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
      onSelected: (action) async {
        // Add a small delay to ensure the popup menu is fully closed
        await Future.delayed(const Duration(milliseconds: 50));

        // Check if the widget is still mounted before navigation
        if (!context.mounted) return;

        switch (action) {
          case _MenuAction.viewMessages:
            GoRouter.of(context).push(AppRoutes.notificationsPage.path);
            break;
          case _MenuAction.sendNotification:
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => const SendNotificationSheet(),
            );
            break;
          case _MenuAction.createGroup:
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) => const CreateGroupSheet(),
            );
            break;
          case _MenuAction.settings:
            GoRouter.of(context).push(AppRoutes.settingsPage.path);
            break;
          case _MenuAction.help:
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => HelpPage(userRole: userRole)));
            break;
        }
      },
      itemBuilder: (context) {
        final int role = userRole ?? 0;
        final items = <PopupMenuEntry<_MenuAction>>[];

        // Always available for all users (role 0, 1, 2)
        items.add(const PopupMenuItem(value: _MenuAction.viewMessages, child: Text('View messages')));

        // Manager and Admin features (role >= 1)
        if (role >= 1) {
          // Add manager-specific items here if needed in the future
        }

        // Admin-only features (role >= 2)
        if (role >= 2) {
          items.addAll([
            const PopupMenuItem(value: _MenuAction.sendNotification, child: Text('Send notification')),
            const PopupMenuItem(value: _MenuAction.createGroup, child: Text('Create notification group')),
          ]);
        }

        // Always available for all users
        items.addAll([
          const PopupMenuItem(value: _MenuAction.settings, child: Text('Settings')),
          const PopupMenuItem(value: _MenuAction.help, child: Text('Help')),
        ]);

        return items;
      },
    );
  }
}

enum _MenuAction { viewMessages, sendNotification, createGroup, settings, help }
