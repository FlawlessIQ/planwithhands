import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/widgets/professional_message_dialog.dart';

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
    final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
    _orgId = userDoc.data()?['organizationId'] as String?;
    if (_orgId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Get user data for filtering notifications
    final userData = userDoc.data()!;

    // subscribe to notifications
    _subscription = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(_orgId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
          final docs = snap.docs;
          final list =
              docs
                  .where((doc) {
                    // Filter notifications based on targeting
                    return _shouldUserSeeNotification(doc.data(), userData);
                  })
                  .map((doc) {
                    final data = doc.data();
                    return {
                      'id': doc.id,
                      'title': data['title'] as String? ?? '',
                      'message': data['message'] as String? ?? '',
                      'createdAt': data['createdAt'],
                      'readBy': List<String>.from(data['readBy'] ?? []),
                      'archivedBy': List<String>.from(data['archivedBy'] ?? []),
                    };
                  })
                  .toList();

          setState(() {
            _notifications
              ..clear()
              ..addAll(list);
            _isLoading = false;
          });
        });
  }

  /// Determine if the current user should see this notification
  bool _shouldUserSeeNotification(Map<String, dynamic> notificationData, Map<String, dynamic> userData) {
    final targetType = notificationData['targetType'] as String?;
    final targetId = notificationData['targetId'] as String?;

    // Handle legacy notifications and "all users" notifications
    if (targetType == null || targetType == 'all') {
      final recipientId = notificationData['recipientId'] as String?;
      // Show to all users if recipientId is 'all' or null
      return recipientId == 'all' || recipientId == null;
    }

    switch (targetType) {
      case 'all':
        return true;

      case 'user':
        // Individual user targeting
        return targetId == _userId;

      case 'group':
        // Group targeting - check if user is member of the group
        // TODO: Implement group membership check when groups are fully implemented
        return false;

      case 'location':
        // Location targeting - check if user has access to this location
        return _userHasLocationAccess(userData, targetId);

      default:
        // Unknown target type - show to be safe
        return true;
    }
  }

  /// Check if user has access to the specified location
  bool _userHasLocationAccess(Map<String, dynamic> userData, String? locationId) {
    if (locationId == null) return false;

    final userRole = userData['userRole'] as int? ?? 0;

    // Admins see all notifications
    if (userRole == 2) return true;

    // For managers and general users: check locationIds array
    final locationIds = userData['locationIds'];
    if (locationIds is List) {
      return locationIds.contains(locationId);
    }

    return false;
  }

  Future<void> _archiveNotification(String id) async {
    if (_userId == null || _orgId == null) return;
    await FirestoreEnforcer.instance.collection('organizations').doc(_orgId).collection('notifications').doc(id).update(
      {
        'archivedBy': FieldValue.arrayUnion([_userId]),
      },
    );
  }

  Future<void> _unarchiveNotification(String id) async {
    if (_userId == null || _orgId == null) return;
    await FirestoreEnforcer.instance.collection('organizations').doc(_orgId).collection('notifications').doc(id).update(
      {
        'archivedBy': FieldValue.arrayRemove([_userId]),
      },
    );
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
    await FirestoreEnforcer.instance.collection('organizations').doc(_orgId).collection('notifications').doc(id).update(
      {
        'readBy': FieldValue.arrayUnion([_userId]),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // filter notifications by view
    final filtered =
        _notifications.where((n) {
          final read = (n['readBy'] as List<String>).contains(_userId);
          final archived = (n['archivedBy'] as List<String>).contains(_userId);
          switch (_viewFilter) {
            case 'Unread':
              return !read && !archived;
            case 'Read':
              return read && !archived;
            case 'Archived':
              return archived;
            default:
              return true;
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
              Text('Messages', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          // View filter chips
          Wrap(
            spacing: 8,
            children:
                ['Unread', 'Read', 'Archived']
                    .map(
                      (f) => ChoiceChip(
                        label: Text(f),
                        selected: _viewFilter == f,
                        onSelected: (_) => setState(() => _viewFilter = f),
                      ),
                    )
                    .toList(),
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
              child: Center(child: Text('No messages', style: TextStyle(fontStyle: FontStyle.italic))),
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
                      title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'archive') {
                            _archiveNotification(n['id']);
                          } else if (value == 'unarchive') {
                            _unarchiveNotification(n['id']);
                          }
                        },
                        itemBuilder:
                            (context) => [
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
      body: NotificationListSheet(
        onMessageTap: (title, details) {
          ProfessionalMessageDialog.show(
            context: context,
            title: title,
            content: details,
            headerIcon: Icons.mail_outline,
          );
        },
      ),
    );
  }
}
