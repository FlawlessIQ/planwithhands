import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';
import 'package:hands_app/core/providers/crashlytics_provider.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/firestore_ttl_helper.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:hands_app/core/logging/logger.dart';

/// Dialog for managing job types with full CRUD functionality.
class JobTypeManagementDialog extends StatefulWidget {
  final VoidCallback onJobTypesUpdated;
  const JobTypeManagementDialog({super.key, required this.onJobTypesUpdated});

  @override
  State<JobTypeManagementDialog> createState() => _JobTypeManagementDialogState();
}

class _JobTypeManagementDialogState extends State<JobTypeManagementDialog> {
  final TextEditingController _newJobTypeController = TextEditingController();
  final TextEditingController _editJobTypeController = TextEditingController();
  List<Map<String, dynamic>> _jobTypes = [];
  bool _isLoading = true;
  String? _organizationId;

  @override
  void initState() {
    super.initState();
    _loadJobTypes();
  }

  @override
  void dispose() {
    _newJobTypeController.dispose();
    _editJobTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadJobTypes() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final currentUserDoc = await FirestoreEnforcer.instance.collection('users').doc(currentUser.uid).get();
        _organizationId = currentUserDoc.data()?['organizationId'];
      }

      if (_organizationId == null || _organizationId!.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final jobTypesSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(_organizationId!)
              .collection('jobTypes')
              .orderBy('name')
              .get();

      final jobTypes =
          jobTypesSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] as String,
              'createdAt': data['createdAt'],
              'organizationId': data['organizationId'],
            };
          }).toList();

      setState(() {
        _jobTypes = jobTypes;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Error loading job types: $e', e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addJobType() async {
    final name = _newJobTypeController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Please enter a job type name', isError: true);
      return;
    }

    // Check for duplicates
    if (_jobTypes.any((jt) => jt['name'].toLowerCase() == name.toLowerCase())) {
      _showSnackBar('This job type already exists', isError: true);
      return;
    }

    try {
      await FirestoreEnforcer.instance.collection('organizations').doc(_organizationId!).collection('jobTypes').add({
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'organizationId': _organizationId!,
      });

      _newJobTypeController.clear();
      _showSnackBar('Job type added successfully');
      await _loadJobTypes();
    } catch (e) {
      logger.e('Error adding job type: $e', e);
      _showSnackBar('Failed to add job type', isError: true);
    }
  }

  Future<void> _editJobType(String jobTypeId, String currentName) async {
    _editJobTypeController.text = currentName;

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Job Type'),
            content: TextFormField(
              controller: _editJobTypeController,
              decoration: const InputDecoration(labelText: 'Job Type Name', border: OutlineInputBorder()),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final newName = _editJobTypeController.text.trim();
                  if (newName.isNotEmpty) {
                    Navigator.pop(context, newName);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result != null && result != currentName) {
      // Check for duplicates
      if (_jobTypes.any((jt) => jt['id'] != jobTypeId && jt['name'].toLowerCase() == result.toLowerCase())) {
        _showSnackBar('This job type already exists', isError: true);
        return;
      }

      try {
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(_organizationId!)
            .collection('jobTypes')
            .doc(jobTypeId)
            .update({'name': result, 'updatedAt': FieldValue.serverTimestamp()});

        _showSnackBar('Job type updated successfully');
        await _loadJobTypes();
      } catch (e) {
        logger.e('Error updating job type: $e', e);
        _showSnackBar('Failed to update job type', isError: true);
      }
    }
  }

  Future<void> _deleteJobType(String jobTypeId, String jobTypeName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Job Type'),
            content: Text(
              'Are you sure you want to delete "$jobTypeName"?\n\nThis action cannot be undone and may affect existing staff assigned to this role.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(_organizationId!)
            .collection('jobTypes')
            .doc(jobTypeId)
            .delete();

        _showSnackBar('Job type deleted successfully');
        await _loadJobTypes();
      } catch (e) {
        logger.e('Error deleting job type: $e', e);
        _showSnackBar('Failed to delete job type', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Manage Job Types', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    widget.onJobTypesUpdated();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Add new job type section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add New Job Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _newJobTypeController,
                            decoration: const InputDecoration(
                              labelText: 'Job Type Name',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., Sous Chef, Barista, etc.',
                            ),
                            onFieldSubmitted: (_) => _addJobType(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _addJobType,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Existing job types list
            const Text('Existing Job Types', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            // Job types list
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _jobTypes.isEmpty
                      ? const Center(
                        child: Text(
                          'No job types found.\nAdd your first job type above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _jobTypes.length,
                        itemBuilder: (context, index) {
                          final jobType = _jobTypes[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.work_outline),
                              title: Text(jobType['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Edit',
                                    onPressed: () => _editJobType(jobType['id'], jobType['name']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteJobType(jobType['id'], jobType['name']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),

            // Footer buttons
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    widget.onJobTypesUpdated();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UserManagementBottomSheet extends HookConsumerWidget {
  final Map<String, dynamic>? userData;
  final String? userId;

  const UserManagementBottomSheet({super.key, this.userData, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final firstNameController = useTextEditingController(text: userData?['firstName'] ?? '');
    final lastNameController = useTextEditingController(text: userData?['lastName'] ?? '');
    final emailController = useTextEditingController(
      text: userData?['emailAddress'] ?? userData?['userEmail'] ?? userData?['email'] ?? '',
    );

    // Selected user role
    final selectedAccessLevel = useState<int>(userData?['userRole'] as int? ?? 0);

    // Available roles
    final availableRoles = useState<List<String>>([]);

    // Extract job types using canonical helper
    final selectedRoles = useState<Set<String>>(
      Set<String>.from(coerceToJobTypes(userData?['jobTypes'] ?? userData?['jobType'])),
    );

    // Available locations
    final availableLocations = useState<List<Map<String, dynamic>>>([]);

    // Extract location data safely
    String? extractLocationId(dynamic locationData) {
      if (locationData == null) return null;
      if (locationData is String) return locationData;
      if (locationData is Map) {
        logger.w('Warning: Location data is a Map: $locationData');
        return locationData['id'] as String?;
      }
      logger.w('Warning: Unexpected location data type: ${locationData.runtimeType}, value: $locationData');
      return null;
    }

    // For managers (role 1), allow multiple locations
    Set<String> extractLocationIds(dynamic locationIdsData, dynamic fallbackLocationId) {
      Set<String> result = <String>{};

      // Try to extract from locationIds array first
      if (locationIdsData is List) {
        result.addAll(locationIdsData.whereType<String>());
      }

      // If no locationIds but we have a single locationId, use that
      if (result.isEmpty) {
        final singleLocationId = extractLocationId(fallbackLocationId);
        if (singleLocationId != null) {
          result.add(singleLocationId);
        }
      }

      return result;
    }

    // Initialize selectedLocationIds with existing data
    Set<String> initialLocationIds = extractLocationIds(userData?['locationIds'], userData?['locationId']);

    // For employees (role 0), if no locationIds but we have a single locationId, add it
    if (initialLocationIds.isEmpty) {
      final singleLocationId =
          extractLocationId(userData?['locationId']) ?? extractLocationId(userData?['primaryLocationId']);
      if (singleLocationId != null) {
        initialLocationIds.add(singleLocationId);
      }
    }

    final selectedLocationIds = useState<Set<String>>(initialLocationIds);

    final isLoading = useState(false);
    final isEditMode = userData != null;

    // Load available roles from Firestore
    useEffect(() {
      _loadRolesAndLocations(availableRoles, availableLocations);
      return null;
    }, []);

    // Auto-assign locations based on user role
    useEffect(() {
      if (availableLocations.value.isEmpty) return null;

      if (selectedAccessLevel.value == 1 || selectedAccessLevel.value == 2) {
        // Managers (role 1) and Admins (role 2) should be assigned to ALL locations
        final allLocationIds = availableLocations.value.map((location) => location['id'] as String).toSet();
        selectedLocationIds.value = allLocationIds;
      } else if (availableLocations.value.length == 1) {
        // Employees (role 0) with only one location available - auto-assign
        final singleLoc = availableLocations.value.first['id'] as String;
        selectedLocationIds.value = {singleLoc};
      }
      return null;
    }, [availableLocations.value, selectedAccessLevel.value]);

    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditMode ? 'Edit Staff' : 'Add New Staff',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 24),

                // First Name
                TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Last Name
                TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter last name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isEditMode, // Don't allow email changes in edit mode
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter email address';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Staff Role Dropdown (0=Employee,1=Manager,2=Admin)
                DropdownButtonFormField<int>(
                  value: selectedAccessLevel.value,
                  decoration: const InputDecoration(
                    labelText: 'Staff Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.security),
                  ),
                  items:
                      List.generate(3, (i) => i).map((level) {
                        final labels = ['Employee', 'Manager', 'Admin'];
                        return DropdownMenuItem<int>(value: level, child: Text(labels[level]));
                      }).toList(),
                  onChanged: (value) => selectedAccessLevel.value = value ?? 0,
                  onSaved: (value) {},
                ),
                const SizedBox(height: 12),

                // Role Description Panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: theme.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Role Permissions',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getRoleDescription(selectedAccessLevel.value),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Job Type and Location selection
                // Job Type multi-select (show for Employees only)
                if (selectedAccessLevel.value == 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Job Types', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: () => _showJobTypeManagement(context, availableRoles),
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Manage', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Staff will only see shifts which align with these job types',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          availableRoles.value.map((type) {
                            final isSelected = selectedRoles.value.contains(type);
                            return FilterChip(
                              label: Text(type),
                              selected: isSelected,
                              onSelected: (sel) {
                                final set = Set<String>.from(selectedRoles.value);
                                sel ? set.add(type) : set.remove(type);
                                selectedRoles.value = set;
                              },
                              selectedColor: theme.primaryColor.withAlpha(50),
                            );
                          }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Location selection (show only if more than one location available)
                if (availableLocations.value.length > 1) ...[
                  // For admins (role 2) and managers (role 1), show auto-assignment message
                  if (selectedAccessLevel.value == 1 || selectedAccessLevel.value == 2) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: theme.primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Location Access',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedAccessLevel.value == 2
                                ? 'Admins are automatically assigned to all locations and have full access across the organization.'
                                : 'Managers are automatically assigned to all locations to oversee operations across the organization.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Assigned locations:',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          ...availableLocations.value.map(
                            (loc) => Padding(
                              padding: const EdgeInsets.only(left: 16, top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: theme.primaryColor, size: 16),
                                  const SizedBox(width: 8),
                                  Text(loc['name'] ?? 'Unnamed Location'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                  // For employees (role 0), allow multiple location selection
                  else if (selectedAccessLevel.value == 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Locations (Select one or more)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children:
                            availableLocations.value.map((loc) {
                              final isSelected = selectedLocationIds.value.contains(loc['id']);
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(loc['name'] ?? 'Unnamed Location'),
                                onChanged: (checked) {
                                  final set = Set<String>.from(selectedLocationIds.value);
                                  if (checked == true) {
                                    set.add(loc['id']);
                                  } else {
                                    set.remove(loc['id']);
                                  }
                                  selectedLocationIds.value = set;
                                },
                              );
                            }).toList(),
                      ),
                    ),
                    if (selectedLocationIds.value.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Please select at least one location',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                ] else if (availableLocations.value.isNotEmpty) ...[
                  // Auto-assign single location silently
                  // selectedLocationId and selectedLocationIds are already initialized in hook
                ],

                const SizedBox(height: 20),

                // Additional options for existing staff
                if (isEditMode) ...[
                  Row(
                    children: [
                      // Resend Invite button removed in new flow
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              isLoading.value ? null : () => _resetPassword(context, emailController.text, isLoading),
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Reset Password'),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading.value ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed:
                            isLoading.value
                                ? null
                                : () async {
                                  try {
                                    // Determine final locations, auto-assign if single option
                                    String? locId; // No longer used for employees
                                    Set<String>? locIds = selectedLocationIds.value;

                                    // For employees (role 0), use selectedLocationIds
                                    if (selectedAccessLevel.value == 0 &&
                                        locIds.isEmpty &&
                                        availableLocations.value.length == 1) {
                                      locIds = {availableLocations.value.first['id'] as String};
                                    }
                                    // For managers (role 1), also use selectedLocationIds
                                    if (selectedAccessLevel.value == 1 &&
                                        locIds.isEmpty &&
                                        availableLocations.value.length == 1) {
                                      locIds = {availableLocations.value.first['id'] as String};
                                    }
                                    await _saveUser(
                                      context,
                                      formKey,
                                      firstNameController,
                                      lastNameController,
                                      emailController,
                                      selectedAccessLevel.value,
                                      selectedRoles.value,
                                      isEditMode,
                                      userId,
                                      isLoading,
                                      locId,
                                      locIds,
                                      ref,
                                    );
                                  } on FirebaseFunctionsException catch (e) {
                                    logger.e('createUser failed [${e.code}]: ${e.message}', e);
                                    if (context.mounted) {
                                      _showSnackBar(
                                        context,
                                        'Cloud Function Error [${e.code}]: ${e.message}',
                                        isError: true,
                                      );
                                    }
                                  } catch (e, st) {
                                    logger.e('Unexpected error: $e\n$st', e);
                                    if (context.mounted) {
                                      _showSnackBar(context, 'Unexpected error: ${e.toString()}', isError: true);
                                    }
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child:
                            isLoading.value
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                : Text(
                                  isEditMode ? 'Update Staff' : 'Create Staff & Send Invite',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleDescription(int userRole) {
    switch (userRole) {
      case 2:
        return 'Full access — can manage subscriptions, add/edit/delete users, locations, shifts, and checklists, and send messages.';
      case 1:
        return 'Can view all performance metrics and data, but cannot manage subscriptions, shifts, or send messages.';
      case 0:
      default:
        return 'Can complete tasks, view training materials and documents, and read messages sent by admins.';
    }
  }

  Future<void> _loadRolesAndLocations(
    ValueNotifier<List<String>> availableRoles,
    ValueNotifier<List<Map<String, dynamic>>> availableLocations,
  ) async {
    await _loadAvailableRoles(availableRoles);
    await _loadAvailableLocations(availableLocations);
  }

  Future<void> _loadAvailableRoles(ValueNotifier<List<String>> availableRoles) async {
    try {
      // Get current user's organization ID
      final currentUser = FirebaseAuth.instance.currentUser;
      String? organizationId;

      if (currentUser != null) {
        final currentUserDoc = await FirestoreEnforcer.instance.collection('users').doc(currentUser.uid).get();
        organizationId = currentUserDoc.data()?['organizationId'];
      }

      if (organizationId == null || organizationId.isEmpty) {
        // Fallback to default job types if no organization
        availableRoles.value = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
        return;
      }

      // Load job types from the organization's jobTypes subcollection
      final jobTypesSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('jobTypes')
              .orderBy('name')
              .get();

      final jobTypes =
          jobTypesSnapshot.docs
              .map((doc) => doc.data()['name'] as String?)
              .where((name) => name != null && name.isNotEmpty)
              .cast<String>()
              .toList();

      // If no custom job types exist, create default ones
      if (jobTypes.isEmpty) {
        await _createDefaultJobTypes(organizationId);
        // Reload after creating defaults
        final defaultJobTypes = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
        availableRoles.value = defaultJobTypes;
      } else {
        availableRoles.value = jobTypes;
      }
    } catch (e) {
      logger.e('Error loading job types: $e', e);
      // Fallback to default job types
      availableRoles.value = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
    }
  }

  Future<void> _createDefaultJobTypes(String organizationId) async {
    final defaultJobTypes = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
    final batch = FirestoreEnforcer.instance.batch();

    for (final jobType in defaultJobTypes) {
      final docRef =
          FirestoreEnforcer.instance.collection('organizations').doc(organizationId).collection('jobTypes').doc();

      batch.set(docRef, {'name': jobType, 'createdAt': FieldValue.serverTimestamp(), 'organizationId': organizationId});
    }

    await batch.commit();
  }

  Future<void> _loadAvailableLocations(ValueNotifier<List<Map<String, dynamic>>> availableLocations) async {
    try {
      // Get current user's organization ID
      final currentUser = FirebaseAuth.instance.currentUser;
      String? organizationId;

      if (currentUser != null) {
        final currentUserDoc = await FirestoreEnforcer.instance.collection('users').doc(currentUser.uid).get();
        organizationId = currentUserDoc.data()?['organizationId'];
      }

      if (organizationId == null || organizationId.isEmpty) {
        availableLocations.value = [];
        return;
      }

      // Load locations from the organization's locations subcollection
      final locationsSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();

      final locations =
          locationsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, 'name': data['locationName'] ?? 'Unnamed Location'};
          }).toList();
      availableLocations.value = locations;
    } catch (e) {
      logger.w('Error loading locations: $e', e);
      availableLocations.value = [];
    }
  }

  Future<void> _saveUser(
    BuildContext context,
    GlobalKey<FormState> formKey,
    TextEditingController firstNameController,
    TextEditingController lastNameController,
    TextEditingController emailController,
    int accessLevel,
    Set<String> roles,
    bool isEditMode,
    String? userId,
    ValueNotifier<bool> isLoading,
    String? locationId, // for general user
    Set<String>? locationIds, // for manager
    WidgetRef ref, // Add ref parameter for provider access
  ) async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    // Enforce job type requirement only for employees (userRole 0)
    // Managers (userRole 1) and Admins (userRole 2) have access to all shifts
    if (accessLevel == 0 && roles.isEmpty) {
      _showSnackBar(context, 'Please select at least one job type for this employee.', isError: true);
      return;
    }
    // Only enforce location selection for employees (userRole 0)
    // Admins (userRole 2) and Managers (userRole 1) are automatically assigned to all locations
    if (accessLevel == 0 && (locationIds == null || locationIds.isEmpty)) {
      _showSnackBar(context, 'An employee must be assigned to at least one location.', isError: true);
      return;
    }

    isLoading.value = true;
    try {
      final organizationId = await _getOrganizationId();
      if (organizationId == null || organizationId.isEmpty) {
        if (context.mounted) {
          _showSnackBar(context, 'Organization ID is missing. Please check your admin account.', isError: true);
        }
        isLoading.value = false;
        return;
      }

      if (isEditMode && userId != null) {
        // Update existing user
        await _updateExistingUser(
          context,
          userId,
          firstNameController.text.trim(),
          lastNameController.text.trim(),
          accessLevel,
          roles,
          locationId,
          locationIds,
          organizationId,
        );
      } else {
        // Create new user
        await _createNewUser(
          context,
          firstNameController.text.trim(),
          lastNameController.text.trim(),
          emailController.text.trim().toLowerCase(),
          accessLevel,
          roles,
          locationId,
          locationIds,
          organizationId,
          ref,
        );
      }
    } catch (e, s) {
      final crashlyticsEnabled = ref.read(crashlyticsEnabledProvider);
      if (crashlyticsEnabled) {
        try {
          FirebaseCrashlytics.instance.recordError(e, s);
        } catch (crashlyticsError) {
          logger.w('Failed to record error to Crashlytics: $crashlyticsError');
        }
      } else {
        logger.w('Crashlytics is not enabled, printing error to console: $e');
        logger.d(s.toString());
      }
      String errorMsg =
          e is FirebaseFunctionsException && e.code == 'already-exists'
              ? 'A staff member with this email already exists.'
              : 'An error occurred: ${e.toString()}';
      if (context.mounted) _showSnackBar(context, errorMsg, isError: true);

      // Show error in a dialog for easier debugging
      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(isEditMode ? 'Error Updating Staff' : 'Error Creating Staff'),
                content: Text(errorMsg),
                actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
              ),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _updateExistingUser(
    BuildContext context,
    String userId,
    String firstName,
    String lastName,
    int accessLevel,
    Set<String> roles,
    String? locationId,
    Set<String>? locationIds,
    String organizationId,
  ) async {
    // Prepare update data
    Map<String, dynamic> updateData = {
      'firstName': firstName,
      'lastName': lastName,
      'userRole': accessLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Handle job types based on user role
    if (accessLevel == 0) {
      // Employee - requires job types
      updateData['jobTypes'] = roles.toList();
      updateData['jobType'] = (roles.isNotEmpty ? roles.toList().first : null);
    } else {
      // Manager (1) and Admin (2) - have access to all shifts, set to empty/null
      updateData['jobTypes'] = [];
      updateData['jobType'] = null;
    }

    // Handle location assignment based on user role
    if (accessLevel == 1 || accessLevel == 2) {
      // Managers (1) and Admins (2) - automatically assign to ALL locations
      try {
        final locationsSnapshot =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .get();

        if (locationsSnapshot.docs.isNotEmpty) {
          final allLocationIds = locationsSnapshot.docs.map((doc) => doc.id).toList();
          updateData['locationIds'] = allLocationIds;
          updateData['locationId'] = allLocationIds.first; // Set first location as primary
          updateData['assignedLocationRefs'] =
              allLocationIds
                  .map(
                    (id) => FirestoreEnforcer.instance
                        .collection('organizations')
                        .doc(organizationId)
                        .collection('locations')
                        .doc(id),
                  )
                  .toList();
        } else {
          // Fallback if no locations found
          updateData['locationIds'] = [];
          updateData['locationId'] = null;
          updateData['assignedLocationRefs'] = [];
        }
      } catch (e) {
        logger.w('Error fetching locations for auto-assignment: $e');
        // Fallback to provided locations
        updateData['locationIds'] = locationIds?.toList() ?? [];
        updateData['locationId'] = locationIds?.first;
        updateData['assignedLocationRefs'] =
            locationIds
                ?.map(
                  (id) => FirestoreEnforcer.instance
                      .collection('organizations')
                      .doc(organizationId)
                      .collection('locations')
                      .doc(id),
                )
                .toList() ??
            [];
      }
    } else if (accessLevel == 0) {
      // Employee - use selected locations
      updateData['locationIds'] = locationIds?.toList() ?? [];
      updateData['locationId'] = locationIds?.first;
      updateData['assignedLocationRefs'] =
          locationIds
              ?.map(
                (id) => FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(organizationId)
                    .collection('locations')
                    .doc(id),
              )
              .toList() ??
          [];
    }

    // Update user document in Firestore
    await FirestoreEnforcer.instance.collection('users').doc(userId).update(updateData);

    if (context.mounted) {
      _showSnackBar(context, 'Staff updated successfully');
      Navigator.pop(context, true);
    }
  }

  Future<void> _createNewUser(
    BuildContext context,
    String firstName,
    String lastName,
    String userEmail,
    int accessLevel,
    Set<String> roles,
    String? locationId,
    Set<String>? locationIds,
    String organizationId,
    WidgetRef ref,
  ) async {
    final tempPw = const Uuid().v4().substring(0, 8);
    final orgName = await _getOrganizationName();
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final templateId = 'd-575968e4e0c449f59ca89c1decdc8abc';

    // Generate secure onboarding token
    final inviteToken = const Uuid().v4();
    final inviteUrl =
        'https://plan-with-hands.web.app/welcome?email=$userEmail&orgId=$organizationId&inviteId=$inviteToken';

    logger.d('[USER_MANAGEMENT] Generated invite URL: $inviteUrl');

    // Store invite in Firestore using TTL helper
    Map<String, dynamic> inviteData = {
      'email': userEmail,
      'organizationId': organizationId,
      'createdAt': FieldValue.serverTimestamp(),
      'used': false,
      'firstName': firstName,
      'lastName': lastName,
      'userRole': accessLevel,
      'locationId': locationId,
      'locationIds': locationIds?.toList(),
      'orgName': orgName,
      'adminEmail': adminEmail,
    };

    // Also include assignedLocationRefs for compatibility
    if (locationIds != null && locationIds.isNotEmpty) {
      inviteData['assignedLocationRefs'] =
          locationIds
              .map(
                (id) => FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(organizationId)
                    .collection('locations')
                    .doc(id),
              )
              .toList();
    } else {
      inviteData['assignedLocationRefs'] = [];
    }

    // Handle job types based on user role
    if (accessLevel == 0) {
      // Employee - requires job types
      inviteData['jobTypes'] = roles.toList();
      inviteData['jobType'] = (roles.isNotEmpty ? roles.toList().first : null);
    } else {
      // Manager (1) and Admin (2) - have access to all shifts, set to empty/null
      inviteData['jobTypes'] = [];
      inviteData['jobType'] = null;
    }

    final inviteRef = FirestoreEnforcer.instance.collection('invites').doc(inviteToken);
    await FirestoreTTLHelper.setWithTTL(inviteRef, inviteData);

    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    final createUser = functions.httpsCallable('createUser');

    // Canonicalize locationIds for clearer logging
    final logLocIds = locationIds != null ? locationIds.toList() : (locationId != null ? [locationId] : <String>[]);

    // Prepare job types based on user role
    List<String> finalJobTypes = [];
    String? finalJobType;

    if (accessLevel == 0) {
      // Employee - use selected job types
      finalJobTypes = roles.toList();
      finalJobType = (roles.isNotEmpty ? roles.toList().first : null);
    } else {
      // Manager (1) and Admin (2) - have access to all shifts, set to empty/null
      finalJobTypes = [];
      finalJobType = null;
    }

    logger.d(
      'Calling createUser with payload: ${{'email': userEmail, 'firstName': firstName, 'lastName': lastName, 'userRole': accessLevel, 'jobTypes': finalJobTypes, 'organizationId': organizationId, 'locationId': logLocIds.isNotEmpty ? logLocIds.first : null, 'locationIds': logLocIds, 'assignedLocationRefs': locationIds?.map((id) => 'organizations/$organizationId/locations/$id').toList() ?? [], 'orgName': orgName, 'adminEmail': adminEmail, 'inviteUrl': inviteUrl, 'templateId': templateId}}',
    );

    final result = await createUser.call({
      'email': userEmail,
      'password': tempPw,
      'firstName': firstName,
      'lastName': lastName,
      'userRole': accessLevel,
      'jobTypes': finalJobTypes,
      'jobType': finalJobType,
      'organizationId': organizationId,
      'locationId': locationId,
      'locationIds': locationIds?.toList(),
      'assignedLocationRefs':
          locationIds != null ? locationIds.map((id) => 'organizations/$organizationId/locations/$id').toList() : [],
      'orgName': orgName,
      'adminEmail': adminEmail,
      'inviteUrl': inviteUrl,
      'templateId': templateId,
    });

    logger.d('createUser result: ${result.data}');

    if (result.data != null && result.data['success'] == true) {
      if (context.mounted) {
        _showSnackBar(context, 'Staff created. A welcome email has been sent to $userEmail');
        Navigator.pop(context, true);
      }
    } else {
      if (context.mounted) {
        _showSnackBar(context, 'Staff creation failed. Please try again.', isError: true);
      }
    }
  }
}

// Resend invite is no longer needed in the new flow. You may remove this button from the UI.

Future<void> _resetPassword(BuildContext context, String email, ValueNotifier<bool> isLoading) async {
  if (email.isEmpty) {
    _showSnackBar(context, 'Email address is missing.', isError: true);
    return;
  }
  isLoading.value = true;
  try {
    await _sendPasswordResetEmail(context, email);
    _showSnackBar(context, 'Password reset link sent to email.');
  } catch (e) {
    _showSnackBar(context, 'Failed to send password reset email: ${e.toString()}', isError: true);
  } finally {
    isLoading.value = false;
  }
}

Future<String?> _getOrganizationId() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final currentUserDoc = await FirestoreEnforcer.instance.collection('users').doc(currentUser.uid).get();
    return currentUserDoc.data()?['organizationId'];
  }
  return null;
}

Future<String> _getOrganizationName() async {
  final organizationId = await _getOrganizationId();
  if (organizationId != null) {
    final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(organizationId).get();
    return orgDoc.data()?['name'] ?? 'Your Organization';
  }
  return 'Your Organization';
}

// All invitation/magic-link/cloud function code removed for the new flow.
Future<void> _sendPasswordResetEmail(BuildContext context, String email) async {
  try {
    // Try to send with a continue URL for better UX
    try {
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://plan-with-hands.web.app/reset-password',
        handleCodeInApp: true,
        androidPackageName: 'com.handsapp.hospitality',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email, actionCodeSettings: actionCodeSettings);
    } catch (settingsError) {
      logger.w('Failed to send with action code settings: $settingsError');
      // Fallback to simpler reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    }

    logger.d('Successfully sent password reset email to $email');
  } catch (e, s) {
    logger.e('Error sending password reset: $e', e);
    // Defensively check if Crashlytics is enabled before recording.
    try {
      if (FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled) {
        FirebaseCrashlytics.instance.recordError(e, s);
      }
    } catch (crashlyticsError) {
      logger.w('Crashlytics error: $crashlyticsError');
    }
    rethrow;
  }
}

void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
  final snackBar = SnackBar(
    content: Text(message),
    backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

void _showJobTypeManagement(BuildContext context, ValueNotifier<List<String>> availableRoles) {
  showDialog(
    context: context,
    builder:
        (context) => JobTypeManagementDialog(
          // Pass a callback that will reload roles
          onJobTypesUpdated: () {
            // Using a local function to reload roles that doesn't rely on class methods
            _reloadRoles(availableRoles);
          },
        ),
  );
}

void _reloadRoles(ValueNotifier<List<String>> availableRoles) async {
  try {
    // Get current user's organization ID
    final currentUser = FirebaseAuth.instance.currentUser;
    String? organizationId;

    if (currentUser != null) {
      final currentUserDoc = await FirestoreEnforcer.instance.collection('users').doc(currentUser.uid).get();
      organizationId = currentUserDoc.data()?['organizationId'];
    }

    if (organizationId == null || organizationId.isEmpty) {
      // Fallback to default job types if no organization
      availableRoles.value = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
      return;
    }

    // Load job types from the organization's jobTypes subcollection
    final jobTypesSnapshot =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(organizationId)
            .collection('jobTypes')
            .orderBy('name')
            .get();

    final jobTypes =
        jobTypesSnapshot.docs
            .map((doc) => doc.data()['name'] as String?)
            .where((name) => name != null && name.isNotEmpty)
            .cast<String>()
            .toList();

    availableRoles.value =
        jobTypes.isEmpty ? ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'] : jobTypes;
  } catch (e) {
    logger.e('Error reloading job types: $e', e);
    // Fallback to default job types
    availableRoles.value = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
  }
}

// All cloud function HTTP helpers removed for the new flow.
