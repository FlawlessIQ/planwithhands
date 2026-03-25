import 'package:flutter/material.dart';
import 'package:hands_app/features/messaging/services/messaging_service.dart';
import 'package:hands_app/widgets/hands_text_field.dart';

class ThreadComposer extends StatefulWidget {
  final String orgId;
  const ThreadComposer({super.key, required this.orgId});

  @override
  State<ThreadComposer> createState() => _ThreadComposerState();
}

class _ThreadComposerState extends State<ThreadComposer> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  String _targetType = 'all_users';
  bool _pushOnLogin = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          children: [
            const Text('New Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _targetType,
              items: const [
                DropdownMenuItem(value: 'all_users', child: Text('All Users')),
                DropdownMenuItem(value: 'custom', child: Text('Custom (later)')),
              ],
              onChanged: (v) => setState(() => _targetType = v!),
              decoration: const InputDecoration(labelText: 'Target'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _pushOnLogin,
              onChanged: (v) => setState(() => _pushOnLogin = v),
              title: const Text('Push on login'),
            ),
            HandsTextFormField(
              controller: _messageCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a message' : null,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final svc = MessagingService();
                final threadId = await svc.createThread(
                  orgId: widget.orgId,
                  targetType: _targetType,
                  pushOnLogin: _pushOnLogin,
                );
                await svc.sendMessage(threadId, _messageCtrl.text.trim());
                if (mounted) Navigator.pop(context, threadId);
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
