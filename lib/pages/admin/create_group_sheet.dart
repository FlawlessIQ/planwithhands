import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _groups = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isGroupsLoading = true;
  String _searchQuery = '';
  String? _organizationId;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchGroups();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;

    // Get this user's organization ID
    final userDoc = await FirestoreEnforcer.instance.collection('users').doc(current.uid).get();
    final orgId = userDoc.data()?['organizationId'] as String?;

    if (orgId == null) return;
    _organizationId = orgId;

    // Load all users in this organization
    final snapshot =
        await FirestoreEnforcer.instance.collection('users').where('organizationId', isEqualTo: orgId).get();

    setState(() {
      _users =
          snapshot.docs.map((doc) {
            final data = doc.data();
            final firstName = data['firstName'] as String? ?? '';
            final lastName = data['lastName'] as String? ?? '';
            final email = data['email'] as String? ?? '';
            final name = '$firstName $lastName'.trim();
            return {'id': doc.id, 'name': name.isEmpty ? (email.isNotEmpty ? email : doc.id) : name};
          }).toList();
      _isLoading = false;
    });
  }

  Future<void> _fetchGroups() async {
    if (_organizationId == null) {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) return;

      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(current.uid).get();
      _organizationId = userDoc.data()?['organizationId'] as String?;
    }

    if (_organizationId == null) return;

    final snapshot =
        await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId!).collection('groups').get();

    setState(() {
      _groups =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unnamed Group',
              'memberIds': data['memberIds'] ?? [],
              'createdAt': data['createdAt'],
            };
          }).toList();
      _isGroupsLoading = false;
    });
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty || _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a group name and select at least one user.')));
      return;
    }

    if (_organizationId == null) return;

    await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId!).collection('groups').add({
      'name': name,
      'memberIds': _selectedUserIds.toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    _groupNameController.clear();
    _selectedUserIds.clear();
    await _fetchGroups(); // Refresh the groups list

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group created successfully!')));
    }
  }

  Future<void> _editGroup(String groupId, String currentName) async {
    final TextEditingController editController = TextEditingController(text: currentName);
    // Find the group and its current members
    final group = _groups.firstWhere((g) => g['id'] == groupId);
    final Set<String> selectedUserIds = Set<String>.from(group['memberIds'] as List);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Group'),
              content: SizedBox(
                width: 350,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: editController,
                        decoration: const InputDecoration(labelText: 'Group Name'),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      const Text('Edit Members:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._users.map(
                        (user) => CheckboxListTile(
                          value: selectedUserIds.contains(user['id']),
                          title: Text(user['name']),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedUserIds.add(user['id']);
                              } else {
                                selectedUserIds.remove(user['id']);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    final name = editController.text.trim();
                    if (name.isNotEmpty && selectedUserIds.isNotEmpty) {
                      Navigator.of(context).pop({'name': name, 'memberIds': selectedUserIds.toList()});
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && _organizationId != null) {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(_organizationId!)
          .collection('groups')
          .doc(groupId)
          .update({
            'name': result['name'],
            'memberIds': result['memberIds'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
      await _fetchGroups(); // Refresh the groups list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group updated successfully!')));
      }
    }
    editController.dispose();
  }

  Future<void> _deleteGroup(String groupId, String groupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Group'),
            content: Text('Are you sure you want to delete the group "$groupName"? This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true && _organizationId != null) {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(_organizationId!)
          .collection('groups')
          .doc(groupId)
          .delete();
      await _fetchGroups(); // Refresh the groups list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group deleted successfully!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manage Groups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      splashRadius: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Existing Groups:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _isGroupsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _groups.isEmpty
                  ? const Text('No groups created yet.')
                  : SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return Card(
                          child: ListTile(
                            title: Text(group['name']),
                            subtitle: Text('${group['memberIds'].length} members'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _editGroup(group['id'], group['name']),
                                  tooltip: 'Edit group',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteGroup(group['id'], group['name']),
                                  tooltip: 'Delete group',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text('Create New Group:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: _groupNameController, decoration: const InputDecoration(labelText: 'Group Name')),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(labelText: 'Search users', prefixIcon: Icon(Icons.search)),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 8),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Users:'),
                      ..._users
                          .where(
                            (user) =>
                                _searchQuery.isEmpty ||
                                user['name'].toLowerCase().contains(_searchQuery) ||
                                user['id'].toLowerCase().contains(_searchQuery),
                          )
                          .map(
                            (user) => CheckboxListTile(
                              value: _selectedUserIds.contains(user['id']),
                              title: Text(user['name']),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedUserIds.add(user['id']);
                                  } else {
                                    _selectedUserIds.remove(user['id']);
                                  }
                                });
                              },
                            ),
                          ),
                    ],
                  ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _createGroup, child: const Text('Create New Group')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
