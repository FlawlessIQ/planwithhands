import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationListSheet extends ConsumerStatefulWidget {
  final void Function(String title, String details)? onMessageTap;

  const NotificationListSheet({super.key, this.onMessageTap});

  @override
  ConsumerState<NotificationListSheet> createState() => _NotificationListSheetState();
}

class _NotificationListSheetState extends ConsumerState<NotificationListSheet> {
  final List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _subscription;
  String? _userId;
  String? _orgId;
  String _viewFilter = 'Unread'; // 'Unread', 'Read', 'Archived'

  @override
  void initState() {
    super.initState();
    _initAndSubscribe();
  }

  Future<void> _initAndSubscribe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    _userId = user.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    _orgId = userDoc.data()?['organizationId'] as String?;
    if (_orgId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // subscribe to notifications
    _subscription = FirebaseFirestore.instance
        .collection('organizations')
        .doc(_orgId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      final docs = snap.docs;
      final list = docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'message': data['message'] as String? ?? '',
          'createdAt': data['createdAt'],
          'readBy': List<String>.from(data['readBy'] ?? []),
          'archivedBy': List<String>.from(data['archivedBy'] ?? []),
        };
      }).toList();

      setState(() {
        _notifications
          ..clear()
          ..addAll(list);
        _isLoading = false;
      });
    });
  }

  Future<void> _archiveNotification(String id) async {
    if (_userId == null || _orgId == null) return;
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(_orgId)
        .collection('notifications')
        .doc(id)
        .update({'archivedBy': FieldValue.arrayUnion([_userId])});
  }
  Future<void> _unarchiveNotification(String id) async {
    if (_userId == null || _orgId == null) return;
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(_orgId)
        .collection('notifications')
        .doc(id)
        .update({'archivedBy': FieldValue.arrayRemove([_userId])});
  }

  Future<void> _markAsRead(String id) async {
    if (_userId == null || _orgId == null) return;
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(_orgId)
        .collection('notifications')
        .doc(id)
        .update({'readBy': FieldValue.arrayUnion([_userId])});
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final diff = now.difference(dt);

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $amPm';

    if (diff.inMinutes < 1) return 'Just now • $timeStr';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago • $timeStr';
    if (diff.inDays < 1) return '${diff.inHours}h ago • $timeStr';
    if (diff.inDays < 7) return '${diff.inDays}d ago • $dateStr $timeStr';
    return '$dateStr $timeStr';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Mark a single notification as read when user views it
  Future<void> _markNotificationAsRead(String id) async {
    if (_userId == null || _orgId == null) return;
    // Optimistically update local state
    final idx = _notifications.indexWhere((n) => n['id'] == id);
    if (idx != -1 && !(_notifications[idx]['readBy'] as List<String>).contains(_userId)) {
      setState(() {
        (_notifications[idx]['readBy'] as List<String>).add(_userId!);
      });
    }
    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(_orgId)
        .collection('notifications')
        .doc(id)
        .update({'readBy': FieldValue.arrayUnion([_userId])});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // filter notifications by view
    final filtered = _notifications.where((n) {
      final read = (n['readBy'] as List<String>).contains(_userId);
      final archived = (n['archivedBy'] as List<String>).contains(_userId);
      switch (_viewFilter) {
        case 'Unread': return !read && !archived;
        case 'Read':   return read && !archived;
        case 'Archived': return archived;
        default: return true;
      }
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Messages',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          // View filter chips
          Wrap(
            spacing: 8,
            children: ['Unread','Read','Archived'].map((f) => ChoiceChip(
              label: Text(f),
              selected: _viewFilter == f,
              onSelected: (_) => setState(() => _viewFilter = f),
            )).toList(),
          ),
          const Divider(),

          // Body
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No messages',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final n = filtered[i];
                  final isRead = (n['readBy'] as List<String>).contains(_userId);
                  final isArchived = (n['archivedBy'] as List<String>).contains(_userId);
                  final title = n['title'] as String? ?? 'New Message';
                  final details = n['message'] as String? ?? 'No content';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Icon(
                        isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread,
                        color: isRead ? Colors.grey : theme.primaryColor,
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        details,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'archive') {
                            _archiveNotification(n['id']);
                          } else if (value == 'unarchive') {
                            _unarchiveNotification(n['id']);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: isArchived ? 'unarchive' : 'archive',
                            child: Text(isArchived ? 'Unarchive' : 'Archive'),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (widget.onMessageTap != null) {
                          widget.onMessageTap!(title, details);
                        }
                        if (!isRead) {
                          _markNotificationAsRead(n['id']);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// New full page for notifications replacing bottom sheet
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: const NotificationListSheet(),
    );
  }
}
