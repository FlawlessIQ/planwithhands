import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hands_app/features/messaging/models/message_thread.dart';
import 'package:hands_app/features/messaging/pages/message_thread_page.dart';
import 'package:hands_app/features/messaging/services/messaging_service.dart';
import 'package:hands_app/features/messaging/widgets/thread_composer.dart';
import 'package:hands_app/widgets/responsive_appbar_title.dart';

class MessageInboxPage extends StatelessWidget {
  final String orgId;
  const MessageInboxPage({super.key, required this.orgId});

  @override
  Widget build(BuildContext context) {
    final svc = MessagingService();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const ResponsiveAppBarTitle('Messages')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please sign in to view messages.'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/login'), child: const Text('Sign in')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const ResponsiveAppBarTitle('Messages')),
      body: StreamBuilder<List<MessageThread>>(
        stream: svc.watchThreads(orgId, uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final threads = snap.data ?? [];
          if (threads.isEmpty) {
            return const Center(child: Text('No threads yet'));
          }
          return ListView.separated(
            itemCount: threads.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = threads[i];
              return ListTile(
                title: Text(t.lastMessagePreview ?? '(no message)'),
                subtitle: Text(t.targetType),
                trailing:
                    t.unreadCount > 0
                        ? CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Text('${t.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        )
                        : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MessageThreadPage(orgId: orgId, threadId: t.id)),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final threadId = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (_) => ThreadComposer(orgId: orgId),
          );
          if (threadId != null && context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MessageThreadPage(orgId: orgId, threadId: threadId)),
            );
          }
        },
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}
