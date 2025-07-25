import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/state/notification_controller.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class SendNotificationSheet extends ConsumerStatefulWidget {
  const SendNotificationSheet({super.key});

  @override
  ConsumerState<SendNotificationSheet> createState() =>
      _SendNotificationSheetState();
}

class _SendNotificationSheetState
    extends ConsumerState<SendNotificationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _recipientType = 'All Users';
  String? _selectedGroup;
  String? _selectedLocation;
  // bool _pushOnLogin = false; // Removed the state variable

  List<Map<String, String>> _groups = [];
  List<String> _locations = [];

  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _updateTitle();
  }

  Future<void> _loadOptions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not signed in');
      final userDoc = await FirestoreEnforcer.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final orgId = userDoc.data()?['organizationId'] as String?;
      if (orgId == null) throw Exception('Organization not found');

      final groupsSnap = await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(orgId)
          .collection('groups')
          .get();
      final locSnap = await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .get();

      final groups = groupsSnap.docs.map((d) => {
        'id': d.id,
        'name': (d.data()['name'] as String?) ?? 'Unnamed Group'
      }).toList();
      final locations = locSnap.docs
          .map((d) => (d.data()['name'] as String?) ?? '')
          .where((l) => l.isNotEmpty)
          .toList();

      setState(() {
        _groups = groups;
        _locations = locations;
      });
    } catch (e) {
      debugPrint('Error loading notification options: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _updateTitle() {
    String t;
    switch (_recipientType) {
      case 'Group':
        if (_selectedGroup != null) {
          final groupName = _groups
              .firstWhere((g) => g['id'] == _selectedGroup,
                  orElse: () => {'name': _selectedGroup!})
              ['name'];
          t = "Message for '$groupName'";
        } else {
          t = 'Group Message';
        }
        break;
      case 'Location':
        t = _selectedLocation != null
            ? "Message for '$_selectedLocation'"
            : 'Location Message';
        break;
      default:
        t = 'General Announcement';
    }
    _titleController.text = t;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final ctrl = ref.read(notificationControllerProvider);
    try {
      String? recipientId;
      String? groupId;
      switch (_recipientType) {
        case 'Group':
          groupId = _selectedGroup;
          recipientId = 'all';
          break;
        case 'Location':
          recipientId = _selectedLocation;
          break;
        default:
          recipientId = null;
      }
      await ctrl.sendNotification(
        recipientId: recipientId ?? 'all',
        title: _titleController.text.trim(),
        body: _messageController.text.trim(),
        groupId: groupId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Failed to send: $e';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Send Notification',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Recipient type selector
                DropdownButtonFormField<String>(
                  value: _recipientType,
                  items: const [
                    DropdownMenuItem(value: 'All Users', child: Text('All Users')),
                    DropdownMenuItem(value: 'Group', child: Text('Send to Group')),
                    DropdownMenuItem(value: 'Location', child: Text('Send to Location')),
                  ],
                  decoration:
                      const InputDecoration(labelText: 'Recipient Type'),
                  onChanged: (v) {
                    setState(() {
                      _recipientType = v!;
                      _selectedGroup = null;
                      _selectedLocation = null;
                      _updateTitle();
                    });
                  },
                ),

                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (_recipientType == 'Group')
                    DropdownButtonFormField<String>(
                      value: _selectedGroup,
                      decoration: const InputDecoration(labelText: 'Select Group'),
                      hint: const Text('Choose a group'),
                      items: _groups.map((g) => DropdownMenuItem(
                            value: g['id'],
                            child: Text(g['name']!),
                          )).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedGroup = v;
                          _updateTitle();
                        });
                      },
                      validator: (v) => _recipientType == 'Group' && (v == null)
                          ? 'Please select a group'
                          : null,
                    ),
                  if (_recipientType == 'Location')
                    DropdownButtonFormField<String>(
                      value: _selectedLocation,
                      items: _locations
                          .map((l) =>
                              DropdownMenuItem(value: l, child: Text(l)))
                          .toList(),
                      decoration:
                          const InputDecoration(labelText: 'Select Location'),
                      onChanged: (v) {
                        setState(() {
                          _selectedLocation = v;
                          _updateTitle();
                        });
                      },
                      validator: (v) => _recipientType == 'Location' &&
                              (v == null || v.isEmpty)
                          ? 'Please select a location'
                          : null,
                    ),
                ],

                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 3,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter a message' : null,
                ),

                const SizedBox(height: 12),
                // Removed the Push on Login UI component

                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 16),
                _sending
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _send,
                          child: const Text('Send Notification'),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
