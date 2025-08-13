import 'package:cloud_firestore/cloud_firestore.dart';

class MessageThread {
  final String id;
  final String orgId;
  final String createdBy;
  final DateTime createdAt;
  final String targetType; // all_users, shift, role, location, group, custom
  final String? targetRef;
  final List<String> recipientUserIds;
  final bool pushOnLogin;
  final String? title;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount; // computed client side

  MessageThread({
    required this.id,
    required this.orgId,
    required this.createdBy,
    required this.createdAt,
    required this.targetType,
    required this.targetRef,
    required this.recipientUserIds,
    required this.pushOnLogin,
    required this.title,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory MessageThread.fromDoc(DocumentSnapshot doc, {int unreadCount = 0}) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageThread(
      id: doc.id,
      orgId: data['orgId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      targetType: data['targetType'] ?? 'custom',
      targetRef: data['targetRef'],
      recipientUserIds: List<String>.from(data['recipientUserIds'] ?? const []),
      pushOnLogin: data['pushOnLogin'] ?? false,
      title: data['title'],
      lastMessagePreview: data['lastMessagePreview'],
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount: unreadCount,
    );
  }
}
