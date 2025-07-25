import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/main.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Placeholder dialog for managing job types.
class JobTypeManagementDialog extends StatelessWidget {
  final VoidCallback onJobTypesUpdated;
  const JobTypeManagementDialog({super.key, required this.onJobTypesUpdated});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Job Types'),
      content: const Text('Job type management UI not implemented.'),
      actions: [
        TextButton(
          onPressed: () {
            onJobTypesUpdated();
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class UserManagementBottomSheet extends HookConsumerWidget {
  final Map<String, dynamic>? userData;
  final String? userId;

  const UserManagementBottomSheet({
    super.key,
    this.userData,
    this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final firstNameController = useTextEditingController(
      text: userData?['firstName'] ?? '',
    );
    final lastNameController = useTextEditingController(
      text: userData?['lastName'] ?? '',
    );
    final emailController = useTextEditingController(
      text: userData?['emailAddress'] ?? userData?['userEmail'] ?? userData?['email'] ?? '',
    );

    // Selected user role
    final selectedAccessLevel = useState<int>(userData?['userRole'] as int? ?? 0);

    // Available roles
    final availableRoles = useState<List<String>>([]);
    final selectedRoles = useState<Set<String>>(
      Set<String>.from(userData?['jobType']?.cast<String>() ?? []),
    );

    // Available locations
    final availableLocations = useState<List<Map<String, dynamic>>>([]);
    // For managers (role 1), allow multiple locations
    final selectedLocationIds = useState<Set<String>>(Set<String>.from(
      userData?['locationIds']?.cast<String>() ?? (userData?['locationId'] != null ? [userData?['locationId']] : []),
    ));
    // For general users (role 0), single location
    final selectedLocationId = useState<String?>(userData?['locationId']);

    final isLoading = useState(false);
    final isEditMode = userData != null;

    // Load available roles from Firestore
    useEffect(() {
      _loadRolesAndLocations(availableRoles, availableLocations);
      return null;
    }, []);
    
    // Auto-assign single location when only one exists
    // Auto-assign single location when only one exists; re-run when locations or role change
    useEffect(() {
      if (availableLocations.value.length == 1) {
        final singleLoc = availableLocations.value.first['id'] as String;
        // For general user
        if (selectedAccessLevel.value == 0) {
          selectedLocationId.value = singleLoc;
        }
        // For manager ensure at least that location
        if (selectedAccessLevel.value == 1) {
          selectedLocationIds.value = {singleLoc};
        }
      }
      return null;
    }, [availableLocations.value, selectedAccessLevel.value]);

    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                      isEditMode ? 'Edit User' : 'Add New User',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
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

                // User Role Dropdown (0=General,1=Manager,2=Admin)
                DropdownButtonFormField<int>(
                  value: selectedAccessLevel.value,
                  decoration: const InputDecoration(
                    labelText: 'User Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.security),
                  ),
                  items: List.generate(3, (i) => i).map((level) {
                    final labels = ['General User','Manager','Admin'];
                    return DropdownMenuItem<int>(
                      value: level,
                      child: Text(labels[level]),
                    );
                  }).toList(),
                  onChanged: (value) => selectedAccessLevel.value = value ?? 0,
                  onSaved: (value) {},
                ),
                const SizedBox(height: 20),

                // Job Type and Location selection
                // Job Type multi-select (show for General Users only)
                if (selectedAccessLevel.value == 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Job Types (Managers/Admins can work shifts)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                      children: availableRoles.value.map((type) {
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
                  // For managers (role 1), allow multiple locations
                  if (selectedAccessLevel.value == 1) ...[
                    const SizedBox(height: 16),
                    Text('Locations (Select one or more)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: availableLocations.value.map((loc) {
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
                        child: Text('Please select at least one location', style: TextStyle(color: theme.colorScheme.error)),
                      ),
                  ] else if (selectedAccessLevel.value == 0) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedLocationId.value,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items: availableLocations.value.map((loc) {
                        return DropdownMenuItem(
                          value: loc['id'] as String,
                          child: Text(loc['name'] ?? 'Unnamed Location'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        selectedLocationId.value = val;
                      },
                      validator: (val) {
                        if (selectedAccessLevel.value == 0 && (val == null || val.isEmpty)) {
                          return 'Please select a location';
                        }
                        return null;
                      },
                    ),
                  ],
                ] else if (availableLocations.value.isNotEmpty) ...[
                  // Auto-assign single location silently
                  // selectedLocationId and selectedLocationIds are already initialized in hook
                ],

                const SizedBox(height: 20),

                // Additional options for existing users
                if (isEditMode) ...[
                  Row(
                    children: [
                      // Resend Invite button removed in new flow
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLoading.value 
                            ? null 
                            : () => _resetPassword(context, emailController.text, isLoading),
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Reset Password'),
                        ),
                      ),
                    ],
                  ),
                  
                  // Debug test email option
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: isLoading.value
                        ? null
                        : () => _testEmailDelivery(context, emailController.text),
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Test Email Delivery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                      ),
                    ),
                  ],
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
                        onPressed: isLoading.value
                          ? null
                          : () async {
                              try {
                                // Determine final locations, auto-assign if single option
                                String? locId = selectedLocationId.value;
                                Set<String>? locIds = selectedLocationIds.value;
                                if (selectedAccessLevel.value == 0 && (locId == null || locId.isEmpty) && availableLocations.value.length == 1) {
                                  locId = availableLocations.value.first['id'] as String;
                                }
                                if (selectedAccessLevel.value == 1 && (locIds.isEmpty) && availableLocations.value.length == 1) {
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
                                debugPrint('createUser failed [${e.code}]: ${e.message}');
                                _showSnackBar(context, 'Cloud Function Error [${e.code}]: ${e.message}', isError: true);
                              } catch (e, st) {
                                debugPrint('Unexpected error: $e\n$st');
                                _showSnackBar(context, 'Unexpected error: ${e.toString()}', isError: true);
                              }
                            },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: theme.primaryColor,
                           padding: const EdgeInsets.symmetric(vertical: 16),
                         ),
                         child: isLoading.value
                           ? const SizedBox(
                               height: 20,
                               width: 20,
                               child: CircularProgressIndicator(
                                 strokeWidth: 2,
                                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                               ),
                            )
                           : Text(
                              isEditMode ? 'Update User' : 'Create User & Send Invite',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
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

  Future<void> _loadRolesAndLocations(
    ValueNotifier<List<String>> availableRoles,
    ValueNotifier<List<Map<String, dynamic>>> availableLocations
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
        final currentUserDoc = await FirestoreEnforcer.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        organizationId = currentUserDoc.data()?['organizationId'];
      }

      if (organizationId == null || organizationId.isEmpty) {
        // Fallback to default job types if no organization
        availableRoles.value = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
        return;
      }

      // Load job types from the organization's jobTypes subcollection
      final jobTypesSnapshot = await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('jobTypes')
          .orderBy('name')
          .get();
      
      final jobTypes = jobTypesSnapshot.docs
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
      print('Error loading job types: $e');
      // Fallback to default job types
      availableRoles.value = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
    }
  }

  Future<void> _createDefaultJobTypes(String organizationId) async {
    final defaultJobTypes = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
    final batch = FirestoreEnforcer.instance.batch();
    
    for (final jobType in defaultJobTypes) {
      final docRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('jobTypes')
          .doc();
      
      batch.set(docRef, {
        'name': jobType,
        'createdAt': FieldValue.serverTimestamp(),
        'organizationId': organizationId,
      });
    }
    
    await batch.commit();
  }

  Future<void> _loadAvailableLocations(ValueNotifier<List<Map<String, dynamic>>> availableLocations) async {
    try {
      // Get current user's organization ID
      final currentUser = FirebaseAuth.instance.currentUser;
      String? organizationId;
      
      if (currentUser != null) {
        final currentUserDoc = await FirestoreEnforcer.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        organizationId = currentUserDoc.data()?['organizationId'];
      }

      if (organizationId == null || organizationId.isEmpty) {
        availableLocations.value = [];
        return;
      }

      // Load locations from the organization's locations subcollection
      final locationsSnapshot = await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .get();
          
      final locations = locationsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['locationName'] ?? 'Unnamed Location',
        };
      }).toList();
      availableLocations.value = locations;
    } catch (e) {
      // print('Error loading locations: $e');
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
    // Additional validation for location
    if (accessLevel == 1 && (locationIds == null || locationIds.isEmpty)) {
      _showSnackBar(context, 'A manager must be assigned to at least one location.', isError: true);
      return;
    }
    if (accessLevel == 0 && (locationId == null || locationId.isEmpty)) {
      _showSnackBar(context, 'A general user must be assigned to a location.', isError: true);
      return;
    }

    isLoading.value = true;
    try {
      final organizationId = await _getOrganizationId();
      if (organizationId == null || organizationId.isEmpty) {
        _showSnackBar(context, 'Organization ID is missing. Please check your admin account.', isError: true);
        isLoading.value = false;
        return;
      }

      final userEmail = emailController.text.trim().toLowerCase();
      final tempPw = const Uuid().v4().substring(0, 8);
      final orgName = await _getOrganizationName();
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final templateId = 'd-575968e4e0c449f59ca89c1decdc8abc'; // <-- Updated to correct SendGrid template ID

      // Generate secure onboarding token
      final inviteToken = const Uuid().v4();
      final inviteUrl = 'https://plan-with-hands.web.app/welcome?email=$userEmail&organizationId=$organizationId&inviteId=$inviteToken';

      // Store invite in Firestore
      await FirestoreEnforcer.instance.collection('invites').doc(inviteToken).set({
        'email': userEmail,
        'organizationId': organizationId,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(days: 7)),
        'used': false,
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'userRole': accessLevel,
        'jobType': roles.toList(),
        'locationId': locationId,
        'locationIds': locationIds?.toList(),
        'orgName': orgName,
        'adminEmail': adminEmail,
      });

      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final createUser = functions.httpsCallable('createUser');
      
      debugPrint('Calling createUser with payload: ${{
        'email': userEmail,
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'userRole': accessLevel,
        'jobType': roles.toList(),
        'organizationId': organizationId,
        'locationId': locationId,
        'locationIds': locationIds?.toList(),
        'orgName': orgName,
        'adminEmail': adminEmail,
        'inviteUrl': inviteUrl,
        'templateId': templateId,
      }}');
      
      final result = await createUser.call({
        'email': userEmail,
        'password': tempPw,
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'userRole': accessLevel,
        'jobType': roles.toList(),
        'organizationId': organizationId,
        'locationId': locationId,
        'locationIds': locationIds?.toList(),
        'orgName': orgName,
        'adminEmail': adminEmail,
        'inviteUrl': inviteUrl,
        'templateId': templateId,
      });

      debugPrint('createUser result: ${result.data}');

      if (result.data != null && result.data['success'] == true) {
        _showSnackBar(context, 'User created. A welcome email has been sent to $userEmail');
        Navigator.pop(context, true);
      } else {
        _showSnackBar(context, 'User creation failed. Please try again.', isError: true);
      }
    } catch (e, s) {
      final crashlyticsEnabled = ref.read(crashlyticsEnabledProvider);
      if (crashlyticsEnabled) {
        try {
          FirebaseCrashlytics.instance.recordError(e, s);
        } catch (crashlyticsError) {
          debugPrint('Failed to record error to Crashlytics: $crashlyticsError');
        }
      } else {
        debugPrint('Crashlytics is not enabled, printing error to console: $e');
        debugPrint(s.toString());
      }
      String errorMsg = e is FirebaseFunctionsException && e.code == 'already-exists'
        ? 'A user with this email already exists.'
        : 'An error occurred: ${e.toString()}';
      _showSnackBar(context, errorMsg, isError: true);

      // Show error in a dialog for easier debugging
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error Creating User'),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      isLoading.value = false;
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
      final currentUserDoc = await FirestoreEnforcer.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
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
        
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email,
          actionCodeSettings: actionCodeSettings
        );
      } catch (settingsError) {
        debugPrint('Failed to send with action code settings: $settingsError');
        // Fallback to simpler reset email
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }
      
      debugPrint('Successfully sent password reset email to $email');
    } catch (e, s) {
      debugPrint('Error sending password reset: $e');
      // Defensively check if Crashlytics is enabled before recording.
      try {
        if (FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled) {
          FirebaseCrashlytics.instance.recordError(e, s);
        } 
      } catch (crashlyticsError) {
        debugPrint('Crashlytics error: $crashlyticsError');
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
      builder: (context) => JobTypeManagementDialog(
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
        final currentUserDoc = await FirestoreEnforcer.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        organizationId = currentUserDoc.data()?['organizationId'];
      }

      if (organizationId == null || organizationId.isEmpty) {
        // Fallback to default job types if no organization
        availableRoles.value = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
        return;
      }

      // Load job types from the organization's jobTypes subcollection
      final jobTypesSnapshot = await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('jobTypes')
          .orderBy('name')
          .get();
      
      final jobTypes = jobTypesSnapshot.docs
          .map((doc) => doc.data()['name'] as String?)
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toList();
      
      availableRoles.value = jobTypes.isEmpty ? 
          ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'] : 
          jobTypes;
    } catch (e) {
      print('Error reloading job types: $e');
      // Fallback to default job types
      availableRoles.value = ['Bartender', 'Server', 'Kitchen Staff', 'Dishwasher', 'Host/Hostess', 'Manager'];
    }
  }

  // All cloud function HTTP helpers removed for the new flow.

  Future<void> _testEmailDelivery(BuildContext context, String email) async {
    try {
      // Show testing dialog
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Testing email delivery...'))
        );
      }

      // Try Firebase Auth default method
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test email sent via Firebase Auth. Check your inbox and spam folder.'),
              duration: Duration(seconds: 8),
            )
          );
        }
        
        debugPrint('Test email sent via Firebase Auth to: $email');
        return;
      } catch (authError) {
        debugPrint('Firebase Auth test email failed: $authError');
        
      // Cloud function test email removed in new flow. Only Firebase Auth test email is supported.
      }
    } catch (e) {
      debugPrint('Test email error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email test failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }
