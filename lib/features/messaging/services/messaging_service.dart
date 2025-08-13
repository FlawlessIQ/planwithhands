import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_thread.dart';
import '../models/message.dart';

class MessagingService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> createThread({
    required String orgId,
    required String targetType,
    String? targetRef,
    List<String>? customUserIds,
    String? title,
    bool pushOnLogin = false,
  }) async {
    final threadRef = _db.collection('messageThreads').doc();
    await threadRef.set({
      'orgId': orgId,
      'createdBy': _auth.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'targetType': targetType,
      'targetRef': targetRef,
      'customUserIds': customUserIds ?? [],
      'recipientUserIds': [],
      'pushOnLogin': pushOnLogin,
      'title': title ?? 'Message',
    });
    return threadRef.id;
  }

  Future<void> sendMessage(String threadId, String text) async {
    final msgRef = _db.collection('messageThreads').doc(threadId).collection('messages').doc();
    await msgRef.set({
      'senderId': _auth.currentUser!.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('messageThreads').doc(threadId).set({
      'lastMessagePreview': text.substring(0, text.length > 80 ? 80 : text.length),
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<MessageThread>> watchThreads(String orgId, String userId) {
    return _db
        .collection('messageThreads')
        .where('orgId', isEqualTo: orgId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final notifSnap = await _db
          .collection('notifications')
          .where('orgId', isEqualTo: orgId)
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      final unreadByThread = <String, int>{};
      for (final d in notifSnap.docs) {
        final data = d.data();
        final tid = data['threadId'] as String?;
        if (tid != null) unreadByThread[tid] = (unreadByThread[tid] ?? 0) + 1;
      }
      return snap.docs
          .where((d) => (d.data()['recipientUserIds'] ?? []).contains(userId))
          .map((d) => MessageThread.fromDoc(d, unreadCount: unreadByThread[d.id] ?? 0))
          .toList();
    });
  }

  Stream<List<ThreadMessage>> watchMessages(String threadId) {
    return _db
        .collection('messageThreads')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(ThreadMessage.fromDoc).toList());
  }

  Future<void> markThreadRead(String threadId, String userId) async {
    final batch = _db.batch();
  final q = await _db
    .collection('notifications')
    .where('threadId', isEqualTo: threadId)
    .where('userId', isEqualTo: userId)
    .where('read', isEqualTo: false)
    .get();
    for (final d in q.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}
