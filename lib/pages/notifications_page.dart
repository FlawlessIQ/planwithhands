import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/state/notification_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

String _localizedNotificationField(
  Map<String, dynamic> data,
  String field,
  String localeCode,
) {
  final direct = data[field];
  final languageMap = data['${field}ByLanguage'];
  if (languageMap is Map) {
    final exact = languageMap[localeCode];
    if (exact is String && exact.trim().isNotEmpty) return exact;

    final baseCode = localeCode.split('-').first;
    final base = languageMap[baseCode];
    if (base is String && base.trim().isNotEmpty) return base;
  }

  if (direct is String && direct.trim().isNotEmpty) return direct;
  return '';
}

class NotificationListSheet extends ConsumerStatefulWidget {
  final void Function(String title, String details)? onMessageTap;
  final bool showHeader;
  final bool embedded;
  final String? title;

  const NotificationListSheet({
    super.key,
    this.onMessageTap,
    this.showHeader = true,
    this.embedded = false,
    this.title,
  });

  @override
  ConsumerState<NotificationListSheet> createState() =>
      _NotificationListSheetState();
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
    final userDoc =
        await FirestoreEnforcer.instance
            .collection('users')
            .doc(user.uid)
            .get();
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
            final localeCode = Localizations.localeOf(context).toLanguageTag();
            final localizedTitle = _localizedNotificationField(
              data,
              'title',
              localeCode,
            );
            final localizedMessage = _localizedNotificationField(
              data,
              'message',
              localeCode,
            );
            return {
              'id': doc.id,
              'title': localizedTitle,
              'message': localizedMessage,
              'createdAt': data['createdAt'],
              'readBy': List<String>.from(data['readBy'] ?? []),
              'archivedBy': List<String>.from(data['archivedBy'] ?? []),
              'type': data['type'] as String? ?? 'update',
              'targetType': data['targetType'] as String?,
              'locationName': data['locationName'] as String?,
              'locationId': data['locationId'] as String?,
              'summaryDate': data['summaryDate'] as String?,
              'summaryData': data['summaryData'],
              'titleByLanguage': data['titleByLanguage'],
              'messageByLanguage': data['messageByLanguage'],
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

    try {
      await FirestoreEnforcer.instance
          .collection('userNotifications')
          .doc(_userId!)
          .collection('notifications')
          .doc(id)
          .update({
            'archivedBy': FieldValue.arrayUnion([_userId]),
          });

      // Force refresh the unread count provider
      if (mounted) {
        ref.invalidate(notificationCountProvider);
        // Refresh current view
        await _loadNotifications(isLoadMore: false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationListSheet] Error archiving notification: $e');
      }
    }
  }

  Future<void> _unarchiveNotification(String id) async {
    if (_userId == null) return;

    try {
      await FirestoreEnforcer.instance
          .collection('userNotifications')
          .doc(_userId!)
          .collection('notifications')
          .doc(id)
          .update({
            'archivedBy': FieldValue.arrayRemove([_userId]),
          });

      // Force refresh the unread count provider
      if (mounted) {
        ref.invalidate(notificationCountProvider);
        // Refresh current view
        await _loadNotifications(isLoadMore: false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationListSheet] Error unarchiving notification: $e');
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    if (_userId == null) return;
    final l10n = context.l10n;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => HandsDialog(
            title: l10n.notificationsDeleteTitle,
            maxWidth: 440,
            actions: [
              HandsSecondaryButton(
                text: l10n.commonCancel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              HandsPrimaryButton(
                text: l10n.commonDelete,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
            child: Text(
              l10n.notificationsDeleteBody,
              style: HandsModalTokens.bodyStyle,
            ),
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
              content: Text(
                l10n.notificationsDeleteSuccess,
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: HandsColors.primary,
            ),
          );
          // Force refresh the unread count provider
          ref.invalidate(notificationCountProvider);
          // Refresh current view
          await _loadNotifications(isLoadMore: false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.notificationsDeleteFailed(e.toString()),
                style: GoogleFonts.inter(color: Colors.white),
              ),
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

    try {
      // Optimistically update local state
      final idx = _notifications.indexWhere((n) => n['id'] == id);
      if (idx != -1 &&
          !(_notifications[idx]['readBy'] as List<String>).contains(_userId)) {
        setState(() {
          (_notifications[idx]['readBy'] as List<String>).add(_userId!);
        });
      }

      // Update Firestore
      await FirestoreEnforcer.instance
          .collection('userNotifications')
          .doc(_userId!)
          .collection('notifications')
          .doc(id)
          .update({
            'readBy': FieldValue.arrayUnion([_userId]),
          });

      // Force refresh the unread count provider by invalidating it
      if (mounted) {
        ref.invalidate(notificationCountProvider);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationListSheet] Error marking notification as read: $e');
      }
    }
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
    final l10n = context.l10n;
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

    final locale = Localizations.localeOf(context).toLanguageTag();
    final timeFormat = DateFormat('h:mm a', locale);
    final dateFormat = DateFormat('MMM d', locale);
    final fullDateFormat = DateFormat('MMM d, yyyy', locale);

    if (messageDate == today) {
      // Today - show just time
      return timeFormat.format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return l10n.notificationsYesterdayAt(timeFormat.format(dateTime));
    } else if (dateTime.year == now.year) {
      // This year - show month, day and time
      return '${dateFormat.format(dateTime)} ${timeFormat.format(dateTime)}';
    } else {
      // Different year - show full date and time
      return '${fullDateFormat.format(dateTime)} ${timeFormat.format(dateTime)}';
    }
  }

  String _notificationTypeLabel(Map<String, dynamic> notification) {
    final l10n = context.l10n;
    switch ((notification['type'] as String? ?? '').toLowerCase()) {
      case 'daily_summary':
        return l10n.notificationsSummaryType;
      case 'broadcast':
        return l10n.messagesBroadcastsTitle;
      default:
        return l10n.notificationsUpdateType;
    }
  }

  IconData _notificationIcon(Map<String, dynamic> notification) {
    switch ((notification['type'] as String? ?? '').toLowerCase()) {
      case 'daily_summary':
        return Icons.insights_outlined;
      case 'broadcast':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _notificationAccent(Map<String, dynamic> notification) {
    switch ((notification['type'] as String? ?? '').toLowerCase()) {
      case 'daily_summary':
        return HandsColors.handsOrange;
      case 'broadcast':
        return const Color(0xFF57B7FF);
      default:
        return HandsColors.sageGreen;
    }
  }

  String _previewMessage(String message) {
    return message.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    if (widget.onMessageTap != null) {
      widget.onMessageTap!(
        (notification['title'] as String?) ?? '',
        (notification['message'] as String?) ?? '',
      );
      return;
    }

    await NotificationDetailSheet.show(
      context: context,
      notification: notification,
      timestampLabel: _formatTimestamp(notification['createdAt']),
      isArchived: (notification['archivedBy'] as List<String>).contains(
        _userId,
      ),
      onArchive:
          _userId == null
              ? null
              : () => _archiveNotification(notification['id'] as String),
      onUnarchive:
          _userId == null
              ? null
              : () => _unarchiveNotification(notification['id'] as String),
      onDelete:
          _userId == null
              ? null
              : () => _deleteNotification(notification['id'] as String),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localizedTitle = widget.title ?? l10n.notificationsInbox;
    final filterLabels = <String, String>{
      'Unread': l10n.notificationsUnread,
      'Read': l10n.notificationsRead,
      'Archived': l10n.notificationsArchived,
    };
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          Text(
            localizedTitle,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: HandsColors.white,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.notificationsHeaderSubtitle,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: HandsColors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
        ],
        _InboxSegmentedFilter(
          currentValue: _viewFilter,
          items:
              ['Unread', 'Read', 'Archived']
                  .map(
                    (filter) => _InboxFilterItem(
                      value: filter,
                      label: filterLabels[filter] ?? filter,
                    ),
                  )
                  .toList(),
          onChanged: _onViewFilterChanged,
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  HandsColors.handsOrange,
                ),
              ),
            ),
          )
        else if (_notifications.isEmpty)
          Expanded(
            child: Center(
              child: _InboxEmptyState(
                title: l10n.notificationsNoMessagesIn(
                  (filterLabels[_viewFilter] ?? _viewFilter).toLowerCase(),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      final isRead = (n['readBy'] as List<String>).contains(
                        _userId,
                      );
                      final isArchived = (n['archivedBy'] as List<String>)
                          .contains(_userId);
                      final title =
                          n['title'] as String? ?? l10n.notificationsNewMessage;
                      final details =
                          n['message'] as String? ??
                          l10n.notificationsNoContent;
                      final timestamp = _formatTimestamp(n['createdAt']);

                      return _NotificationFeedCard(
                        title: title,
                        preview: _previewMessage(details),
                        timestamp: timestamp,
                        typeLabel: _notificationTypeLabel(n),
                        icon: _notificationIcon(n),
                        accent: _notificationAccent(n),
                        isRead: isRead,
                        isArchived: isArchived,
                        onTap: () async {
                          await _openNotification(n);
                          if (!isRead) {
                            await _markNotificationAsRead(n['id'] as String);
                          }
                        },
                        menuBuilder:
                            (context) => [
                              PopupMenuItem(
                                value: isArchived ? 'unarchive' : 'archive',
                                child: Text(
                                  isArchived
                                      ? l10n.commonUnarchive
                                      : l10n.commonArchive,
                                  style: GoogleFonts.inter(
                                    color: HandsColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  l10n.commonDelete,
                                  style: GoogleFonts.inter(
                                    color: HandsColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                        onMenuSelected: (value) {
                          if (value == 'archive') {
                            _archiveNotification(n['id'] as String);
                          } else if (value == 'unarchive') {
                            _unarchiveNotification(n['id'] as String);
                          } else if (value == 'delete') {
                            _deleteNotification(n['id'] as String);
                          }
                        },
                      );
                    },
                  ),
                ),
                if (_hasMoreData && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child:
                        _isLoadingMore
                            ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                HandsColors.handsOrange,
                              ),
                            )
                            : HandsSecondaryButton(
                              text: l10n.notificationsLoadMore,
                              onPressed:
                                  () => _loadNotifications(isLoadMore: true),
                            ),
                  ),
              ],
            ),
          ),
      ],
    );

    if (widget.embedded) {
      return Padding(padding: const EdgeInsets.all(18), child: content);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: HandsDecorations.primaryBoxDecoration,
      child: content,
    );
  }
}

class _InboxFilterItem {
  final String value;
  final String label;

  const _InboxFilterItem({required this.value, required this.label});
}

class _InboxSegmentedFilter extends StatelessWidget {
  final String currentValue;
  final List<_InboxFilterItem> items;
  final ValueChanged<String> onChanged;

  const _InboxSegmentedFilter({
    required this.currentValue,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: HandsModalTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Row(
        children:
            items.map((item) {
              final selected = item.value == currentValue;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => onChanged(item.value),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? HandsColors.handsOrange
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color:
                              selected
                                  ? HandsColors.white
                                  : HandsColors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _InboxEmptyState extends StatelessWidget {
  final String title;

  const _InboxEmptyState({required this.title});

  @override
  Widget build(BuildContext context) {
    return HandsModalSection(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: HandsColors.secondaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: HandsColors.white70,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: HandsColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationFeedCard extends StatelessWidget {
  final String title;
  final String preview;
  final String timestamp;
  final String typeLabel;
  final IconData icon;
  final Color accent;
  final bool isRead;
  final bool isArchived;
  final VoidCallback onTap;
  final void Function(String value) onMenuSelected;
  final List<PopupMenuEntry<String>> Function(BuildContext context) menuBuilder;

  const _NotificationFeedCard({
    required this.title,
    required this.preview,
    required this.timestamp,
    required this.typeLabel,
    required this.icon,
    required this.accent,
    required this.isRead,
    required this.isArchived,
    required this.onTap,
    required this.onMenuSelected,
    required this.menuBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isRead
                  ? HandsModalTokens.surfaceElevated
                  : const Color(0xFF202632),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isArchived
                    ? HandsColors.white12
                    : isRead
                    ? HandsModalTokens.border
                    : accent.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight:
                                isRead ? FontWeight.w700 : FontWeight.w800,
                            color: HandsColors.white,
                            letterSpacing: -0.2,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timestamp,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: HandsColors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: HandsColors.white70,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MessageMetaChip(label: typeLabel, accent: accent),
                      const SizedBox(width: 8),
                      _MessageMetaChip(
                        label:
                            isArchived
                                ? context.l10n.notificationsArchived
                                : isRead
                                ? context.l10n.notificationsRead
                                : context.l10n.notificationsUnread,
                        accent:
                            isArchived
                                ? HandsColors.white70
                                : isRead
                                ? const Color(0xFF7C8698)
                                : HandsColors.handsOrange,
                      ),
                      const Spacer(),
                      if (!isRead && !isArchived)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: HandsColors.white54,
              ),
              color: HandsModalTokens.surfaceElevated,
              onSelected: onMenuSelected,
              itemBuilder: menuBuilder,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageMetaChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _MessageMetaChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

class NotificationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String timestampLabel;
  final bool isArchived;

  const NotificationDetailSheet({
    super.key,
    required this.notification,
    required this.timestampLabel,
    required this.isArchived,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> notification,
    required String timestampLabel,
    required bool isArchived,
    VoidCallback? onArchive,
    VoidCallback? onUnarchive,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => NotificationDetailSheet(
            notification: notification,
            timestampLabel: timestampLabel,
            isArchived: isArchived,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title =
        (notification['title'] as String?) ?? l10n.notificationsNewMessage;
    final message =
        (notification['message'] as String?) ?? l10n.notificationsNoContent;
    final type = (notification['type'] as String? ?? 'update').toLowerCase();
    final summaryData = notification['summaryData'];

    final accent = switch (type) {
      'daily_summary' => HandsColors.handsOrange,
      'broadcast' => const Color(0xFF57B7FF),
      _ => HandsColors.sageGreen,
    };
    final typeLabel = switch (type) {
      'daily_summary' => l10n.notificationsSummaryType,
      'broadcast' => l10n.messagesBroadcastsTitle,
      _ => l10n.notificationsUpdateType,
    };

    return HandsBottomSheet(
      title: title,
      subtitle: typeLabel,
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.96,
      actions: [
        HandsSecondaryButton(
          text: l10n.commonClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MessageMetaChip(label: typeLabel, accent: accent),
                const SizedBox(width: 8),
                _MessageMetaChip(
                  label:
                      isArchived
                          ? l10n.notificationsArchived
                          : l10n.notificationsUnread,
                  accent:
                      isArchived
                          ? HandsColors.white70
                          : HandsColors.handsOrange,
                ),
                const Spacer(),
                Text(
                  timestampLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: HandsColors.white60,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (type == 'daily_summary' && summaryData is Map<String, dynamic>)
              _DailySummaryDetail(summaryData: summaryData, fallback: message)
            else
              _GenericMessageDetailBody(message: message),
          ],
        ),
      ),
    );
  }
}

class _GenericMessageDetailBody extends StatelessWidget {
  final String message;

  const _GenericMessageDetailBody({required this.message});

  @override
  Widget build(BuildContext context) {
    final paragraphs =
        message
            .split(RegExp(r'\n\s*\n'))
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList();

    return HandsModalSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            paragraphs
                .map(
                  (paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      paragraph,
                      style: HandsModalTokens.bodyStyle.copyWith(
                        color: HandsColors.white,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _DailySummaryDetail extends StatelessWidget {
  final Map<String, dynamic> summaryData;
  final String fallback;

  const _DailySummaryDetail({
    required this.summaryData,
    required this.fallback,
  });

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! Iterable) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overallStats =
        (summaryData['overallStats'] as Map?)?.cast<String, dynamic>() ?? {};
    final shiftCompletions = _mapList(summaryData['shiftCompletions']);
    final missedTaskEntries = _mapList(summaryData['missedTaskEntries']);
    final notesEntries = _mapList(summaryData['notesEntries']);
    final photoBypassed = _mapList(summaryData['photoBypassed']);

    final totalTasks = overallStats['totalTasks'] as int? ?? 0;
    final completedTasks = overallStats['completedTasks'] as int? ?? 0;
    final incompleteTasks =
        overallStats['incompleteTasks'] as int? ?? missedTaskEntries.length;
    final overallPercentage =
        (overallStats['overallPercentage'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HandsModalSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.notificationsSummaryOverview,
                style: HandsModalTokens.sectionTitleStyle,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetricCard(
                      label: l10n.notificationsSummaryCompletion,
                      value: '${overallPercentage.toStringAsFixed(0)}%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryMetricCard(
                      label: l10n.notificationsSummaryTasks,
                      value: '$completedTasks/$totalTasks',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryMetricCard(
                      label: l10n.notificationsSummaryMissedTasks,
                      value: '$incompleteTasks',
                    ),
                  ),
                ],
              ),
              if (notesEntries.isNotEmpty || photoBypassed.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (notesEntries.isNotEmpty)
                      Expanded(
                        child: _SummaryMetricCard(
                          label: l10n.notificationsSummaryNotes,
                          value: '${notesEntries.length}',
                        ),
                      ),
                    if (notesEntries.isNotEmpty && photoBypassed.isNotEmpty)
                      const SizedBox(width: 10),
                    if (photoBypassed.isNotEmpty)
                      Expanded(
                        child: _SummaryMetricCard(
                          label: l10n.notificationsSummaryPhotoBypassed,
                          value: '${photoBypassed.length}',
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (shiftCompletions.isNotEmpty) ...[
          const SizedBox(height: 14),
          HandsModalSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.notificationsSummaryLocations,
                  style: HandsModalTokens.sectionTitleStyle,
                ),
                const SizedBox(height: 12),
                ...shiftCompletions
                    .take(6)
                    .map(
                      (shift) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SummaryLocationRow(
                          locationName:
                              (shift['locationName'] as String?) ??
                              l10n.commonNotSpecified,
                          shiftName:
                              (shift['shiftName'] as String?) ??
                              l10n.commonNotSpecified,
                          completedTasks: shift['completedTasks'] as int? ?? 0,
                          totalTasks: shift['totalTasks'] as int? ?? 0,
                          percentage:
                              (shift['completionPercentage'] as num?)
                                  ?.toDouble() ??
                              0,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
        if (missedTaskEntries.isNotEmpty) ...[
          const SizedBox(height: 14),
          HandsModalSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.notificationsSummaryMissedTasks,
                  style: HandsModalTokens.sectionTitleStyle,
                ),
                const SizedBox(height: 12),
                ...missedTaskEntries
                    .take(5)
                    .map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SummaryTaskRow(
                          title:
                              (task['taskName'] as String?) ??
                              l10n.notificationsNoContent,
                          contextLine: [
                            if ((task['shiftName'] as String?)?.isNotEmpty ??
                                false)
                              task['shiftName'] as String,
                            if ((task['locationName'] as String?)?.isNotEmpty ??
                                false)
                              task['locationName'] as String,
                          ].join(' • '),
                          reason:
                              (task['reason'] as String?)?.trim().isNotEmpty ==
                                      true
                                  ? task['reason'] as String
                                  : l10n.notificationsSummaryNoReason,
                        ),
                      ),
                    ),
                if (missedTaskEntries.length > 5)
                  Text(
                    l10n.notificationsSummaryMoreItems(
                      missedTaskEntries.length - 5,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: HandsColors.white60,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (shiftCompletions.isEmpty && missedTaskEntries.isEmpty) ...[
          const SizedBox(height: 14),
          _GenericMessageDetailBody(message: fallback),
        ],
      ],
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HandsModalTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: HandsColors.white60,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: HandsColors.white,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLocationRow extends StatelessWidget {
  final String locationName;
  final String shiftName;
  final int completedTasks;
  final int totalTasks;
  final double percentage;

  const _SummaryLocationRow({
    required this.locationName,
    required this.shiftName,
    required this.completedTasks,
    required this.totalTasks,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        percentage >= 90
            ? HandsColors.sageGreen
            : percentage >= 70
            ? HandsColors.amber
            : HandsColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HandsModalTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationName,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: HandsColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shiftName,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: HandsColors.white60,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$completedTasks/$totalTasks',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HandsColors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTaskRow extends StatelessWidget {
  final String title;
  final String contextLine;
  final String reason;

  const _SummaryTaskRow({
    required this.title,
    required this.contextLine,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HandsModalTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HandsModalTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HandsColors.white,
            ),
          ),
          if (contextLine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              contextLine,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: HandsColors.white60,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            reason,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: HandsColors.white70,
              height: 1.35,
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
          context.l10n.notificationsInbox,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: HandsColors.white,
          ),
        ),
        backgroundColor: HandsColors.scaffoldBackground,
        foregroundColor: HandsColors.white,
        elevation: 0,
      ),
      body: const NotificationListSheet(showHeader: false),
    );
  }
}
