import 'package:cloud_firestore/cloud_firestore.dart';

class ThreadMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  ThreadMessage({required this.id, required this.senderId, required this.text, required this.createdAt});

  factory ThreadMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ThreadMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
