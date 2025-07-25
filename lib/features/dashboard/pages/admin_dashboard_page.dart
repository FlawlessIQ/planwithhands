import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/custom_code/widgets/UserManagementBottomSheet.dart';
import 'package:hands_app/ui/location_bottom_sheet.dart';
import 'package:hands_app/ui/UploadDocumentBottomSheet.dart';
import 'package:hands_app/ui/checklist_bottom_sheet.dart';
import 'package:hands_app/features/shifts/shift_template_bottom_sheet.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/debug/scheduling_test_data_seeder.dart';
import 'package:hands_app/debug/role_diagnostic.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int? userRole;
  String? organizationId;
  bool isLoading = true;

  // Location selection state
  String? _selectedLocationId;
  String? _selectedLocationName;
  List<Map<String, dynamic>> _availableLocations = [];
  bool _showLocationSelector = false;

  // Add refresh keys to force StreamBuilder updates
  final ValueNotifier<int> _refreshTrigger = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _checkUserAccess();
  }

  Future<void> _loadLocations() async {
    if (organizationId == null) {
      debugPrint(
        '[AdminDashboard] Cannot load locations - organizationId is null',
      );
      return;
    }

    debugPrint(
      '[AdminDashboard] Loading locations for organization: $organizationId',
    );

    try {
      final locationsSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();

      debugPrint(
        '[AdminDashboard] Found ${locationsSnap.docs.length} locations',
      );

      final locations =
          locationsSnap.docs.map((doc) {
            final data = doc.data();
            debugPrint(
              '[AdminDashboard] Location ${doc.id}: ${data['locationName'] ?? 'Unnamed'}',
            );
            return {
              'id': doc.id,
              'name': data['locationName'] ?? 'Unnamed Location',
              'isPrimary': data['isPrimary'] ?? false,
            };
          }).toList();

      // Sort so primary location comes first
      locations.sort((a, b) {
        if (a['isPrimary'] == true && b['isPrimary'] != true) return -1;
        if (b['isPrimary'] == true && a['isPrimary'] != true) return 1;
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      if (mounted) {
        setState(() {
          _availableLocations = locations;
          _showLocationSelector =
              locations.length > 1; // Show selector if multiple locations

          // Auto-select primary location or first location if available
          if (locations.isNotEmpty) {
            final primaryLocation = locations.firstWhere(
              (loc) => loc['isPrimary'] == true,
              orElse: () => locations.first,
            );
            _selectedLocationId = primaryLocation['id'] as String?;
            _selectedLocationName = primaryLocation['name'] as String?;
            debugPrint(
              '[AdminDashboard] Selected location: ${primaryLocation['name']} (${primaryLocation['id']})',
            );
          } else {
            _selectedLocationId = null;
            _selectedLocationName = null;
            debugPrint(
              '[AdminDashboard] No locations found - will create default location',
            );
            // Create a default location for the organization
            _createDefaultLocation();
          }
        });
      }
    } catch (e) {
      debugPrint('[AdminDashboard] Error loading locations: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load locations: $e')));
      }
    }
  }

  Future<void> _createDefaultLocation() async {
    if (organizationId == null) return;

    try {
      debugPrint(
        '[AdminDashboard] Creating default location for organization: $organizationId',
      );

      // Create a default location
      final defaultLocationData = {
        'locationName': 'Main Location',
        'address': '',
        'city': '',
        'state': '',
        'zip': '',
        'isPrimary': true,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      final newLocationRef = await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .add(defaultLocationData);

      debugPrint(
        '[AdminDashboard] Default location created with ID: ${newLocationRef.id}',
      );

      // Reload locations after creating the default one
      await _loadLocations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Created default location. You can edit it in the Locations section.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[AdminDashboard] Error creating default location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create default location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _refreshTrigger.dispose();
    super.dispose();
  }

  Future<void> _checkUserAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        context.go(AppRoutes.loginPage.path);
      }
      return;
    }

    try {
      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData == null) {
          debugPrint('[AdminDashboard] User document exists but data is null');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'User data is corrupted. Please contact support.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            context.go(AppRoutes.loginPage.path);
          }
          return;
        }
        final role = userData['userRole'] as int? ?? 0;
        final orgId = userData['organizationId'] as String?;

        debugPrint('[AdminDashboard] User role: $role, OrgId: $orgId');

        // Only allow admin access (userRole = 2) and require organizationId
        if (role != 2 || orgId == null) {
          debugPrint(
            '[AdminDashboard] Access denied - role: $role, orgId: $orgId',
          );
          if (mounted) {
            context.go(AppRoutes.userDashboardPage.path);
          }
          return;
        }

        // Check organization subscription status
        final orgDoc =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(orgId)
                .get();

        if (orgDoc.exists) {
          final orgData = orgDoc.data();
          if (orgData == null) {
            debugPrint(
              '[AdminDashboard] Organization document exists but data is null: $orgId',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Organization data is corrupted. Please contact support.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              context.go(AppRoutes.loginPage.path);
            }
            return;
          }

          final subscriptionStatus =
              orgData['subscriptionStatus'] as String? ?? 'pending';

          debugPrint(
            '[AdminDashboard] Organization data keys: ${orgData.keys.toList()}',
          );
          debugPrint(
            '[AdminDashboard] Subscription status: $subscriptionStatus',
          );

          // Allow active, trialing, or trial subscriptions
          if (!(subscriptionStatus == 'active' ||
              subscriptionStatus == 'trialing' ||
              subscriptionStatus == 'trial')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Your subscription is not active ($subscriptionStatus). Please complete your payment to access the dashboard.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
              context.go(AppRoutes.loginPage.path);
            }
            return;
          }
        } else {
          debugPrint(
            '[AdminDashboard] Organization document not found: $orgId',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Organization not found. Please contact support.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            context.go(AppRoutes.loginPage.path);
          }
          return;
        }

        if (mounted) {
          setState(() {
            userRole = role;
            organizationId = orgId;
            isLoading = false;
          });
          // Load locations after setting organizationId
          _loadLocations();
        }
      } else {
        debugPrint('[AdminDashboard] User document not found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found. Please contact support.'),
              backgroundColor: Colors.red,
            ),
          );
          context.go(AppRoutes.loginPage.path);
        }
        return;
      }
    } catch (e) {
      debugPrint('[AdminDashboard] Error checking user access: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
        context.go(AppRoutes.loginPage.path);
      }
    }
  }

  // Helper method to trigger refresh
  void _triggerRefresh() {
    _refreshTrigger.value++;
  }

  void _onLocationSelected(String locationId) {
    setState(() {
      _selectedLocationId = locationId;
      _selectedLocationName =
          _availableLocations.firstWhere(
            (loc) => loc['id'] == locationId,
            orElse: () => {'name': 'Unknown'},
          )['name'];
    });
    _triggerRefresh();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(
          appBarTitle: 'Admin Dashboard',
          userRole: userRole,
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Location selector (only show if multiple locations)
            if (_showLocationSelector) ...[
              _buildLocationSelector(),
              const SizedBox(height: 16),
            ],
            _buildUsersSection(),
            const SizedBox(height: 16),
            _buildShiftsSection(),
            const SizedBox(height: 16),
            _buildChecklistsSection(),
            const SizedBox(height: 16),
            _buildLocationsSection(),
            const SizedBox(height: 16),
            _buildDocumentsSection(),
            // Debug section - only show in debug mode
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              _buildDebugSection(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 2, userRole: userRole),
    );
  }

  Widget _buildUsersSection() {
    return _buildSection(
      'Users',
      () => _showUserBottomSheet(),
      _buildUsersList(),
    );
  }

  Widget _buildShiftsSection() {
    return _buildSection(
      'Shifts',
      () => _showShiftBottomSheet(),
      _buildShiftsList(),
    );
  }

  Widget _buildChecklistsSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Checklists',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Migration button (only show if there might be old checklists)
                TextButton.icon(
                  onPressed: () => _showMigrationDialog(),
                  icon: const Icon(Icons.sync_alt, size: 16),
                  label: const Text('Migrate', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showChecklistBottomSheet(),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Add New',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          _buildChecklistsList(),
        ],
      ),
    );
  }

  void _showMigrationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Migrate Checklists to Locations'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will copy any organization-level checklists to all locations.',
                ),
                SizedBox(height: 8),
                Text(
                  'Each location will get its own copy that can be customized independently.',
                ),
                SizedBox(height: 16),
                Text(
                  'This is useful when upgrading from the old checklist system.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _migrateChecklistsToLocations();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Migrate'),
              ),
            ],
          ),
    );
  }

  Widget _buildLocationsSection() {
    return _buildSection(
      'Locations',
      () => _showLocationBottomSheet(),
      _buildLocationsList(),
    );
  }

  Widget _buildDocumentsSection() {
    return _buildSection(
      'Training Documents',
      () => _showUploadDocumentBottomSheet(),
      _buildDocumentsList(),
    );
  }

  Widget _buildSection(String title, VoidCallback onAdd, Widget content) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            trailing: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(
                Icons.add_circle_outline,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Add New',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                elevation: 0,
              ),
            ),
          ),
          const Divider(),
          content,
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (organizationId == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No organization data available'),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          // Query root users collection by organizationId
          stream: FirestoreEnforcer.instance
              .collection('users')
              .where('organizationId', isEqualTo: organizationId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading users: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final users = snapshot.data?.docs ?? [];

            if (users.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No users found',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Add users to get started',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            // Filter users by selected location
            final usersToShow =
                users
                    .where((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      final role = userData['userRole'] ?? 0;
                      if (_selectedLocationId == null) return true;
                      if (role == 2) return true; // Admins always show
                      if (role == 0) {
                        // General user: only show if locationId matches
                        return userData['locationId'] == _selectedLocationId;
                      }
                      if (role == 1) {
                        // Manager: only show if locationIds contains selected location
                        final locIds =
                            userData['locationIds'] is List
                                ? List<String>.from(userData['locationIds'])
                                : [];
                        return locIds.contains(_selectedLocationId);
                      }
                      return false;
                    })
                    .map((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      final name =
                          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                              .trim();
                      final email =
                          userData['emailAddress'] ??
                          userData['userEmail'] ??
                          userData['email'] ??
                          'No email';
                      final role = userData['userRole'] ?? 0;
                      final roleText =
                          role == 2
                              ? 'Admin'
                              : role == 1
                              ? 'Manager'
                              : 'General User';

                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(name.isEmpty ? 'Unnamed User' : name),
                        subtitle: Text('$email • $roleText'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed:
                                  () => _showUserBottomSheet(
                                    doc.id,
                                    doc.data() as Map<String, dynamic>,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed:
                                  () => _showDeleteConfirmation(
                                    context: context,
                                    title: 'Delete User',
                                    content:
                                        'Are you sure you want to delete this user? This action cannot be undone.',
                                    onConfirm: () => _deleteUser(doc.id),
                                  ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList();

            return users.length > 4
                ? SizedBox(
                  height: 300, // Fixed height for scrollable area
                  child: ListView.builder(
                    itemCount: usersToShow.length,
                    itemBuilder: (context, index) => usersToShow[index],
                  ),
                )
                : Column(children: usersToShow);
          },
        );
      },
    );
  }

  Widget _buildLocationsList() {
    if (organizationId == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No organization data available'),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('locations')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading locations: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final locations = snapshot.data?.docs ?? [];

            if (locations.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_city_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No locations found',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Add a location to get started',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            // Show all locations with scrolling if more than 4
            final locationsToShow =
                locations.map((doc) {
                  final locationData = doc.data() as Map<String, dynamic>;
                  final name =
                      locationData['locationName'] ?? 'Unnamed Location';
                  final address = locationData['address'] ?? '';
                  final city = locationData['city'] ?? '';
                  final state = locationData['state'] ?? '';

                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(name),
                    subtitle: Text('$address, $city, $state'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed:
                              () => _showLocationBottomSheet(
                                doc.id,
                                locationData,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed:
                              () => _showDeleteConfirmation(
                                context: context,
                                title: 'Delete Location',
                                content:
                                    'Are you sure you want to delete this location? This action cannot be undone.',
                                onConfirm: () => _deleteLocation(doc.id),
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList();

            return locations.length > 4
                ? SizedBox(
                  height: 300, // Fixed height for scrollable area
                  child: ListView.builder(
                    itemCount: locationsToShow.length,
                    itemBuilder: (context, index) => locationsToShow[index],
                  ),
                )
                : Column(children: locationsToShow);
          },
        );
      },
    );
  }

  Widget _buildShiftsList() {
    if (organizationId == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No organization data available'),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('shifts')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading shifts: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final snapshotDocs = snapshot.data?.docs ?? [];
            final allShifts =
                snapshotDocs
                    .map(
                      (doc) => {
                        'id': doc.id,
                        'data': doc.data() as Map<String, dynamic>,
                      },
                    )
                    .toList();

            // Filter shifts by selected location if a location is selected
            List<Map<String, dynamic>> filteredShifts = allShifts;
            if (_selectedLocationId != null) {
              filteredShifts =
                  allShifts.where((shift) {
                    final shiftData = shift['data'] as Map<String, dynamic>;
                    final locationIds = List<String>.from(
                      shiftData['locationIds'] ?? [],
                    );
                    return locationIds.contains(_selectedLocationId);
                  }).toList();
            }

            if (filteredShifts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.schedule_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      _selectedLocationId != null
                          ? 'No shifts found for selected location'
                          : 'No shifts found',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Create shifts to manage scheduling',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            // Show all shifts with scrolling if more than 4
            final shiftsToShow =
                filteredShifts.map((shift) {
                  final shiftData = shift['data'] as Map<String, dynamic>;
                  final shiftId = shift['id'] as String;

                  final name =
                      shiftData['shiftName'] as String? ?? 'Unnamed Shift';
                  final startTime = shiftData['startTime'] ?? '';
                  final endTime = shiftData['endTime'] ?? '';
                  final roles = List<String>.from(shiftData['jobType'] ?? []);
                  final locationIds = List<String>.from(
                    shiftData['locationIds'] ?? [],
                  );
                  final staffingLevels = Map<String, dynamic>.from(
                    shiftData['staffingLevels'] ?? {},
                  );

                  // Get location names for this shift
                  final locationNames =
                      locationIds.map((id) {
                        final location = _availableLocations.firstWhere(
                          (loc) => loc['id'] == id,
                          orElse: () => {'name': 'Unknown Location'},
                        );
                        return location['name'] as String;
                      }).toList();

                  // Calculate total suggested staff
                  final totalStaff = staffingLevels.values.fold<int>(
                    0,
                    (total, staffCount) => total + (staffCount as int? ?? 0),
                  );

                  return ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$startTime - $endTime • ${roles.join(', ')}'),
                        if (totalStaff > 0)
                          Text(
                            'Suggested staff: $totalStaff people',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (locationNames.isNotEmpty)
                          Text(
                            'Locations: ${locationNames.join(', ')}',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed:
                              () => _showShiftBottomSheet(
                                shiftId,
                                ShiftData.fromJson(shiftData),
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed:
                              () => _showDeleteConfirmation(
                                context: context,
                                title: 'Delete Shift',
                                content:
                                    'Are you sure you want to delete $name? This action cannot be undone.',
                                onConfirm: () => _deleteShift(shiftId),
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList();

            return filteredShifts.length > 4
                ? SizedBox(
                  height: 300, // Fixed height for scrollable area
                  child: ListView.builder(
                    itemCount: shiftsToShow.length,
                    itemBuilder: (context, index) => shiftsToShow[index],
                  ),
                )
                : Column(children: shiftsToShow);
          },
        );
      },
    );
  }

  Widget _buildChecklistsList() {
    if (organizationId == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No organization data available'),
      );
    }

    // Show organization-level checklist templates (not location-specific)
    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('checklist_templates')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading checklists: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final checklists = snapshot.data?.docs ?? [];

            if (checklists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.checklist_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _selectedLocationName != null
                          ? 'No checklists found for $_selectedLocationName'
                          : 'No checklists found',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Create checklists to track tasks',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            // Show all checklists with scrolling if more than 4
            final checklistsToShow =
                checklists.map((doc) {
                  final checklistData = doc.data() as Map<String, dynamic>;
                  final name = checklistData['name'] ?? 'Unnamed Checklist';
                  final description =
                      checklistData['description'] ?? 'No description';
                  final tasksList =
                      checklistData['tasks'] as List<dynamic>? ?? [];
                  final taskCount = tasksList.length;

                  return ListTile(
                    leading: const Icon(Icons.checklist),
                    title: Text(name),
                    subtitle: Text('$description • $taskCount tasks'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed:
                              () => _showChecklistBottomSheet(
                                doc.id,
                                checklistData,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed:
                              () => _showDeleteConfirmation(
                                context: context,
                                title: 'Delete Checklist',
                                content:
                                    'Are you sure you want to delete $name? This action cannot be undone.',
                                onConfirm: () => _deleteChecklist(doc.id),
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList();

            final checklistWidget =
                checklists.length > 4
                    ? SizedBox(
                      height: 300, // Fixed height for scrollable area
                      child: ListView.builder(
                        itemCount: checklistsToShow.length,
                        itemBuilder:
                            (context, index) => checklistsToShow[index],
                      ),
                    )
                    : Column(children: checklistsToShow);

            return checklistWidget;
          },
        );
      },
    );
  }

  Widget _buildDocumentsList() {
    if (organizationId == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No organization data available'),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('training_documents')
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading documents: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final documents = snapshot.data?.docs ?? [];

            if (documents.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No documents found',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Upload training materials to get started',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children:
                  documents.map((doc) {
                    final docData = doc.data() as Map<String, dynamic>;
                    final title = docData['title'] ?? 'Untitled Document';
                    final category = docData['category'] ?? 'Uncategorized';
                    final fileType = docData['fileType'] ?? 'Unknown';

                    return ListTile(
                      leading: Icon(_getFileIcon(fileType)),
                      title: Text(title),
                      subtitle: Text(category),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed:
                                () => _showUploadDocumentBottomSheet(
                                  doc.id,
                                  docData,
                                ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed:
                                () => _showDeleteConfirmation(
                                  context: context,
                                  title: 'Delete Document',
                                  content:
                                      'Are you sure you want to delete $title? This action cannot be undone.',
                                  onConfirm: () => _deleteDocument(doc.id),
                                ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            );
          },
        );
      },
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'mp4':
      case 'mov':
        return Icons.videocam;
      default:
        return Icons.description;
    }
  }

  // Bottom sheet methods
  void _showUserBottomSheet([String? userId, Map<String, dynamic>? userData]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) =>
              UserManagementBottomSheet(userId: userId, userData: userData),
    );
  }

  void _showShiftBottomSheet([String? shiftId, ShiftData? shiftData]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => ShiftTemplateBottomSheet(
            shiftId: shiftId,
            shiftData: shiftData,
            organizationId: organizationId!,
            availableLocations: _availableLocations,
            onShiftSaved: () {
              // Refresh the dashboard
              _triggerRefresh();
            },
          ),
    );
  }

  void _showLocationBottomSheet([
    String? locationId,
    Map<String, dynamic>? locationData,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => LocationBottomSheet(
            initialName: locationData?['locationName'],
            initialStreet: locationData?['address'],
            initialCity: locationData?['city'],
            initialState: locationData?['state'],
            initialZip: locationData?['zip'],
            onSave: (updatedData) {
              // Handle save logic here
            },
          ),
    );
  }

  void _showChecklistBottomSheet([
    String? checklistId,
    Map<String, dynamic>? checklistData,
  ]) {
    // For organization-level checklists, we don't need a specific location
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Organization ID not available. Please try refreshing the page.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => ChecklistBottomSheet(
            organizationId: organizationId!,
            locationId:
                _selectedLocationId ??
                'no-location', // Use placeholder if no location
            checklistId: checklistId,
            initialData: checklistData,
            availableLocations: _availableLocations,
            onSave: (result) {
              _saveChecklist(
                checklistData: result['checklistData'],
                selectedShiftIds: List<String>.from(
                  result['selectedShiftIds'] ?? [],
                ),
                duplicateToAll: result['duplicateToAll'] ?? false,
                existingChecklistId: checklistId,
              );
            },
          ),
    );
  }

  Future<void> _saveChecklist({
    required Map<String, dynamic> checklistData,
    required List<String> selectedShiftIds,
    required bool duplicateToAll,
    String? existingChecklistId,
  }) async {
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Missing organization ID.')),
      );
      return;
    }

    final batch = FirestoreEnforcer.instance.batch();

    // 1. Save the main checklist template at organization level
    final mainChecklistRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('checklist_templates')
        .doc(existingChecklistId); // If null, a new ID is generated

    batch.set(mainChecklistRef, checklistData, SetOptions(merge: true));
    final mainChecklistId = mainChecklistRef.id;

    // 2. If duplicating, save additional copies (but organization-level templates don't need location duplication)
    // Note: Since we're now using organization-level templates, they're automatically available to all locations
    // The duplication logic is no longer needed, but we'll keep the checkbox for UI consistency

    // 3. Update shift associations
    final shiftsCollection = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('shifts');

    // Atomically update shifts: remove from old, add to new
    if (existingChecklistId != null) {
      // Find all shifts currently containing the checklist
      final shiftsWithChecklistSnapshot =
          await shiftsCollection
              .where('checklistTemplateIds', arrayContains: existingChecklistId)
              .get();

      for (final shiftDoc in shiftsWithChecklistSnapshot.docs) {
        // If a shift that had the checklist is not in the new selection, remove it
        if (!selectedShiftIds.contains(shiftDoc.id)) {
          batch.update(shiftDoc.reference, {
            'checklistTemplateIds': FieldValue.arrayRemove([
              existingChecklistId,
            ]),
          });
        }
      }
    }
    // Add checklist to all newly selected shifts
    for (final shiftId in selectedShiftIds) {
      batch.update(shiftsCollection.doc(shiftId), {
        'checklistTemplateIds': FieldValue.arrayUnion([mainChecklistId]),
      });
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checklist saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _triggerRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save checklist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUploadDocumentBottomSheet([
    String? docId,
    Map<String, dynamic>? docData,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => UploadDocumentBottomSheet(
            documentId: docId,
            documentData: docData,
            onDocumentUploaded: () {
              _triggerRefresh();
            },
          ),
    );
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('users')
          .doc(userId)
          .delete();
      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
      }
    }
  }

  Future<void> _deleteLocation(String locationId) async {
    if (_selectedLocationId == null) return;

    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .delete();
      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting location: $e')));
      }
    }
  }

  Future<void> _deleteShift(String shiftId) async {
    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts')
          .doc(shiftId)
          .delete();
      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting shift: $e')));
      }
    }
  }

  Future<void> _deleteDocument(String documentId) async {
    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('training_documents')
          .doc(documentId)
          .delete();
      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting document: $e')));
      }
    }
  }

  Future<void> _deleteChecklist(String checklistId) async {
    try {
      // Delete from organization-level checklist templates (not location-specific)
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('checklist_templates')
          .doc(checklistId)
          .delete();
      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checklist deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting checklist: $e')));
      }
    }
  }

  void _showDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  /// Migration helper: Copy organization-level checklists to all locations
  Future<void> _migrateChecklistsToLocations() async {
    if (organizationId == null) return;

    try {
      // Get all existing organization-level checklist templates
      final orgChecklistsSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('checklist_templates')
              .get();

      if (orgChecklistsSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No organization-level checklists found to migrate',
              ),
            ),
          );
        }
        return;
      }

      // Get all locations
      final locationsSnapshot =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();

      if (locationsSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No locations found to migrate checklists to'),
            ),
          );
        }
        return;
      }

      int migratedCount = 0;

      // Copy each checklist to each location
      for (final checklistDoc in orgChecklistsSnapshot.docs) {
        final checklistData = checklistDoc.data();

        for (final locationDoc in locationsSnapshot.docs) {
          final locationData = locationDoc.data();
          final locationName =
              locationData['locationName'] ?? 'Unknown Location';

          // Create location-specific checklist
          final locationChecklistData = {
            ...checklistData,
            'locationId': locationDoc.id,
            'locationName': locationName,
            'migratedFrom': 'organization-level',
            'migratedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .doc(locationDoc.id)
              .collection('checklist_templates')
              .add(locationChecklistData);

          migratedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Migrated $migratedCount location-specific checklists successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error migrating checklists: $e')),
        );
      }
    }
  }

  Widget _buildLocationSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButtonFormField<String>(
          value: _selectedLocationId,
          onChanged: (value) {
            if (value != null) {
              _onLocationSelected(value);
            }
          },
          items:
              _availableLocations.map((location) {
                return DropdownMenuItem<String>(
                  value: location['id'],
                  child: Text(location['name']),
                );
              }).toList(),
          decoration: const InputDecoration(
            labelText: 'Select Location',
            border: InputBorder.none,
            icon: Icon(Icons.location_pin),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Debug Tools',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Development and testing utilities (Debug mode only)',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Role Diagnostic Widget
            const RoleDiagnostic(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                if (organizationId == null || _selectedLocationId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please select an organization and location first',
                      ),
                    ),
                  );
                  return;
                }
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seeding test data...')),
                  );
                  await SchedulingTestDataSeeder.seedTestData(
                    organizationId: organizationId!,
                    locationId: _selectedLocationId!,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Test data seeded successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error seeding data: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.data_usage),
              label: const Text('Seed Test Data'),
            ),
            const SizedBox(height: 16),
            // Role diagnostic widget
            const RoleDiagnostic(),
          ],
        ),
      ),
    );
  }
} // End of _AdminDashboardPageState class
