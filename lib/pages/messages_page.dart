import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/pages/notifications_page.dart';
import 'package:hands_app/pages/admin/send_notification_sheet.dart';
import 'package:hands_app/pages/admin/create_group_sheet.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';

class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userStateProvider);
    final userRole = userState.userData?.userRole ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // View Messages Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.inbox),
                title: const Text('View Messages'),
                subtitle: const Text('See all notifications and messages'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => NotificationListSheet(
                      onMessageTap: (title, details) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Row(
                              children: [
                                const Icon(Icons.message, size: 28),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              details,
                              style: const TextStyle(fontSize: 16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            
            // Send Message Card (Managers and Admins only)
            if (userRole >= 1)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.send),
                  title: const Text('Send a Message'),
                  subtitle: const Text('Send notifications to team members'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const SendNotificationSheet(),
                    );
                  },
                ),
              ),
            
            // Create Group Card (Admins only)
            if (userRole >= 2)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.group_add),
                  title: const Text('Create a Group'),
                  subtitle: const Text('Create communication groups'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const CreateGroupSheet(),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Message Statistics (if available)
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Message Center',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Quick actions available based on your role:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      if (userRole == 0) ...[
                        const Text('• View messages and notifications'),
                      ] else if (userRole == 1) ...[
                        const Text('• View messages and notifications'),
                        const Text('• Send messages to team members'),
                      ] else if (userRole >= 2) ...[
                        const Text('• View messages and notifications'),
                        const Text('• Send messages to team members'),
                        const Text('• Create and manage groups'),
                        const Text('• Full administrative messaging access'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: -1, userRole: userRole), // No specific index for messages page
    );
  }
}
