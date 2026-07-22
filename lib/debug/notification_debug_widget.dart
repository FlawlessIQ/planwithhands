import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/state/notification_state.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Simple debug widget to test the red indicator functionality
class NotificationDebugWidget extends ConsumerStatefulWidget {
  const NotificationDebugWidget({super.key});

  @override
  ConsumerState<NotificationDebugWidget> createState() => _NotificationDebugWidgetState();
}

class _NotificationDebugWidgetState extends ConsumerState<NotificationDebugWidget> {
  String _debugInfo = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final unreadCountAsync = ref.watch(unreadNotificationsCountProvider);
    final userState = ref.watch(userStateProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐛 Red Indicator Debug', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Current provider state
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Provider State:', style: TextStyle(fontWeight: FontWeight.bold)),
                  unreadCountAsync.when(
                    data:
                        (count) => Text(
                          'Unread Count: $count ${count > 0 ? '🔴' : '⚪'}',
                          style: TextStyle(color: count > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                        ),
                    loading: () => const Text('⏳ Loading...'),
                    error: (err, stack) => Text('❌ Error: $err', style: const TextStyle(color: Colors.red)),
                  ),
                  if (userState.userData != null) ...[
                    const SizedBox(height: 4),
                    Text('User: ${FirebaseAuth.instance.currentUser?.email ?? 'Unknown'}'),
                    Text('Org: ${userState.userData!.organizationId}'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _createTestNotification,
                  child:
                      _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create Test'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _checkNotifications, child: const Text('Check DB')),
              ],
            ),

            if (_debugInfo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(_debugInfo, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createTestNotification() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Creating test notification...\n';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addDebugInfo('❌ No user logged in');
        return;
      }

      final testId = 'debug_${DateTime.now().millisecondsSinceEpoch}';
      _addDebugInfo('📝 Creating notification with ID: $testId');

      await FirestoreEnforcer.instance
          .collection('userNotifications')
          .doc(user.uid)
          .collection('notifications')
          .doc(testId)
          .set({
            'id': testId,
            'title': 'Red Indicator Test',
            'message': 'This test notification should make the red dot appear',
            'type': 'debug',
            'createdAt': DateTime.now().toIso8601String(),
            'readBy': <String>[],
            'archivedBy': <String>[],
            'userId': user.uid,
            'orgId': ref.read(userStateProvider).userData?.organizationId ?? '',
          });

      _addDebugInfo('✅ Test notification created successfully!');
      _addDebugInfo('🔴 Check if red dot appears on menu button');
    } catch (e) {
      _addDebugInfo('❌ Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkNotifications() async {
    setState(() {
      _debugInfo = 'Checking notifications in database...\n';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addDebugInfo('❌ No user logged in');
        return;
      }

      _addDebugInfo('📋 Checking userNotifications/${user.uid}/notifications...');

      final snapshot =
          await FirestoreEnforcer.instance
              .collection('userNotifications')
              .doc(user.uid)
              .collection('notifications')
              .get();

      _addDebugInfo('📊 Found ${snapshot.docs.length} total notifications');

      if (snapshot.docs.isEmpty) {
        _addDebugInfo('📭 No notifications found - this explains why red dot is missing');
        return;
      }

      int unreadCount = 0;
      int readCount = 0;
      int archivedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final readBy = List<String>.from(data['readBy'] ?? []);
        final archivedBy = List<String>.from(data['archivedBy'] ?? []);

        if (archivedBy.contains(user.uid)) {
          archivedCount++;
        } else if (readBy.contains(user.uid)) {
          readCount++;
        } else {
          unreadCount++;
          _addDebugInfo('📧 Unread: ${doc.id} - "${data['title']}"');
        }
      }

      _addDebugInfo('');
      _addDebugInfo('📊 SUMMARY:');
      _addDebugInfo('   Unread: $unreadCount 🔴');
      _addDebugInfo('   Read: $readCount ✅');
      _addDebugInfo('   Archived: $archivedCount 🗃️');
      _addDebugInfo('');

      if (unreadCount > 0) {
        _addDebugInfo('🔴 Red indicator SHOULD be visible');
      } else {
        _addDebugInfo('⚪ Red indicator should NOT be visible');
      }
    } catch (e) {
      _addDebugInfo('❌ Error checking notifications: $e');
    }
  }

  void _addDebugInfo(String message) {
    setState(() {
      _debugInfo += '$message\n';
    });
  }
}
