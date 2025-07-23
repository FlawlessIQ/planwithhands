import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/data/models/schedule_entry_data.dart';
import 'package:hands_app/data/models/extended_user_data.dart';

class ShiftBottomSheet extends StatefulWidget {
  final String scheduleId;
  final String dayShiftKey;
  final String shiftId;
  final String shiftName;
  final Map<String, int> defaultParLevels;
  final String organizationId;
  final String locationId;
  final ScheduleEntryData? existingEntry;
  final Map<String, bool>? availability;

  const ShiftBottomSheet({
    super.key,
    required this.scheduleId,
    required this.dayShiftKey,
    required this.shiftId,
    required this.shiftName,
    required this.defaultParLevels,
    required this.organizationId,
    required this.locationId,
    this.existingEntry,
    this.availability,
  });

  @override
  State<ShiftBottomSheet> createState() => _ShiftBottomSheetState();
}

class _ShiftBottomSheetState extends State<ShiftBottomSheet> {
  late Map<String, int> requiredRoles;
  late Set<String> assignedUserIds;
  List<ExtendedUserData> availableUsers = [];
  Map<String, String> roleNames = {};
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    requiredRoles = Map<String, int>.from(widget.existingEntry?.requiredRoles ?? widget.defaultParLevels);
    assignedUserIds = Set<String>.from(widget.existingEntry?.assignedUserIds ?? []);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    try {
      await Future.wait([
        _loadRoleNames(),
        _loadAvailableUsers(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadRoleNames() async {
    try {
      // Since we now use role names directly as keys in requiredRoles,
      // we can create a simple mapping of name -> name
      final names = <String, String>{};
      
      // For each role in requiredRoles, map the name to itself
      for (final roleName in requiredRoles.keys) {
        names[roleName] = roleName;
      }
      
      // Also try to load from the old system for backward compatibility
      var rolesSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('roles')
          .get();

      // Fallback to jobTypes if roles collection is empty
      if (rolesSnapshot.docs.isEmpty) {
        rolesSnapshot = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('jobTypes')
            .get();
      }

      // Add any role definitions from the database
      for (final doc in rolesSnapshot.docs) {
        final roleName = doc.data()['name'] as String? ?? doc.id;
        names[doc.id] = roleName;
        // Also map the name to itself for direct lookup
        names[roleName] = roleName;
      }
      
      if (mounted) {
        setState(() => roleNames = names);
      }
    } catch (e) {
      debugPrint('Error loading role names: $e');
      // If there's an error, still create a basic mapping for the required roles
      final names = <String, String>{};
      for (final roleName in requiredRoles.keys) {
        names[roleName] = roleName;
      }
      if (mounted) {
        setState(() => roleNames = names);
      }
    }
  }

  Future<void> _loadAvailableUsers() async {
    try {
      debugPrint('Loading users for org: ${widget.organizationId}, location: ${widget.locationId}, dayShiftKey: ${widget.dayShiftKey}');
      
      // Debug: Check current user authentication and role
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        debugPrint('Current user UID: ${currentUser.uid}');
        try {
          final currentUserDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (currentUserDoc.exists) {
            final userData = currentUserDoc.data()!;
            debugPrint('Current user role: ${userData['userRole']}, org: ${userData['organizationId']}');
          }
        } catch (e) {
          debugPrint('Error getting current user data: $e');
        }
      } else {
        debugPrint('No authenticated user found');
      }
      
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('organizationId', isEqualTo: widget.organizationId)
          .get();

      debugPrint('Found ${usersSnapshot.docs.length} users in organization');

      final users = <ExtendedUserData>[];
      for (final doc in usersSnapshot.docs) {
        final userData = ExtendedUserData.fromMap(doc.data(), doc.id);
        debugPrint('Processing user: ${userData.fullName}, roles: ${userData.jobTypes}, userRole: ${userData.userRole}');
        // Filter users by availability if provided
        final userRoles = Set<String>.from(userData.jobTypes);
        final shiftRoles = Set<String>.from(requiredRoles.keys);
        final hasRelevantRole = shiftRoles.isEmpty || userRoles.intersection(shiftRoles).isNotEmpty;
        bool isAvailable = false;
        if (widget.availability != null) {
          isAvailable = widget.availability![widget.dayShiftKey] ?? false;
        } else {
          isAvailable = userData.availability[widget.dayShiftKey] ?? false;
        }
        // ...existing code for location access...
        bool hasLocationAccess = false;
        if (userData.userRole == 2) {
          hasLocationAccess = true;
        } else if (userData.userRole == 1 && userData.locationIds != null) {
          hasLocationAccess = userData.locationIds!.contains(widget.locationId);
        } else if (userData.userRole == 0 && userData.locationId != null) {
          hasLocationAccess = userData.locationId == widget.locationId;
        }
        // Include users who: have relevant role OR are already assigned, AND have location access, AND (are available OR already assigned)
        if (hasRelevantRole && hasLocationAccess && (isAvailable || assignedUserIds.contains(userData.userId))) {
          users.add(userData);
          debugPrint('\u2713 Added user: ${userData.fullName}');
        } else {
          debugPrint('\u2717 Excluded user: ${userData.fullName} - hasRelevantRole=$hasRelevantRole, hasLocationAccess=$hasLocationAccess, isAvailable=$isAvailable, isAssigned=${assignedUserIds.contains(userData.userId)}');
        }
      }

      debugPrint('Final user count: ${users.length}');

      // Sort users: assigned first, then by name
      users.sort((a, b) {
        final aAssigned = assignedUserIds.contains(a.userId);
        final bAssigned = assignedUserIds.contains(b.userId);
        
        if (aAssigned && !bAssigned) return -1;
        if (!aAssigned && bAssigned) return 1;
        
        return a.fullName.compareTo(b.fullName);
      });

      if (mounted) {
        setState(() => availableUsers = users);
      }
    } catch (e) {
      debugPrint('Error loading available users: $e');
    }
  }

  Future<List<ExtendedUserData>> _getAssignedUsers() async {
    try {
      final assignedUsers = <ExtendedUserData>[];
      
      // Get user data for all assigned user IDs
      for (final userId in assignedUserIds) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final userData = ExtendedUserData.fromMap(userDoc.data()!, userDoc.id);
          assignedUsers.add(userData);
        }
      }
      
      // Sort by name
      assignedUsers.sort((a, b) => a.fullName.compareTo(b.fullName));
      
      return assignedUsers;
    } catch (e) {
      debugPrint('Error loading assigned users: $e');
      return [];
    }
  }

  void _toggleUserAssignment(String userId) {
    setState(() {
      if (assignedUserIds.contains(userId)) {
        assignedUserIds.remove(userId);
      } else {
        assignedUserIds.add(userId);
      }
    });
  }

  void _updateRequiredCount(String roleId, int count) {
    setState(() {
      if (count <= 0) {
        requiredRoles.remove(roleId);
      } else {
        requiredRoles[roleId] = count;
      }
    });
  }

  Future<void> _saveEntry() async {
    setState(() => isSaving = true);

    try {
      final entryId = widget.existingEntry?.id ?? 
                      FirebaseFirestore.instance.collection('temp').doc().id;

      final entryData = ScheduleEntryData(
        id: entryId,
        dayShiftKey: widget.dayShiftKey,
        requiredRoles: requiredRoles,
        assignedUserIds: assignedUserIds.toList(),
        scheduleId: widget.scheduleId,
        shiftId: widget.shiftId,
      );

      final batch = FirebaseFirestore.instance.batch();

      // Save the schedule entry
      final entryRef = FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('schedules')
          .doc(widget.scheduleId)
          .collection('entries')
          .doc(entryId);
      
      batch.set(entryRef, entryData.toMap());

      // Create or update the schedule document (mark as draft by default)
      final scheduleRef = FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('schedules')
          .doc(widget.scheduleId);

      // Extract date from dayShiftKey (format: "YYYY-MM-DD_shiftId")
      final datePart = widget.dayShiftKey.split('_')[0];
      final scheduleDate = DateTime.parse(datePart);
      
      batch.set(scheduleRef, {
        'id': widget.scheduleId,
        'startDate': Timestamp.fromDate(DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day)),
        'endDate': Timestamp.fromDate(DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day, 23, 59, 59)),
        'published': false, // Default to draft mode
        'organizationId': widget.organizationId,
        'locationId': widget.locationId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift schedule updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving schedule: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void _showAddRoleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Required Role'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: roleNames.length,
            itemBuilder: (context, index) {
              final roleId = roleNames.keys.elementAt(index);
              final roleName = roleNames[roleId]!;
              final isAlreadyAdded = requiredRoles.containsKey(roleId);
              
              return ListTile(
                title: Text(roleName),
                subtitle: isAlreadyAdded ? const Text('Already added') : null,
                trailing: isAlreadyAdded 
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: isAlreadyAdded ? null : () {
                  Navigator.pop(context);
                  setState(() {
                    requiredRoles[roleId] = 1; // Default to 1 person needed
                  });
                  // Reload users to reflect new role requirements
                  _loadAvailableUsers();
                },
                enabled: !isAlreadyAdded,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  int get totalRequired => requiredRoles.values.fold(0, (total, roleCount) => total + roleCount);
  int get totalAssigned => assignedUserIds.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.shiftName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            widget.dayShiftKey.replaceAll('_', ' '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: totalAssigned >= totalRequired 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: totalAssigned >= totalRequired 
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        totalAssigned >= totalRequired 
                            ? Icons.check_circle 
                            : Icons.schedule,
                        color: totalAssigned >= totalRequired 
                            ? Colors.green 
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$totalAssigned of $totalRequired assigned',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: totalAssigned >= totalRequired 
                              ? Colors.green[700] 
                              : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Required roles section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Required Roles',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _showAddRoleDialog,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Role'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (requiredRoles.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'No roles assigned to this shift. Tap "Add Role" to add required positions.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...requiredRoles.entries.map((entry) => _buildRoleRequirement(entry.key, entry.value)),
                        
                        const SizedBox(height: 24),
                        
                        // Assigned users section
                        Text(
                          'Assigned Users',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (assignedUserIds.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                              'No users assigned yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              // Get assigned users - first try from availableUsers, then fetch from Firestore if needed
                              final assignedUsersFromAvailable = availableUsers.where((user) => assignedUserIds.contains(user.userId)).toList();
                              
                              // If we have all assigned users in availableUsers, show them
                              if (assignedUsersFromAvailable.length == assignedUserIds.length) {
                                return Column(
                                  children: assignedUsersFromAvailable.map((user) => _buildUserTileWithConflict(user)).toList(),
                                );
                              }
                              
                              // Otherwise, fetch the missing users from Firestore
                              return FutureBuilder<List<ExtendedUserData>>(
                                future: _getAssignedUsers(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  
                                  final assignedUsers = snapshot.data ?? [];
                                  return Column(
                                    children: assignedUsers.map((user) => _buildUserTileWithConflict(user)).toList(),
                                  );
                                },
                              );
                            },
                          ),

                        const SizedBox(height: 24),
                        Divider(thickness: 1, color: Colors.grey),
                        const SizedBox(height: 12),
                        // Available users section
                        Text(
                          'Available Users (Matching Roles)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...availableUsers.where((user) => !assignedUserIds.contains(user.userId)).map((user) => _buildUserTileWithConflict(user)),

                        // Divider and secondary section for non-matching users
                        const SizedBox(height: 24),
                        Divider(thickness: 1, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'Other Users (No Matching Role)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            return FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .where('organizationId', isEqualTo: widget.organizationId)
                                  .get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                final allUsers = snapshot.data!.docs.map((doc) => ExtendedUserData.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
                                final matchingUserIds = availableUsers.map((u) => u.userId).toSet();
                                final alreadyAssigned = assignedUserIds;
                                final nonMatchingUsers = allUsers.where((user) {
                                  // Exclude users already shown or already assigned
                                  if (matchingUserIds.contains(user.userId)) return false;
                                  if (alreadyAssigned.contains(user.userId)) return false;
                                  // Location access check
                                  bool hasLocationAccess = false;
                                  if (user.userRole == 2) {
                                    hasLocationAccess = true;
                                  } else if (user.userRole == 1 && user.locationIds != null) {
                                    hasLocationAccess = user.locationIds!.contains(widget.locationId);
                                  } else if (user.userRole == 0 && user.locationId != null) {
                                    hasLocationAccess = user.locationId == widget.locationId;
                                  }
                                  return hasLocationAccess;
                                }).toList();
                                if (nonMatchingUsers.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    child: const Text(
                                      'No other users available',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  );
                                }
                                return Column(
                                  children: nonMatchingUsers.map((user) => _buildUserTileWithConflict(user)).toList(),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 100), // Space for button
                      ],
                    ),
                  ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Schedule',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleRequirement(String roleId, int count) {
    final roleName = roleNames[roleId] ?? 'Unknown Role';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Required: $count',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: count > 1 ? () => _updateRequiredCount(roleId, count - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 20,
                tooltip: 'Decrease count',
              ),
              SizedBox(
                width: 40,
                child: Text(
                  count.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () => _updateRequiredCount(roleId, count + 1),
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 20,
                tooltip: 'Increase count',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeRole(roleId),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                iconSize: 20,
                tooltip: 'Remove role',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserTileWithConflict(ExtendedUserData user) {
    final isAssigned = assignedUserIds.contains(user.userId);
    final userRolesText = user.jobTypes.join(', ');

    // Only check for conflicts if we have a valid scheduleId
    if (widget.scheduleId.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            child: Text(
              user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
            ),
          ),
          title: Text(user.fullName),
          subtitle: Text(userRolesText),
          trailing: Checkbox(
            value: isAssigned,
            onChanged: (_) => _toggleUserAssignment(user.userId),
          ),
          onTap: () => _toggleUserAssignment(user.userId),
          tileColor: isAssigned ? Colors.blue.withOpacity(0.1) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    // Conflict indicator: check if user is already assigned to another shift that day
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('locations')
          .doc(widget.locationId)
          .collection('schedules')
          .doc(widget.scheduleId)
          .collection('entries')
          .where('assignedUserIds', arrayContains: user.userId)
          .get(),
      builder: (context, snapshot) {
        bool isDoubleBooked = false;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          // If the user is assigned to any other entry for this schedule (day)
          for (final doc in snapshot.data!.docs) {
            final entry = ScheduleEntryData.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            // Exclude current shift
            if (entry.shiftId != widget.shiftId) {
              isDoubleBooked = true;
              break;
            }
          }
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
              ),
            ),
            title: Row(
              children: [
                Text(user.fullName),
                if (isDoubleBooked)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Tooltip(
                      message: 'Already assigned to another shift this day',
                      child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    ),
                  ),
              ],
            ),
            subtitle: Text(userRolesText),
            trailing: Checkbox(
              value: isAssigned,
              onChanged: (_) => _toggleUserAssignment(user.userId),
            ),
            onTap: () => _toggleUserAssignment(user.userId),
            tileColor: isAssigned ? Colors.blue.withOpacity(0.1) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }

  void _removeRole(String roleId) {
    setState(() {
      requiredRoles.remove(roleId);
    });
    // Reload users to reflect new role requirements
    _loadAvailableUsers();
  }
}
