import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _groupNameFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final Set<String> _selectedUserIds = {};
  List<Map<String, String>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    _groupNameFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;
    // get this user’s orgId
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(current.uid)
        .get();
    final orgId = userDoc.data()?['organizationId'] as String?;

    if (orgId == null) return;
    // load all users in this organization
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('organizationId', isEqualTo: orgId)
        .get();

    setState(() {
      _users = snap.docs.map((doc) {
        final data = doc.data();
        final name = '${data['firstName'] as String? ?? ''} ${data['lastName'] as String? ?? ''}';
        return {
          'id': doc.id,
          'name': name.trim().isEmpty ? (data['email'] as String? ?? doc.id) : name,
        };
      }).toList();
      _isLoading = false;
    });
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty || _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a group name and select at least one user.'),
        ),
      );
      return;
    }

    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(current.uid)
        .get();
    final orgId = userDoc.data()?['organizationId'] as String?;
    if (orgId == null) return;

    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('groups')
        .add({
      'name': name,
      'memberIds': _selectedUserIds.toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((u) {
      final q = _searchQuery.toLowerCase();
      return q.isEmpty ||
          u['name']!.toLowerCase().contains(q) ||
          u['id']!.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Group',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _groupNameController,
                focusNode: _groupNameFocusNode,
                decoration: const InputDecoration(labelText: 'Group Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Search users',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                const Text('Select Users:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...filtered.map((user) {
                  final id = user['id']!;
                  return CheckboxListTile(
                    title: Text(user['name']!),
                    value: _selectedUserIds.contains(id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedUserIds.add(id);
                        } else {
                          _selectedUserIds.remove(id);
                        }
                      });
                    },
                  );
                }),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createGroup,
                  child: const Text('Create Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
