import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/widgets/professional_message_dialog.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationListSheet extends ConsumerStatefulWidget {
  final void Function(String title, String details)? onMessageTap;

  const NotificationListSheet({super.key, this.onMessageTap});

  @override
  ConsumerState<NotificationListSheet> createState() => _NotificationListSheetState();
}

class _NotificationListSheetState extends ConsumerState<NotificationListSheet> {
  final List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  StreamSubscription<QuerySnapshot>? _subscription;
  String? _userId;
  String? _orgId;
  String _viewFilter = 'Unread'; // 'Unread', 'Read', 'Archived'
  static const int _pageSize = 10;
  DocumentSnapshot? _lastDocument;

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

    // Reset pagination state
    _lastDocument = null;
    _hasMoreData = true;
    _notifications.clear();

    // Load first page
    await _loadNotifications(isLoadMore: false);
  }

  Future<void> _loadNotifications({required bool isLoadMore}) async {
    if (isLoadMore && (!_hasMoreData || _isLoadingMore)) return;

    if (mounted) {
      setState(() {
        if (isLoadMore) {
          _isLoadingMore = true;
        } else {
          _isLoading = true;
        }
      });
    }

    try {
      // Load all notifications and filter on client side for simplicity
      // This avoids complex Firestore query limitations with array conditions
      Query query = FirestoreEnforcer.instance
          .collection('userNotifications')
          .doc(_userId!)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize * 3); // Load more to account for filtering

      // Add pagination
      if (isLoadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      if (docs.isEmpty) {
        setState(() {
          _hasMoreData = false;
          if (isLoadMore) {
            _isLoadingMore = false;
          } else {
            _isLoading = false;
          }
        });
        return;
      }

      // Filter notifications based on current view
      final filteredDocs =
          docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final readBy = List<String>.from(data['readBy'] ?? []);
                final archivedBy = List<String>.from(data['archivedBy'] ?? []);
                final isRead = readBy.contains(_userId);
                final isArchived = archivedBy.contains(_userId);

                switch (_viewFilter) {
                  case 'Unread':
                    return !isRead && !isArchived;
                  case 'Read':
                    return isRead && !isArchived;
                  case 'Archived':
                    return isArchived;
                  default:
                    return true;
                }
              })
              .take(_pageSize)
              .toList();

      final newNotifications =
          filteredDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'title': data['title'] as String? ?? '',
              'message': data['message'] as String? ?? '',
              'createdAt': data['createdAt'],
              'readBy': List<String>.from(data['readBy'] ?? []),
              'archivedBy': List<String>.from(data['archivedBy'] ?? []),
              'docSnapshot': doc, // Store for pagination
            };
          }).toList();

      setState(() {
        if (isLoadMore) {
          _notifications.addAll(newNotifications);
          _isLoadingMore = false;
        } else {
          _notifications
            ..clear()
            ..addAll(newNotifications);
          _isLoading = false;
        }

        _lastDocument = docs.isNotEmpty ? docs.last : null;
        _hasMoreData = newNotifications.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _isLoadingMore = false;
          } else {
            _isLoading = false;
          }
        });
      }
    }
  }

  Future<void> _archiveNotification(String id) async {
    if (_userId == null) return;
    await FirestoreEnforcer.instance
        .collection('userNotifications')
        .doc(_userId!)
        .collection('notifications')
        .doc(id)
        .update({
          'archivedBy': FieldValue.arrayUnion([_userId]),
        });
    // Refresh current view
    await _loadNotifications(isLoadMore: false);
  }

  Future<void> _unarchiveNotification(String id) async {
    if (_userId == null) return;
    await FirestoreEnforcer.instance
        .collection('userNotifications')
        .doc(_userId!)
        .collection('notifications')
        .doc(id)
        .update({
          'archivedBy': FieldValue.arrayRemove([_userId]),
        });
    // Refresh current view
    await _loadNotifications(isLoadMore: false);
  }

  Future<void> _deleteNotification(String id) async {
    if (_userId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: HandsColors.cardPrimary,
            title: Text(
              'Delete Message',
              style: GoogleFonts.comfortaa(color: HandsColors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to permanently delete this message? This action cannot be undone.',
              style: GoogleFonts.comfortaa(color: HandsColors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: GoogleFonts.comfortaa(color: HandsColors.white70)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete', style: GoogleFonts.comfortaa(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await FirestoreEnforcer.instance
            .collection('userNotifications')
            .doc(_userId!)
            .collection('notifications')
            .doc(id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Message deleted successfully', style: GoogleFonts.comfortaa(color: Colors.white)),
              backgroundColor: HandsColors.primary,
            ),
          );
          // Refresh current view
          await _loadNotifications(isLoadMore: false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete message: $e', style: GoogleFonts.comfortaa(color: Colors.white)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Mark a single notification as read when user views it
  Future<void> _markNotificationAsRead(String id) async {
    if (_userId == null) return;
    // Optimistically update local state
    final idx = _notifications.indexWhere((n) => n['id'] == id);
    if (idx != -1 && !(_notifications[idx]['readBy'] as List<String>).contains(_userId)) {
      setState(() {
        (_notifications[idx]['readBy'] as List<String>).add(_userId!);
      });
    }
    await FirestoreEnforcer.instance
        .collection('userNotifications')
        .doc(_userId!)
        .collection('notifications')
        .doc(id)
        .update({
          'readBy': FieldValue.arrayUnion([_userId]),
        });
  }

  void _onViewFilterChanged(String newFilter) {
    setState(() {
      _viewFilter = newFilter;
      _lastDocument = null;
      _hasMoreData = true;
    });
    _loadNotifications(isLoadMore: false);
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final fullDateFormat = DateFormat('MMM d, yyyy');

    if (messageDate == today) {
      // Today - show just time
      return timeFormat.format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday ${timeFormat.format(dateTime)}';
    } else if (dateTime.year == now.year) {
      // This year - show month, day and time
      return '${dateFormat.format(dateTime)} ${timeFormat.format(dateTime)}';
    } else {
      // Different year - show full date and time
      return '${fullDateFormat.format(dateTime)} ${timeFormat.format(dateTime)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: HandsDecorations.primaryBoxDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MESSAGES',
                style: GoogleFonts.comfortaa(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: HandsColors.white,
                  letterSpacing: 1.5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: HandsColors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
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
                        onSelected: (_) => _onViewFilterChanged(f),
                        backgroundColor: HandsColors.secondaryContainer,
                        selectedColor: HandsColors.handsOrange,
                        labelStyle: GoogleFonts.comfortaa(
                          color: _viewFilter == f ? HandsColors.white : HandsColors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                    .toList(),
          ),
          Divider(color: HandsColors.white12, thickness: 1),

          // Body
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(HandsColors.handsOrange)),
              ),
            )
          else if (_notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No messages',
                  style: GoogleFonts.comfortaa(fontStyle: FontStyle.italic, color: HandsColors.white70),
                ),
              ),
            )
          else
            Flexible(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: false,
                      itemCount: _notifications.length,
                      itemBuilder: (context, i) {
                        final n = _notifications[i];
                        final isRead = (n['readBy'] as List<String>).contains(_userId);
                        final isArchived = (n['archivedBy'] as List<String>).contains(_userId);
                        final title = n['title'] as String? ?? 'New Message';
                        final details = n['message'] as String? ?? 'No content';
                        final timestamp = _formatTimestamp(n['createdAt']);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: HandsDecorations.tertiaryBoxDecoration,
                          child: ListTile(
                            leading: Icon(
                              isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread,
                              color: isRead ? HandsColors.white70 : HandsColors.handsOrange,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: GoogleFonts.comfortaa(
                                      fontWeight: isRead ? FontWeight.w400 : FontWeight.bold,
                                      color: HandsColors.white,
                                    ),
                                  ),
                                ),
                                if (timestamp.isNotEmpty)
                                  Text(
                                    timestamp,
                                    style: GoogleFonts.comfortaa(
                                      fontSize: 12,
                                      color: HandsColors.white70,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              details,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 13),
                            ),
                            trailing: PopupMenuButton<String>(
                              iconColor: HandsColors.white70,
                              color: HandsColors.secondaryContainer,
                              onSelected: (value) {
                                if (value == 'archive') {
                                  _archiveNotification(n['id']);
                                } else if (value == 'unarchive') {
                                  _unarchiveNotification(n['id']);
                                } else if (value == 'delete') {
                                  _deleteNotification(n['id']);
                                }
                              },
                              itemBuilder:
                                  (context) => [
                                    PopupMenuItem(
                                      value: isArchived ? 'unarchive' : 'archive',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isArchived ? Icons.unarchive : Icons.archive,
                                            color: HandsColors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isArchived ? 'Unarchive' : 'Archive',
                                            style: GoogleFonts.comfortaa(color: HandsColors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete, color: Colors.red, size: 16),
                                          const SizedBox(width: 8),
                                          Text('Delete', style: GoogleFonts.comfortaa(color: Colors.red)),
                                        ],
                                      ),
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
                  // Load More button
                  if (_hasMoreData && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child:
                          _isLoadingMore
                              ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(HandsColors.handsOrange),
                              )
                              : ElevatedButton(
                                onPressed: () => _loadNotifications(isLoadMore: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: HandsColors.handsOrange,
                                  foregroundColor: HandsColors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Load More', style: GoogleFonts.comfortaa(fontWeight: FontWeight.w500)),
                              ),
                    ),
                ],
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'MESSAGES',
          style: GoogleFonts.comfortaa(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: HandsColors.white,
          ),
        ),
        backgroundColor: HandsColors.scaffoldBackground,
        foregroundColor: HandsColors.white,
        elevation: 0,
      ),
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
