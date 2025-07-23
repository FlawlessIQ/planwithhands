import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/main.dart';

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
    final theme = Theme.of(context);
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
    final selectedAccessLevel = useState<int>(userData?['userRole'] ?? 0);
    // Available roles for the user
    final availableRoles = useState<List<String>>([]);
    // Job Type selection (minimal ActionChip style)
    final availableLocations = useState<List<Map<String, dynamic>>>([]);
    // Selected roles for the user
    final selectedRoles = useState<Set<String>>({});
    // Selected location IDs for manager role
    final selectedLocationIds = useState<Set<String>>({});
    // Selected location ID for general user
    final selectedLocationId = useState<String?>(null);
    // Loading state for async actions
    final isLoading = useState<bool>(false);
    final isEditMode = userData != null;

    // You may want to load roles and locations asynchronously, e.g.:
    useEffect(() {
      _loadRolesAndLocations(availableRoles, availableLocations);
      return null;
    }, []);

    return SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(),
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

            // Job Type selection (minimal ActionChip style)
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Roles', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...availableRoles.value.map((jobType) {
                        final isSelected = selectedRoles.value.contains(jobType);
                        return Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: ActionChip(
                            label: Text(jobType),
                            backgroundColor: isSelected ? theme.primaryColor.withAlpha(50) : Colors.grey[50],
                            side: BorderSide(color: Colors.grey[300]!),
                            onPressed: () {
                              final set = Set<String>.from(selectedRoles.value);
                              isSelected ? set.remove(jobType) : set.add(jobType);
                              selectedRoles.value = set;
                            },
                          ),
                        );
                      }),
                      ActionChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add, size: 16),
                            SizedBox(width: 4),
                            Text('Add New'),
                          ],
                        ),
                        backgroundColor: Colors.blue[50],
                        side: BorderSide(color: Colors.blue[300]!),
                        onPressed: () => _showJobTypeManagement(context, availableRoles),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Location selection
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
            ] 
            else if (selectedAccessLevel.value == 0) ...[
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
                      : () => _saveUser(
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
                          selectedLocationId.value, // for general user
                          selectedLocationIds.value, // for manager
                          ref, // Pass ref to access providers
                        ),
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
        final currentUserDoc = await FirebaseFirestore.instance
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
      final jobTypesSnapshot = await FirebaseFirestore.instance
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
    final batch = FirebaseFirestore.instance.batch();
    
    for (final jobType in defaultJobTypes) {
      final docRef = FirebaseFirestore.instance
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
        final currentUserDoc = await FirebaseFirestore.instance
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
      final locationsSnapshot = await FirebaseFirestore.instance
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
    debugPrint('DEBUG: _saveUser called');
    debugPrint('DEBUG: Form validation result: ${formKey.currentState?.validate()}');
    if (!formKey.currentState!.validate()) {
      debugPrint('DEBUG: Form not valid, aborting');
      return;
    }
    // Additional validation for location
    if (accessLevel == 1 && (locationIds == null || locationIds.isEmpty)) {
      debugPrint('DEBUG: Manager must be assigned to at least one location');
      _showSnackBar(context, 'A manager must be assigned to at least one location.', isError: true);
      return;
    }
    if (accessLevel == 0 && (locationId == null || locationId.isEmpty)) {
      debugPrint('DEBUG: General user must be assigned to a location');
      _showSnackBar(context, 'A general user must be assigned to a location.', isError: true);
      return;
    }

    isLoading.value = true;
    try {
      final organizationId = await _getOrganizationId();
      debugPrint('DEBUG: organizationId: $organizationId');
      if (organizationId == null || organizationId.isEmpty) {
        debugPrint('DEBUG: Organization ID missing');
        _showSnackBar(context, 'Organization ID is missing. Please check your admin account.', isError: true);
        isLoading.value = false;
        return;
      }

      final userEmail = emailController.text.trim().toLowerCase();
      final orgName = await _getOrganizationName();
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      debugPrint('DEBUG: userEmail: $userEmail');
      debugPrint('DEBUG: orgName: $orgName');
      debugPrint('DEBUG: adminEmail: $adminEmail');
      debugPrint('DEBUG: accessLevel: $accessLevel');
      debugPrint('DEBUG: roles: ${roles.toString()}');
      debugPrint('DEBUG: locationId: $locationId');
      debugPrint('DEBUG: locationIds: ${locationIds?.toList()}');

      // Use Firebase Callable Functions with region
      debugPrint('DEBUG: Preparing to call createUserAndSendInvite Cloud Function');
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final createUserAndSendInvite = functions.httpsCallable('createUserAndSendInvite');
      final payload = {
        'email': userEmail,
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'organizationId': organizationId,
        'userRole': accessLevel,
        'jobType': roles.isNotEmpty ? roles.first : '',
        'locationId': locationId,
        'locationIds': locationIds?.toList() ?? [],
        'orgName': orgName,
        'adminEmail': adminEmail,
        // You can add inviteUrl and templateId if needed
      };
      debugPrint('DEBUG: Payload for Cloud Function: ${payload.toString()}');
      try {
        final result = await createUserAndSendInvite.call(payload);
        debugPrint('DEBUG: Cloud Function result: ${result.data}');
        if (result.data != null && result.data['success'] == true) {
          _showSnackBar(context, 'User created. A welcome email has been sent to $userEmail');
          Navigator.pop(context, true);
        } else {
          debugPrint('DEBUG: Cloud Function returned failure');
          _showSnackBar(context, 'User creation failed. Please try again.', isError: true);
        }
      } catch (cfError, cfStack) {
        debugPrint('DEBUG: Cloud Function call threw error: $cfError');
        debugPrint('DEBUG: Cloud Function error stack: $cfStack');
        rethrow;
      }
    } catch (e, s) {
      debugPrint('DEBUG: Exception in _saveUser: $e');
      debugPrint('DEBUG: Stack trace: $s');
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
      debugPrint('DEBUG: _saveUser finished');
      isLoading.value = false;
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
      final currentUserDoc = await FirebaseFirestore.instance
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
      final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(organizationId).get();
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
          url: 'https://handstest-3c95b.web.app/reset-password',
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
        final currentUserDoc = await FirebaseFirestore.instance
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
      final jobTypesSnapshot = await FirebaseFirestore.instance
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
}

class JobTypeManagementDialog extends StatefulWidget {
  final VoidCallback onJobTypesUpdated;

  const JobTypeManagementDialog({
    super.key,
    required this.onJobTypesUpdated,
  });

  @override
  State<JobTypeManagementDialog> createState() => _JobTypeManagementDialogState();
}
class _JobTypeManagementDialogState extends State<JobTypeManagementDialog> {
  final TextEditingController _newJobTypeController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _loadJobTypes() async {
    try {
      // Get current user's organization ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        _organizationId = currentUserDoc.data()?['organizationId'];
      }

      if (_organizationId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load job types
      final jobTypesSnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationId!)
          .collection('jobTypes')
          .orderBy('name')
          .get();

      setState(() {
        _jobTypes = jobTypesSnapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc.data()['name'] as String,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading job types: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addJobType() async {
    final newJobType = _newJobTypeController.text.trim();
    if (newJobType.isEmpty || _organizationId == null) return;

    // Check if job type already exists
    if (_jobTypes.any((jt) => jt['name'].toLowerCase() == newJobType.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job type already exists')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationId!)
          .collection('jobTypes')
          .add({
        'name': newJobType,
        'createdAt': FieldValue.serverTimestamp(),
        'organizationId': _organizationId!,
      });

      _newJobTypeController.clear();
      await _loadJobTypes();
      widget.onJobTypesUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "$newJobType" job type')),
        );
      }
    } catch (e) {
      print('Error adding job type: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding job type: $e')),
        );
      }
    }
  }

  Future<void> _deleteJobType(String jobTypeId, String jobTypeName) async {
    if (_organizationId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Type'),
        content: Text('Are you sure you want to delete "$jobTypeName"?\n\nThis may affect users who have this job type assigned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(_organizationId!)
          .collection('jobTypes')
          .doc(jobTypeId)
          .delete();

      await _loadJobTypes();
      widget.onJobTypesUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "$jobTypeName" job type')),
        );
      }
    } catch (e) {
      print('Error deleting job type: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting job type: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Roles'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            // Add new role
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newJobTypeController,
                    decoration: const InputDecoration(
                      labelText: 'New Role',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addJobType(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addJobType,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // List of existing roles
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _jobTypes.isEmpty
                      ? const Center(
                          child: Text(
                            'No roles found.\nAdd some roles above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _jobTypes.length,
                          itemBuilder: (context, index) {
                            final jobType = _jobTypes[index];
                            return ListTile(
                              leading: const Icon(Icons.work),
                              title: Text(jobType['name']),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteJobType(
                                  jobType['id'],
                                  jobType['name'],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Helper to fetch organization name by ID
Future<String> _getOrgName(String orgId) async {
  try {
    final orgDoc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .get();
    final data = orgDoc.data();
    return data?['name'] as String? ?? 'Your Organization';
  } catch (e, stack) {
    // Log error to Crashlytics, with a defensive check
    if (FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled) {
      FirebaseCrashlytics.instance.recordError(e, stack);
    } else {
      print('Crashlytics not enabled, logging error to console: $e');
    }
    return 'Your Organization';
  }
}
