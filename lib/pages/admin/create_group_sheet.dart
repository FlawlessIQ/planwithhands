import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/shared/components/hands_buttons.dart';
import 'package:hands_app/shared/components/hands_bottom_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/widgets/hands_text_field.dart';

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
    final userDoc =
        await FirestoreEnforcer.instance
            .collection('users')
            .doc(current.uid)
            .get();
    final orgId = userDoc.data()?['organizationId'] as String?;

    if (orgId == null) return;
    _organizationId = orgId;

    // Load all users in this organization
    final snapshot =
        await FirestoreEnforcer.instance
            .collection('users')
            .where('organizationId', isEqualTo: orgId)
            .get();

    setState(() {
      _users =
          snapshot.docs.map((doc) {
            final data = doc.data();
            final firstName = data['firstName'] as String? ?? '';
            final lastName = data['lastName'] as String? ?? '';
            final email = data['email'] as String? ?? '';
            final name = '$firstName $lastName'.trim();
            return {
              'id': doc.id,
              'name': name.isEmpty ? (email.isNotEmpty ? email : doc.id) : name,
            };
          }).toList();
      _isLoading = false;
    });
  }

  Future<void> _fetchGroups() async {
    if (_organizationId == null) {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) return;

      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(current.uid)
              .get();
      _organizationId = userDoc.data()?['organizationId'] as String?;
    }

    if (_organizationId == null) return;

    final snapshot =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(_organizationId!)
            .collection('groups')
            .get();

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
    final l10n = context.l10n;
    final name = _groupNameController.text.trim();
    if (name.isEmpty || _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.audienceEnterNameAndMember)));
      return;
    }

    if (_organizationId == null) return;

    await FirestoreEnforcer.instance
        .collection('organizations')
        .doc(_organizationId!)
        .collection('groups')
        .add({
          'name': name,
          'memberIds': _selectedUserIds.toList(),
          'createdAt': FieldValue.serverTimestamp(),
        });

    _groupNameController.clear();
    _selectedUserIds.clear();
    await _fetchGroups(); // Refresh the groups list

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.audienceCreatedSuccess)));
    }
  }

  Future<void> _editGroup(String groupId, String currentName) async {
    final l10n = context.l10n;
    final TextEditingController editController = TextEditingController(
      text: currentName,
    );
    // Find the group and its current members
    final group = _groups.firstWhere((g) => g['id'] == groupId);
    final Set<String> selectedUserIds = Set<String>.from(
      group['memberIds'] as List,
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return HandsDialog(
              title: l10n.audienceEditTitle,
              maxWidth: 460,
              actions: [
                HandsSecondaryButton(
                  text: l10n.commonCancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                HandsPrimaryButton(
                  text: l10n.dashboardSave,
                  onPressed: () {
                    final name = editController.text.trim();
                    if (name.isNotEmpty && selectedUserIds.isNotEmpty) {
                      Navigator.of(context).pop({
                        'name': name,
                        'memberIds': selectedUserIds.toList(),
                      });
                    }
                  },
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HandsTextFormField(
                    controller: editController,
                    decoration: InputDecoration(
                      labelText: l10n.audienceNameLabel,
                      labelStyle: HandsModalTokens.labelStyle,
                      filled: true,
                      fillColor: HandsColors.secondaryContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(
                          color: HandsColors.white12,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(
                          color: HandsColors.white12,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(
                          color: HandsColors.handsOrange,
                          width: 2,
                        ),
                      ),
                    ),
                    style: GoogleFonts.inter(
                      color: HandsColors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.audienceMembersTitle,
                    style: HandsModalTokens.sectionTitleStyle,
                  ),
                  ..._users.map(
                    (user) => CheckboxListTile(
                      value: selectedUserIds.contains(user['id']),
                      title: Text(
                        user['name'],
                        style: GoogleFonts.inter(
                          color: HandsColors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedUserIds.add(user['id']);
                          } else {
                            selectedUserIds.remove(user['id']);
                          }
                        });
                      },
                      activeColor: HandsColors.handsOrange,
                      checkColor: HandsColors.white,
                    ),
                  ),
                ],
              ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.audienceUpdatedSuccess)));
      }
    }
    editController.dispose();
  }

  Future<void> _deleteGroup(String groupId, String groupName) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => HandsDialog(
            title: l10n.audienceDeleteTitle,
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
              l10n.audienceDeleteBody(groupName),
              style: HandsModalTokens.bodyStyle.copyWith(
                color: HandsModalTokens.text,
              ),
            ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.audienceDeletedSuccess)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HandsBottomSheet(
      title: l10n.messagesAudiencesTitle,
      subtitle: l10n.audienceSheetSubtitle,
      initialChildSize: 0.8,
      minChildSize: 0.42,
      maxChildSize: 0.95,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.audienceSavedTitle,
              style: HandsModalTokens.sectionTitleStyle,
            ),
            const SizedBox(height: 8),
            _isGroupsLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      HandsColors.handsOrange,
                    ),
                  ),
                )
                : _groups.isEmpty
                ? Text(
                  l10n.messagesNoAudiences,
                  style: GoogleFonts.inter(
                    color: HandsColors.white70,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                )
                : SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: HandsDecorations.tertiaryBoxDecoration,
                        child: ListTile(
                          title: Text(
                            group['name'],
                            style: GoogleFonts.inter(
                              color: HandsColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: Text(
                            l10n.messagesMemberCount(
                              (group['memberIds'] as List).length,
                            ),
                            style: GoogleFonts.inter(
                              color: HandsColors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: HandsColors.handsOrange,
                                ),
                                onPressed:
                                    () =>
                                        _editGroup(group['id'], group['name']),
                                tooltip: l10n.audienceEditTitle,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: HandsColors.error,
                                ),
                                onPressed:
                                    () => _deleteGroup(
                                      group['id'],
                                      group['name'],
                                    ),
                                tooltip: l10n.audienceDeleteTitle,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            const SizedBox(height: 24),
            Divider(color: HandsColors.white12, thickness: 1),
            const SizedBox(height: 16),
            Text(
              l10n.audienceNewTitle,
              style: HandsModalTokens.sectionTitleStyle,
            ),
            const SizedBox(height: 8),
            HandsTextFormField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: l10n.audienceNameLabel,
                labelStyle: HandsModalTokens.labelStyle,
                filled: true,
                fillColor: HandsColors.secondaryContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: HandsColors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: HandsColors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(
                    color: HandsColors.handsOrange,
                    width: 2,
                  ),
                ),
              ),
              style: GoogleFonts.inter(
                color: HandsColors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            HandsTextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: l10n.audienceSearchMembers,
                prefixIcon: const Icon(
                  Icons.search,
                  color: HandsColors.white70,
                ),
                labelStyle: HandsModalTokens.labelStyle,
                filled: true,
                fillColor: HandsColors.secondaryContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: HandsColors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: HandsColors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(
                    color: HandsColors.handsOrange,
                    width: 2,
                  ),
                ),
              ),
              style: GoogleFonts.inter(
                color: HandsColors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      HandsColors.handsOrange,
                    ),
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.audienceTeamMembers,
                      style: HandsModalTokens.sectionTitleStyle,
                    ),
                    ..._users
                        .where(
                          (user) =>
                              _searchQuery.isEmpty ||
                              user['name'].toLowerCase().contains(
                                _searchQuery,
                              ) ||
                              user['id'].toLowerCase().contains(_searchQuery),
                        )
                        .map(
                          (user) => CheckboxListTile(
                            value: _selectedUserIds.contains(user['id']),
                            title: Text(
                              user['name'],
                              style: GoogleFonts.inter(
                                color: HandsColors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedUserIds.add(user['id']);
                                } else {
                                  _selectedUserIds.remove(user['id']);
                                }
                              });
                            },
                            activeColor: HandsColors.handsOrange,
                            checkColor: HandsColors.white,
                          ),
                        ),
                  ],
                ),
            const SizedBox(height: 24),
            HandsPrimaryButton(
              text: l10n.audienceCreateButton,
              onPressed: _createGroup,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
