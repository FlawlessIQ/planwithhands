import 'package:flutter/material.dart';
import 'package:hands_app/debug/push_notification_test_widget.dart';
import 'package:hands_app/debug/location_assignment_debug_tool.dart';

/// Add this to your app for testing push notifications
/// Can be accessed via debug menu or added to dashboard temporarily
class PushNotificationDebugButton extends StatelessWidget {
  const PushNotificationDebugButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PushNotificationTestWidget()));
      },
      label: const Text('Test Push'),
      icon: const Icon(Icons.bug_report),
      backgroundColor: Colors.orange,
    );
  }
}

/// Temporary debug widget for quick access to push notification testing
/// Add this to your dashboard or anywhere you need quick access
class QuickPushNotificationTest extends StatelessWidget {
  const QuickPushNotificationTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Debug: Push Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Test FCM token registration and notification delivery', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (context) => const PushNotificationTestWidget()));
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Diagnostics'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (context) => const LocationAssignmentDebugTool()));
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('Location Debug'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
