import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hands_app/features/messaging/models/message.dart';
import 'package:hands_app/features/messaging/services/messaging_service.dart';
import 'package:hands_app/widgets/responsive_appbar_title.dart';

class MessageThreadPage extends StatefulWidget {
  final String orgId;
  final String threadId;
  const MessageThreadPage({super.key, required this.orgId, required this.threadId});

  @override
  State<MessageThreadPage> createState() => _MessageThreadPageState();
}

class _MessageThreadPageState extends State<MessageThreadPage> {
  final _msgCtrl = TextEditingController();
  late final MessagingService _svc;

  @override
  void initState() {
    super.initState();
    _svc = MessagingService();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      Future.delayed(const Duration(milliseconds: 400), () => _svc.markThreadRead(widget.threadId, uid, widget.orgId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const ResponsiveAppBarTitle('Thread')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ThreadMessage>>(
              stream: _svc.watchMessages(widget.threadId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final isMine = m.senderId == FirebaseAuth.instance.currentUser?.uid;
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMine ? () => _showDeleteDialog(m) : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMine ? Colors.blue : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      m.text,
                                      style: TextStyle(color: isMine ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                  if (isMine) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _showDeleteDialog(m),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: isMine ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTs(m.createdAt),
                                style: TextStyle(fontSize: 11, color: isMine ? Colors.white70 : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintText: 'Message',
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final text = _msgCtrl.text.trim();
                    if (text.isEmpty) return;
                    await _svc.sendMessage(widget.threadId, text);
                    _msgCtrl.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTs(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDeleteDialog(ThreadMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Message'),
            content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _svc.deleteMessage(widget.threadId, message.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message deleted successfully'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete message: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}
