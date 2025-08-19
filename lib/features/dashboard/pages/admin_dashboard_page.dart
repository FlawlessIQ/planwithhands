import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/custom_code/widgets/UserManagementBottomSheet.dart';
import 'package:hands_app/ui/location_bottom_sheet_new.dart';
import 'package:hands_app/ui/checklist_bottom_sheet.dart';
import 'package:hands_app/features/shifts/shift_template_bottom_sheet.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/utils/location_helper.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/state/app_state.dart';
import 'package:hands_app/data/models/location_data.dart';
import 'package:hands_app/core/logging/logger.dart';
// Admin tools widgets removed from this page; imports intentionally removed
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

// Admin dashboard view selector
enum AdminView { shiftsChecklists, usersLocations }

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  int? userRole;
  String? organizationId;
  bool isLoading = true;
  bool _hasShownWelcomeDialog = false; // Prevent multiple welcome dialogs

  // Admin view toggle
  AdminView _currentView = AdminView.shiftsChecklists; // default

  // Available locations (no longer storing selected location locally)
  List<Map<String, dynamic>> _availableLocations = [];

  // Add refresh keys to force StreamBuilder updates
  final ValueNotifier<int> _refreshTrigger = ValueNotifier<int>(0);

  /// Get the currently selected location ID from shared state
  String? get _selectedLocationId {
    return ref.read(appStateProvider).selectedLocation?.locationId;
  }

  /// Get the currently selected location name from shared state
  String? get _selectedLocationName {
    return ref.read(appStateProvider).selectedLocation?.locationName;
  }

  @override
  void initState() {
    super.initState();
    _checkUserAccess();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if this is a new user setup flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouterState.of(context).uri;
      final isSetup = uri.queryParameters['setup'] == 'true';

      if (isSetup && !_hasShownWelcomeDialog) {
        logger.d('[AdminDashboard] New user setup detected, will show location creation flow');
        _hasShownWelcomeDialog = true; // Mark as shown to prevent duplicate dialogs
        // Show the location creation flow regardless of existing locations
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showFirstLocationCreationFlow();
          }
        });
      }
    });
  }

  Future<void> _loadLocations() async {
    if (organizationId == null) {
      logger.w('[AdminDashboard] Cannot load locations - organizationId is null');
      return;
    }

    logger.d('[AdminDashboard] Loading locations for organization: $organizationId');

    try {
      final locationsSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(organizationId)
              .collection('locations')
              .get();

  logger.d('[AdminDashboard] Found ${locationsSnap.docs.length} locations');

      final locations =
          locationsSnap.docs.map((doc) {
            final data = doc.data();
            logger.d('[AdminDashboard] Location ${doc.id}: ${data['locationName'] ?? 'Unnamed'}');
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

          // Auto-select primary location or first location if available and no location is currently selected
          if (locations.isNotEmpty) {
            final currentSelectedLocation = ref.read(appStateProvider).selectedLocation;

            // Only auto-select if no location is currently selected or the current selection is invalid
            if (currentSelectedLocation == null ||
                !locations.any((loc) => loc['id'] == currentSelectedLocation.locationId)) {
              final primaryLocation = locations.firstWhere(
                (loc) => loc['isPrimary'] == true,
                orElse: () => locations.first,
              );

              // Update shared state with selected location
              final locationData = LocationData(
                locationId: primaryLocation['id'],
                locationName: primaryLocation['name'],
                createdAt: DateTime.now(),
                locationAddress: '',
              );
              ref.read(appStateProvider.notifier).setSelectedLocation(locationData);

              logger.d(
                '[AdminDashboard] Auto-selected location: ${primaryLocation['name']} (${primaryLocation['id']})',
              );
            } else {
              logger.d('[AdminDashboard] Keeping existing selection: ${currentSelectedLocation.locationName}');
            }
          } else {
            // Clear selected location
            ref.read(appStateProvider.notifier).setSelectedLocation(null);
              logger.i('[AdminDashboard] No locations found - will show location creation flow');

            // Only show the location creation bottom sheet if we haven't already shown the welcome dialog
            if (!_hasShownWelcomeDialog) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showFirstLocationCreationFlow();
              });
            }
          }
        });
      }
    } catch (e) {
  logger.e('[AdminDashboard] Error loading locations: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load locations: $e')));
      }
    }
  }

  /// Show a guided flow for creating the first location
  void _showFirstLocationCreationFlow() {
    if (organizationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Organization ID not available. Please try again.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // User must complete this step
      builder:
          (context) => AlertDialog(
            title: const Text('Welcome to Hands!'),
            content: const Text(
              'Let\'s get you started by setting up your first location. '
              'This will be where your team members check in and out for shifts.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the welcome dialog
                  _showLocationBottomSheetForFirstLocation(); // Show the location creation bottom sheet
                },
                child: const Text('Create My First Location'),
              ),
            ],
          ),
    );
  }

  /// Show location bottom sheet specifically for first location creation with proper completion handling
  void _showLocationBottomSheetForFirstLocation() {
    if (organizationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Organization ID not available. Please try again.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // Don't allow dismissing during first location setup
      enableDrag: false, // Don't allow dragging to dismiss
      builder:
          (context) => LocationWizard(
            organizationId: organizationId!,
            onCompleted: () async {
              _triggerRefresh();
              await _loadLocations();
              // The bottom sheet will automatically close after completion
              // No need to manually close it here since LocationWizard handles it
            },
          ),
    );
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
      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData == null) {
          logger.w('[AdminDashboard] User document exists but data is null');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User data is corrupted. Please contact support.'),
                backgroundColor: Colors.red,
              ),
            );
            context.go(AppRoutes.loginPage.path);
          }
          return;
        }
        // Allow all authenticated users - removed onboarding check for existing users
        final role = userData['userRole'] as int? ?? 0;
        final orgId = userData['organizationId'] as String?;

  logger.d('[AdminDashboard] User role: $role, OrgId: $orgId');

        // Only allow admin access (userRole = 2) and require organizationId
        if (role != 2 || orgId == null) {
          logger.w('[AdminDashboard] Access denied - role: $role, orgId: $orgId');
          if (mounted) {
            context.go(AppRoutes.userDashboardPage.path);
          }
          return;
        }

        // Check organization subscription status
        final orgDoc = await FirestoreEnforcer.instance.collection('organizations').doc(orgId).get();

        if (orgDoc.exists) {
          final orgData = orgDoc.data();
          if (orgData == null) {
            logger.w('[AdminDashboard] Organization document exists but data is null: $orgId');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Organization data is corrupted. Please contact support.'),
                  backgroundColor: Colors.red,
                ),
              );
              context.go(AppRoutes.loginPage.path);
            }
            return;
          }

          final subscriptionStatus = orgData['subscriptionStatus'] as String? ?? 'pending';

          logger.d('[AdminDashboard] Organization data keys: ${orgData.keys.toList()}');
          logger.d('[AdminDashboard] Subscription status: $subscriptionStatus');

          // Allow active, trialing, or trial subscriptions
          if (!(subscriptionStatus == 'active' || subscriptionStatus == 'trialing' || subscriptionStatus == 'trial')) {
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
          logger.w('[AdminDashboard] Organization document not found: $orgId');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Organization not found. Please contact support.'),
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
  logger.w('[AdminDashboard] User document not found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found. Please contact support.'), backgroundColor: Colors.red),
          );
          context.go(AppRoutes.loginPage.path);
        }
        return;
      }
    } catch (e) {
  logger.e('[AdminDashboard] Error checking user access: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e'), backgroundColor: Colors.red));
        context.go(AppRoutes.loginPage.path);
      }
    }
  }

  // Helper method to trigger refresh
  void _triggerRefresh() {
    _refreshTrigger.value++;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(appBarTitle: 'Setup', userRole: userRole),
        automaticallyImplyLeading: false,
        actions: [
          // Compact location selector for mobile
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              enabled: _availableLocations.isNotEmpty,
              onSelected: (value) async {
                // Find the selected location details
                final selectedLoc = _availableLocations.firstWhere(
                  (loc) => loc['id'] == value,
                  orElse: () => {'id': value, 'name': 'Unknown Location'},
                );

                // Update shared state with selected location
                final locationData = LocationData(
                  locationId: selectedLoc['id'],
                  locationName: selectedLoc['name'],
                  createdAt: DateTime.now(),
                  locationAddress: '',
                );
                ref.read(appStateProvider.notifier).setSelectedLocation(locationData);

                _triggerRefresh();
              },
              itemBuilder:
                  (context) =>
                      _availableLocations.map((location) {
                        return PopupMenuItem<String>(
                          value: location['id'],
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color:
                                    location['id'] == _selectedLocationId
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[600],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location['name'],
                                  style: TextStyle(
                                    fontWeight:
                                        location['id'] == _selectedLocationId ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (location['id'] == _selectedLocationId)
                                const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16)),
                            ],
                          ),
                        );
                      }).toList(),
              child: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isNarrowScreen = screenWidth < 400;

                  if (isNarrowScreen) {
                    // Compact mobile version - just location icon
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                    );
                  } else {
                    // Full desktop version
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _selectedLocationName?.isNotEmpty == true ? _selectedLocationName! : 'Select Location',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          // Menu button
          UnifiedMenuButton(userRole: userRole),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildViewToggle(),
            const SizedBox(height: 16),
            if (_currentView == AdminView.shiftsChecklists) ...[
              _buildShiftsSection(),
              const SizedBox(height: 16),
              _buildChecklistsSection(),
            ] else if (_currentView == AdminView.usersLocations) ...[
              _buildUsersSection(),
              const SizedBox(height: 16),
              _buildLocationsSection(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 2, userRole: userRole),
    );
  }

  Widget _buildViewToggle() {
    // Silver-gradient two-segment toggle button
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTight = constraints.maxWidth < 420;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('View', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5F5F7), Color(0xFFE9E9EA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  _buildToggleSegment(
                    context,
                    label: isTight ? 'Shifts' : 'Shifts & Checklists',
                    icon: Icons.schedule,
                    selected: _currentView == AdminView.shiftsChecklists,
                    onTap: () {
                      if (_currentView != AdminView.shiftsChecklists && mounted) {
                        setState(() => _currentView = AdminView.shiftsChecklists);
                      }
                    },
                    left: true,
                  ),
                  _buildToggleSegment(
                    context,
                    label: isTight ? 'Users' : 'Users & Locations',
                    icon: Icons.group,
                    selected: _currentView == AdminView.usersLocations,
                    onTap: () {
                      if (_currentView != AdminView.usersLocations && mounted) {
                        setState(() => _currentView = AdminView.usersLocations);
                      }
                    },
                    left: false,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Place this helper inside the _AdminDashboardPageState class ---
  Widget _buildToggleSegment(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool left,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient:
                selected
                    ? const LinearGradient(
                      colors: [Color(0xFFBFC1C6), Color(0xFFD7D8DB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: left ? const Radius.circular(12) : Radius.zero,
              right: !left ? const Radius.circular(12) : Radius.zero,
            ),
            boxShadow:
                selected
                    ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
                    : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: selected ? Colors.black87 : Colors.black45),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black87 : Colors.black54,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientSection({
    required IconData icon,
    required String title,
    required List<Color> colors,
    required VoidCallback onAdd,
    required Widget child,
  }) {
    // Create darker background colors from the header gradient
    final backgroundColors = colors.map((color) => color.withValues(alpha: 0.08)).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1), // Creates a subtle border effect
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: backgroundColors),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
              ),
              child: ListTile(
                leading: Icon(icon, color: Colors.white, size: 24),
                title: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                  label: const Text('Add New', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                    elevation: 0,
                    side: const BorderSide(color: Colors.white, width: 1),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildUsersSection() {
    return _buildGradientSection(
      icon: Icons.group,
      title: 'Users',
      colors: [const Color(0xFF4c63d2), const Color(0xFF5a4dae)], // Darker purple-blue gradient
      onAdd: () => _showUserBottomSheet(),
      child: _buildUsersList(),
    );
  }

  Widget _buildShiftsSection() {
    return _buildGradientSection(
      icon: Icons.schedule,
      title: 'Shifts',
      colors: [const Color(0xFF2e86de), const Color(0xFF006ba6)], // Darker blue gradient
      onAdd: () => _showShiftBottomSheet(),
      child: _buildShiftsList(),
    );
  }

  Widget _buildChecklistsSection() {
    return _buildGradientSection(
      icon: Icons.checklist,
      title: 'Checklists',
      colors: [const Color(0xFF26de81), const Color(0xFF20bf6b)], // Darker green gradient
      onAdd: () => _showChecklistBottomSheet(),
      child: _buildChecklistsList(),
    );
  }

  // Deprecated: migration dialog removed

  Widget _buildLocationsSection() {
    return _buildGradientSection(
      icon: Icons.location_on,
      title: 'Locations',
      colors: [const Color(0xFFe55039), const Color(0xFFfa7f72)], // Darker coral-red gradient
      onAdd: () => _showLocationWizard(),
      child: _buildLocationsList(),
    );
  }

  // Admin tools removed from UI; helper removed.

  Widget _buildUsersList() {
    if (organizationId == null) {
      return const Padding(padding: EdgeInsets.all(16.0), child: Text('No organization data available'));
    }

    return ValueListenableBuilder<int>(
      valueListenable: _refreshTrigger,
      builder: (context, value, child) {
        return StreamBuilder<QuerySnapshot>(
          // Query root users collection by organizationId
          stream:
              FirestoreEnforcer.instance
                  .collection('users')
                  .where('organizationId', isEqualTo: organizationId)
                  .snapshots(),
          builder: (context, snapshot) {
            // Debug logging
            logger.d('[AdminDashboard] Organization ID: $organizationId');
            logger.d('[AdminDashboard] User snapshot has data: ${snapshot.hasData}');
            if (snapshot.hasData) {
              final snapshotData = snapshot.data;
              if (snapshotData != null) {
                logger.d('[AdminDashboard] Number of users found: ${snapshotData.docs.length}');
                for (final doc in snapshotData.docs) {
                  final userData = doc.data() as Map<String, dynamic>;
                  logger.d(
                    '[AdminDashboard] User ${doc.id}: ${userData['email']} - orgId: ${userData['organizationId']}',
                  );
                }
              }
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading users: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
            }

            final users = snapshot.data?.docs ?? [];

            if (users.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No users found', style: TextStyle(color: Colors.grey)),
                    Text('Add users to get started', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                        // General user: show if their locationIds contain the selected location
                        // OR if they have no location data (include) or their locations are orphaned (include)
                        final locIds = coerceToLocationIds(userData['locationIds'] ?? userData['locationId']);

                        if (locIds.isEmpty) return true; // No location data
                        if (_selectedLocationId == null) return true; // No filter applied
                        if (locIds.contains(_selectedLocationId)) return true; // Matches selected

                        // If none of the user's locations exist in current available locations, treat as orphan and include
                        final anyMatch = locIds.any((id) => _availableLocations.any((loc) => loc['id'] == id));
                        if (!anyMatch) {
                          logger.d(
                            '[AdminDashboard] User ${doc.id} has orphaned locationIds: $locIds - including anyway',
                          );
                          return true;
                        }

                        return false;
                      }
                      if (role == 1) {
                        // Manager: only show if any of their locationIds contains selected location
                        final locIds = coerceToLocationIds(userData['locationIds'] ?? userData['locationId']);
                        if (_selectedLocationId == null) return true;
                        return locIds.contains(_selectedLocationId);
                      }
                      return false;
                    })
                    .map((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      final name = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
                      final email =
                          userData['emailAddress'] ?? userData['userEmail'] ?? userData['email'] ?? 'No email';
                      final role = userData['userRole'] ?? 0;
                      final roleText =
                          role == 2
                              ? 'Admin'
                              : role == 1
                              ? 'Manager'
                              : 'General User';

                      return ListTile(
                        leading: const Icon(Icons.person, color: Colors.white),
                        title: Text(name.isEmpty ? 'Unnamed User' : name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('$email • $roleText', style: const TextStyle(color: Colors.white70)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              iconSize: 18,
                              onPressed: () => _showUserBottomSheet(doc.id, doc.data() as Map<String, dynamic>),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              iconSize: 18,
                              onPressed:
                                  () => _showDeleteConfirmation(
                                    context: context,
                                    title: 'Delete User',
                                    content: 'Are you sure you want to delete this user? This action cannot be undone.',
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
      return const Padding(padding: EdgeInsets.all(16.0), child: Text('No organization data available'));
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
              return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
            }

            final locations = snapshot.data?.docs ?? [];

            if (locations.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.location_city_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No locations found', style: TextStyle(color: Colors.grey)),
                    Text('Add a location to get started', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            }

            // Show all locations with scrolling if more than 4
            final locationsToShow =
                locations.map((doc) {
                  final locationData = doc.data() as Map<String, dynamic>;

                  // Debug logging
                  logger.d('[AdminDashboard] Processing location ${doc.id}: $locationData');

                  // Safe string extraction function
                  String safeGetString(dynamic value) {
                    if (value == null) return '';
                    if (value is String) return value;
                    if (value is Map) {
                      // Handle nested objects - extract any string values
                      final values = value.values.whereType<String>();
                      return values.isNotEmpty ? values.first.toString() : '';
                    }
                    return value.toString();
                  }

                  final name = safeGetString(locationData['locationName']);
                  final displayName = name.isNotEmpty ? name : 'Unnamed Location';
                  // Handle both old and new field names with safe extraction
                  final address =
                      safeGetString(locationData['street']).isNotEmpty
                          ? safeGetString(locationData['street'])
                          : safeGetString(locationData['address']);
                  final city = safeGetString(locationData['city']);

                  // Create clean address display without curly braces
                  String addressDisplay = '';
                  if (address.isNotEmpty && city.isNotEmpty) {
                    addressDisplay = '$address, $city';
                  } else if (address.isNotEmpty) {
                    addressDisplay = address;
                  } else if (city.isNotEmpty) {
                    addressDisplay = city;
                  }

                  return ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.white),
                    title: Text(displayName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      addressDisplay.isEmpty ? 'No address provided' : addressDisplay,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          iconSize: 18,
                          onPressed: () => _showLocationBottomSheet(locationId: doc.id, initialData: locationData),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          iconSize: 18,
                          onPressed:
                              () => _showDeleteConfirmation(
                                context: context,
                                title: 'Delete Location',
                                content:
                                    'Are you sure you want to delete ${displayName.isEmpty ? 'this location' : displayName}? This action cannot be undone.',
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
      return const Padding(padding: EdgeInsets.all(16.0), child: Text('No organization data available'));
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
              return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
            }

            final snapshotDocs = snapshot.data?.docs ?? [];
            final allShifts =
                snapshotDocs.map((doc) => {'id': doc.id, 'data': doc.data() as Map<String, dynamic>}).toList();

            // Filter shifts by selected location if a location is selected
            List<Map<String, dynamic>> filteredShifts = allShifts;
            if (_selectedLocationId != null) {
              filteredShifts =
                  allShifts.where((shift) {
                    final shiftData = shift['data'] as Map<String, dynamic>;
                    final docLocationIds = coerceToLocationIds(shiftData['locationIds'] ?? shiftData['locationId']);
                    return docLocationIds.contains(_selectedLocationId);
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
                      _selectedLocationId != null ? 'No shifts found for selected location' : 'No shifts found',
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

                  final name = shiftData['shiftName'] as String? ?? 'Unnamed Shift';
                  final startTime = shiftData['startTime'] ?? '';
                  final endTime = shiftData['endTime'] ?? '';
                  final roles = coerceToJobTypes(shiftData['jobTypes'] ?? shiftData['jobType']);
                  final locationIds = coerceToLocationIds(shiftData['locationIds'] ?? shiftData['locationId']);

                  // Get location names for this shift
                  final locationNames =
                      locationIds.map((id) {
                        final location = _availableLocations.firstWhere(
                          (loc) => loc['id'] == id,
                          orElse: () => {'name': 'Unknown Location'},
                        );
                        return location['name'] as String;
                      }).toList();

                  return ListTile(
                    leading: const Icon(Icons.schedule, color: Colors.white),
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_range12h(startTime, endTime)} • ${roles.join(', ')}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (locationNames.isNotEmpty)
                          Text(
                            'Locations: ${locationNames.join(', ')}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          iconSize: 18,
                          onPressed: () => _showShiftBottomSheet(shiftId, ShiftData.fromJson(shiftData)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          iconSize: 18,
                          onPressed:
                              () => _showDeleteConfirmation(
                                context: context,
                                title: 'Delete Shift',
                                content: 'Are you sure you want to delete $name? This action cannot be undone.',
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
      return const Padding(padding: EdgeInsets.all(16.0), child: Text('No organization data available'));
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
              return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
            }

            final checklists = snapshot.data?.docs ?? [];

            if (checklists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.checklist_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      _selectedLocationName != null
                          ? 'No checklists found for $_selectedLocationName'
                          : 'No checklists found',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text('Create checklists to track tasks', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              );
            }

            // Show all checklists with scrolling if more than 4
            final checklistsToShow =
                checklists.map((doc) {
                  final checklistData = doc.data() as Map<String, dynamic>;
                  final name = checklistData['name'] ?? 'Unnamed Checklist';
                  final description = checklistData['description'] ?? 'No description';
                  final tasksList = checklistData['tasks'] as List<dynamic>? ?? [];
                  final taskCount = tasksList.length;

                  return ListTile(
                    leading: const Icon(Icons.checklist, color: Colors.white),
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text('$description • $taskCount tasks', style: const TextStyle(color: Colors.white70)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          iconSize: 18,
                          onPressed: () => _showChecklistBottomSheet(doc.id, checklistData),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          iconSize: 18,
                          onPressed:
                              () => _showDeleteConfirmation(
                                context: context,
                                title: 'Delete Checklist',
                                content: 'Are you sure you want to delete $name? This action cannot be undone.',
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
                        itemBuilder: (context, index) => checklistsToShow[index],
                      ),
                    )
                    : Column(children: checklistsToShow);

            return checklistWidget;
          },
        );
      },
    );
  }

  // Bottom sheet methods
  void _showUserBottomSheet([String? userId, Map<String, dynamic>? userData]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => UserManagementBottomSheet(userId: userId, userData: userData),
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

  void _showChecklistBottomSheet([String? checklistId, Map<String, dynamic>? checklistData]) {
    // For organization-level checklists, we don't need a specific location
    if (organizationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Organization ID not available. Please try refreshing the page.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => ChecklistBottomSheet(
            organizationId: organizationId!,
            locationId: _selectedLocationId ?? 'no-location', // Use placeholder if no location
            checklistId: checklistId,
            initialData: checklistData,
            availableLocations: _availableLocations,
            onSave: (result) {
              _saveChecklist(
                checklistData: result['checklistData'],
                selectedShiftIds: List<String>.from(result['selectedShiftIds'] ?? []),
                duplicateToAll: result['duplicateToAll'] ?? false,
                existingChecklistId: checklistId,
              );
            },
          ),
    );
  }

  // Locations: add/edit using inline bottom sheet
  void _showLocationWizard() {
    if (organizationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Organization ID not available. Please try again.')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => LocationWizard(
              organizationId: organizationId!,
              onCompleted: () async {
                _triggerRefresh();
                await _loadLocations();
              },
            ),
      ),
    );
  }

  void _showLocationBottomSheet({String? locationId, Map<String, dynamic>? initialData}) {
    if (organizationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Organization ID not available. Please try again.')));
      return;
    }

    // Map initial data to old bottom sheet fields if present

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => LocationWizard(
            organizationId: organizationId!,
            locationId: locationId,
            initialData: initialData,
            onCompleted: () async {
              _triggerRefresh();
              await _loadLocations();
            },
          ),
    );
  }

  Future<void> _deleteLocation(String locationId) async {
    if (organizationId == null) return;
    try {
      final orgRef = FirestoreEnforcer.instance.collection('organizations').doc(organizationId);
      await orgRef.collection('locations').doc(locationId).delete();
      await orgRef
          .update({'locationCount': FieldValue.increment(-1), 'updatedAt': FieldValue.serverTimestamp()})
          .catchError((_) {});
      _triggerRefresh();
      await _loadLocations();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location deleted'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting location: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _saveChecklist({
    required Map<String, dynamic> checklistData,
    required List<String> selectedShiftIds,
    required bool duplicateToAll,
    String? existingChecklistId,
  }) async {
    if (organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Missing organization ID.')));
      return;
    }

    final batch = FirestoreEnforcer.instance.batch();

    // 1. Save the main checklist template at organization level
    final mainChecklistRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(organizationId)
        .collection('checklist_templates')
        .doc(existingChecklistId); // If null, a new ID is generated

    // Keep tasks on parent for backward UI, but also mirror to subcollection (canonical)
    final List<Map<String, dynamic>> tasksArray =
        (checklistData['tasks'] is List)
            ? List<Map<String, dynamic>>.from(checklistData['tasks'])
            : <Map<String, dynamic>>[];

    // Also persist a quick count for lightweight admin listings
    final checklistDocPayload = {
      ...checklistData,
      'taskCount': tasksArray.length,
      'updatedAt': FieldValue.serverTimestamp(),
      if (existingChecklistId == null) 'createdAt': FieldValue.serverTimestamp(),
    };

    batch.set(mainChecklistRef, checklistDocPayload, SetOptions(merge: true));
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
          await shiftsCollection.where('checklistTemplateIds', arrayContains: existingChecklistId).get();

      for (final shiftDoc in shiftsWithChecklistSnapshot.docs) {
        // If a shift that had the checklist is not in the new selection, remove it
        if (!selectedShiftIds.contains(shiftDoc.id)) {
          batch.update(shiftDoc.reference, {
            'checklistTemplateIds': FieldValue.arrayRemove([existingChecklistId]),
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
      // Commit parent doc + shift associations first
      await batch.commit();

      // Replace tasks in template's canonical subcollection
      final tasksColl = mainChecklistRef.collection('tasks');

      // 3a. Delete existing subcollection tasks (if any) in chunks (<=500 ops per batch)
      final existingTasksSnap = await tasksColl.get();
      if (existingTasksSnap.docs.isNotEmpty) {
        WriteBatch delBatch = FirestoreEnforcer.instance.batch();
        int opCount = 0;
        for (final doc in existingTasksSnap.docs) {
          delBatch.delete(doc.reference);
          opCount++;
          if (opCount == 450) {
            // leave headroom
            await delBatch.commit();
            delBatch = FirestoreEnforcer.instance.batch();
            opCount = 0;
          }
        }
        if (opCount > 0) {
          await delBatch.commit();
        }
      }

      // 3b. Create new subcollection tasks with stable-ish IDs based on name (+dup index)
      if (tasksArray.isNotEmpty) {
        WriteBatch addBatch = FirestoreEnforcer.instance.batch();
        int opCount = 0;
        final Map<String, int> nameCounts = {};
        for (int i = 0; i < tasksArray.length; i++) {
          final t = tasksArray[i];
          final rawName = (t['name'] ?? t['taskName'] ?? t['title'] ?? t['description'] ?? '').toString();
          final normName = rawName.trim();
          final photoRequired = (t['photoRequired'] ?? false) == true;
          final order = t['order'] is int ? t['order'] : i;

          // Track duplicates to avoid identical IDs
          final count = (nameCounts[normName.toLowerCase()] ?? 0) + 1;
          nameCounts[normName.toLowerCase()] = count;

          final idSeed = normName.isEmpty ? 'untitled-$i' : '$normName|$count';
          final hash = crypto.sha1.convert(utf8.encode(idSeed)).toString().substring(0, 16);
          final taskDocRef = tasksColl.doc(hash);

          addBatch.set(taskDocRef, {
            // Prefer canonical field names used by services
            'taskName': normName.isEmpty ? 'Untitled Task' : normName,
            'name': normName, // keep for compatibility
            'photoRequired': photoRequired,
            'order': order,
            // Optional metadata
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          opCount++;
          if (opCount == 450) {
            // commit in chunks
            await addBatch.commit();
            addBatch = FirestoreEnforcer.instance.batch();
            opCount = 0;
          }
        }
        if (opCount > 0) {
          await addBatch.commit();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Checklist saved successfully!'), backgroundColor: Colors.green));
      }
      _triggerRefresh();
      // Reseed today's existing daily checklists that reference this template so
      // newly saved template tasks appear immediately in today's UI if the
      // daily checklist was already generated earlier.
      try {
        final dcs = DailyChecklistService();
        final now = DateTime.now();
        final dateStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        final locsSnap =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(organizationId)
                .collection('locations')
                .get();
        for (final locDoc in locsSnap.docs) {
          final existingDaily =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('locations')
                  .doc(locDoc.id)
                  .collection('daily_checklists')
                  .where('date', isEqualTo: dateStr)
                  .where('checklistTemplateId', isEqualTo: mainChecklistId)
                  .get();
          for (final cd in existingDaily.docs) {
            try {
              await dcs.reseedChecklistTasksFromTemplate(
                organizationId: organizationId!,
                locationId: locDoc.id,
                checklistId: cd.id,
              );
            } catch (e) {
              logger.e('[AdminDashboard] Error reseeding checklist ${cd.id}: $e', e);
            }
          }
        }
      } catch (e) {
  logger.e('[AdminDashboard] Reseed step failed: $e', e);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save checklist: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      // Call the server-side callable 'deleteUser' to remove Auth record + Firestore doc atomically
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('deleteUser');
      final resp = await callable.call(<String, dynamic>{'uid': userId});
      final data = resp.data as Map<String, dynamic>?;

      _triggerRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data != null && data['message'] != null ? data['message'] : 'User deleted successfully'),
          ),
        );
      }
    } catch (e) {
  logger.e('[AdminDashboard] deleteUser callable error: $e', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift deleted successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting shift: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist deleted successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting checklist: $e')));
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
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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

  // Migration helper removed

  String _to12h(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h24 = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    final mm = m.toString().padLeft(2, '0');
    final suffix = h24 >= 12 ? 'pm' : 'am';
    return '$h12.$mm$suffix';
  }

  String _range12h(String startHhmm, String endHhmm) => '${_to12h(startHhmm)} – ${_to12h(endHhmm)}';
}
