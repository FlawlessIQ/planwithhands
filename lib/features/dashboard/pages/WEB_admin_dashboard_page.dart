import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';

import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/location_helper.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:hands_app/data/models/shift_data.dart';

// Bottom sheet widgets for editing
import 'package:hands_app/features/shifts/shift_template_bottom_sheet.dart';
import 'package:hands_app/ui/checklist_bottom_sheet.dart';
import 'package:hands_app/custom_code/widgets/UserManagementBottomSheet.dart';
import 'package:hands_app/ui/location_bottom_sheet_new.dart';

enum WebAdminTab { shifts, checklists, users, locations }

class WEBAdminDashboardPage extends StatefulWidget {
  final String organizationId;
  final WebAdminTab? initialTab;
  final bool usePortalLayout;

  const WEBAdminDashboardPage({super.key, required this.organizationId, this.initialTab, this.usePortalLayout = false});

  @override
  State<WEBAdminDashboardPage> createState() => _WEBAdminDashboardPageState();
}

class _WEBAdminDashboardPageState extends State<WEBAdminDashboardPage> {
  int? userRole;
  bool isLoading = true;

  // Current active tab
  late WebAdminTab _currentTab;

  // Available locations for filtering
  List<Map<String, dynamic>> _availableLocations = [];
  String? _selectedLocationId;
  String? _selectedLocationName;

  // Data caches
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _shiftDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _checklistDocs = [];

  // Lookups
  final Map<String, String> _checklistNameById = {}; // templateId -> name
  final Map<String, String> _shiftNameById = {}; // shiftId -> name
  final Map<String, List<String>> _checklistsByShiftId = {}; // shiftId -> [templateIds]
  final Map<String, List<String>> _shiftsByChecklistId = {}; // checklistTemplateId -> [shiftIds]

  // Search and filtering
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Pagination
  int _rowsPerPage = 10;
  int _currentPage = 0;

  // Sort state
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab ?? WebAdminTab.shifts;
    _checkUserAccess();
    _searchController.addListener(_onSearchChanged);
  }

  // Reload on mount after access check sets up org
  Future<void> _reloadAllTables() async {
    await Future.wait([_loadChecklistsTable(), _loadShiftsTable()]);
  }

  // --- Data loaders -------------------------------------------------------
  Future<void> _loadShiftsTable() async {
    try {
      final snap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('shifts')
              .get();
      _shiftDocs = snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

      // Build lookups
      _shiftNameById.clear();
      _checklistsByShiftId.clear();
      for (final d in _shiftDocs) {
        final data = d.data();
        final sid = d.id;
        _shiftNameById[sid] = (data['shiftName'] ?? '').toString();
        final tids = List<String>.from(data['checklistTemplateIds'] ?? const []);
        _checklistsByShiftId[sid] = tids;
      }

      // Build reverse index
      _shiftsByChecklistId.clear();
      _checklistsByShiftId.forEach((sid, tids) {
        for (final t in tids) {
          _shiftsByChecklistId.putIfAbsent(t, () => []).add(sid);
        }
      });
    } catch (e, st) {
      logger.e('[WEBAdminDashboard] _loadShiftsTable error: $e\n$st');
    }
  }

  Future<void> _loadChecklistsTable() async {
    try {
      final snap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('checklist_templates')
              .get();
      _checklistDocs = snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

      _checklistNameById.clear();
      for (final d in _checklistDocs) {
        final data = d.data();
        final name = (data['checklistName'] ?? data['name'] ?? '').toString();
        _checklistNameById[d.id] = name;
      }

      // Trigger UI update after loading checklists
      if (mounted) {
        setState(() {});
      }
    } catch (e, st) {
      logger.e('[WEBAdminDashboard] _loadChecklistsTable error: $e\n$st');
    }
  }

  String _formatSchedule(Map<String, dynamic> s) {
    final daily = s['repeatsDaily'] == true;
    final days = (s['days'] is List) ? List.from(s['days']) : <dynamic>[];

    if (daily) {
      return 'Daily';
    }

    if (days.isEmpty) {
      return '—';
    }

    mapDay(d) {
      final dd = d.toString().toLowerCase();
      if (dd.startsWith('mon') || dd == '1') return 'Mon';
      if (dd.startsWith('tue') || dd == '2') return 'Tue';
      if (dd.startsWith('wed') || dd == '3') return 'Wed';
      if (dd.startsWith('thu') || dd == '4') return 'Thu';
      if (dd.startsWith('fri') || dd == '5') return 'Fri';
      if (dd.startsWith('sat') || dd == '6') return 'Sat';
      if (dd.startsWith('sun') || dd == '0' || dd == '7') return 'Sun';
      return dd.substring(0, 3).toUpperCase();
    }

    final names = days.map(mapDay).toList();
    return names.join(' ');
  }

  Widget _locationPicker(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: _availableLocations.isNotEmpty,
      onSelected: (value) async {
        setState(() {
          _selectedLocationId = value;
          _selectedLocationName =
              _availableLocations.firstWhere((l) => l['id'] == value, orElse: () => {'name': 'Location'})['name']
                  as String?;
        });
        await _reloadAllTables();
      },
      itemBuilder:
          (context) =>
              _availableLocations.map((loc) {
                final selected = loc['id'] == _selectedLocationId;
                return PopupMenuItem<String>(
                  value: loc['id'],
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: selected ? Theme.of(context).primaryColor : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(loc['name'], overflow: TextOverflow.ellipsis)),
                      if (selected)
                        const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 14)),
                    ],
                  ),
                );
              }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 18),
            const SizedBox(width: 6),
            Text(_selectedLocationName ?? 'Select location', overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(WEBAdminDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update tab when route changes
    if (widget.initialTab != oldWidget.initialTab && widget.initialTab != null) {
      setState(() {
        _currentTab = widget.initialTab!;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _currentPage = 0; // Reset to first page when searching
    });
  }

  Future<void> _checkUserAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData == null) return;

        // Handle both old and new user data structures
        int? role;
        String? orgId;

        // Check for new structure first (roles map and orgMemberships array)
        final roles = userData['roles'] as Map<String, dynamic>?;
        final orgMemberships = userData['orgMemberships'] as List?;

        if (roles != null && orgMemberships != null) {
          // New structure: Check if user is member of this org and has admin role
          final orgIds = orgMemberships.cast<String>();
          if (orgIds.contains(widget.organizationId)) {
            final roleInOrg = roles[widget.organizationId] as String?;
            if (roleInOrg == 'admin') {
              role = 2; // Admin
              orgId = widget.organizationId;
            }
          }
        } else {
          // Legacy structure: Use userRole and organizationId fields
          role = userData['userRole'] as int? ?? 0;
          orgId = userData['organizationId'] as String?;
        }

        // Only allow admin access (userRole = 2) and require matching organizationId
        if (role != 2 || orgId != widget.organizationId) {
          logger.w(
            '[WEBAdminDashboard] Access denied: role=$role, orgId=$orgId, expectedOrgId=${widget.organizationId}',
          );
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }

        setState(() {
          userRole = role;
          isLoading = false;
        });

        await _loadLocations();
      }
    } catch (e) {
      logger.e('[WEBAdminDashboard] Error checking user access: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadLocations() async {
    try {
      logger.i('[WEBAdminDashboard] Loading locations for org: ${widget.organizationId}');

      List<Map<String, dynamic>> locations = [];

      // Query locations subcollection
      final locationsSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('locations')
              .get();

      if (locationsSnap.docs.isEmpty) {
        // Try querying locations at the root level instead of as subcollection
        final rootLocationsSnap =
            await FirestoreEnforcer.instance
                .collection('locations')
                .where('organizationId', isEqualTo: widget.organizationId)
                .get();

        if (rootLocationsSnap.docs.isNotEmpty) {
          locations =
              rootLocationsSnap.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['locationName'] ?? data['name'] ?? 'Unnamed Location',
                  'isPrimary': data['isPrimary'] ?? false,
                };
              }).toList();
        }
      } else {
        locations =
            locationsSnap.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['locationName'] ?? data['name'] ?? 'Unnamed Location',
                'isPrimary': data['isPrimary'] ?? false,
              };
            }).toList();
      }

      // Sort primary first
      locations.sort((a, b) {
        if (a['isPrimary'] == true && b['isPrimary'] != true) return -1;
        if (b['isPrimary'] == true && a['isPrimary'] != true) return 1;
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      setState(() {
        _availableLocations = locations;
        if ((_selectedLocationId == null || !_availableLocations.any((l) => l['id'] == _selectedLocationId)) &&
            _availableLocations.isNotEmpty) {
          final primary = _availableLocations.firstWhere(
            (l) => l['isPrimary'] == true,
            orElse: () => _availableLocations.first,
          );
          _selectedLocationId = primary['id'] as String?;
          _selectedLocationName = primary['name'] as String?;
        }
      });

      // Reload dependent tables
      await _reloadAllTables();
    } catch (e, stackTrace) {
      logger.e('[WEBAdminDashboard] Error loading locations: $e');
      logger.e('[WEBAdminDashboard] Stack trace: $stackTrace');

      // Set empty locations to avoid infinite loading
      setState(() {
        _availableLocations = [];
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? HandsColors.error : HandsColors.sageGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showEditDialog(Widget child) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(color: HandsColors.scaffoldBackground, borderRadius: BorderRadius.circular(12)),
              child: child,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: HandsColors.scaffoldBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(appBarTitle: 'Admin Dashboard', userRole: userRole),
        automaticallyImplyLeading: false,
        actions: [
          // Location selector dropdown
          if (_availableLocations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PopupMenuButton<String>(
                enabled: _availableLocations.isNotEmpty,
                onSelected: (value) {
                  setState(() {
                    _selectedLocationId = value;
                    _selectedLocationName =
                        _availableLocations.firstWhere(
                              (loc) => loc['id'] == value,
                              orElse: () => {'name': 'Unknown Location'},
                            )['name']
                            as String?;
                  });
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
                                          ? HandsColors.handsOrange
                                          : HandsColors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location['name'],
                                    style: GoogleFonts.comfortaa(
                                      fontWeight:
                                          location['id'] == _selectedLocationId ? FontWeight.bold : FontWeight.normal,
                                      color: HandsColors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (location['id'] == _selectedLocationId)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.check, color: HandsColors.handsOrange, size: 16),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: HandsColors.handsOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: HandsColors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _selectedLocationName?.isNotEmpty == true ? _selectedLocationName! : 'Select Location',
                        style: GoogleFonts.comfortaa(
                          color: HandsColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: HandsColors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // Unified menu button
          UnifiedMenuButton(userRole: userRole),
        ],
      ),
      body: Row(
        children: [
          // Left Navigation Bar
          _buildLeftNavigation(),
          // Main Content Area
          Expanded(child: Column(children: [_buildFilterBar(), Expanded(child: _buildMainContent())])),
        ],
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 2, userRole: userRole), // Admin tab is index 2
    );
  }

  Widget _buildLeftNavigation() {
    return Container(
      width: 250,
      color: HandsColors.cardPrimary, // Same charcoal color as header
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: HandsColors.white12, width: 1))),
            child: Text(
              'ADMIN SETUP',
              style: GoogleFonts.comfortaa(
                color: HandsColors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  icon: Icons.schedule,
                  label: 'Shifts',
                  tab: WebAdminTab.shifts,
                  isActive: _currentTab == WebAdminTab.shifts,
                ),
                _buildNavItem(
                  icon: Icons.checklist,
                  label: 'Checklists',
                  tab: WebAdminTab.checklists,
                  isActive: _currentTab == WebAdminTab.checklists,
                ),
                _buildNavItem(
                  icon: Icons.people,
                  label: 'Users',
                  tab: WebAdminTab.users,
                  isActive: _currentTab == WebAdminTab.users,
                ),
                _buildNavItem(
                  icon: Icons.location_on,
                  label: 'Locations',
                  tab: WebAdminTab.locations,
                  isActive: _currentTab == WebAdminTab.locations,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required WebAdminTab tab,
    required bool isActive,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive ? HandsColors.handsOrange.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _currentTab = tab;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: isActive ? HandsColors.handsOrange : HandsColors.white70, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.comfortaa(
                    color: isActive ? HandsColors.handsOrange : HandsColors.white70,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // _buildTabButton removed - admin left sidebar removed so these tab buttons are no longer needed

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HandsColors.cardPrimary,
        border: Border(bottom: BorderSide(color: HandsColors.white12, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Search field
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.comfortaa(color: HandsColors.white),
                  decoration: InputDecoration(
                    hintText: 'Search ${_getTabDisplayName()}...',
                    hintStyle: GoogleFonts.comfortaa(color: HandsColors.white30),
                    prefixIcon: const Icon(Icons.search, color: HandsColors.white30),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear, color: HandsColors.white30),
                              onPressed: () => _searchController.clear(),
                            )
                            : null,
                    filled: true,
                    fillColor: HandsColors.secondaryContainer,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Add new button
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: Text('Add ${_getTabDisplayName(singular: true)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HandsColors.handsOrange,
                  foregroundColor: HandsColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          // Location filter for mobile/smaller screens (if needed)
          if (_shouldShowLocationFilter() && MediaQuery.of(context).size.width < 1200) ...[
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft, child: SizedBox(width: 250, child: _locationPicker(context))),
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        return _buildShiftsTable();
      case WebAdminTab.checklists:
        return _buildChecklistsTable();
      case WebAdminTab.users:
        return _buildUsersTable();
      case WebAdminTab.locations:
        return _buildLocationsTable();
    }
  }

  Widget _buildShiftsTable() {
    // Only wait for checklists to load - locations might be empty
    // Don't block on locations being empty since that's a valid state
    if (_checklistNameById.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading checklist data...')],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('shifts')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        List<Map<String, dynamic>> shifts =
            docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              // Try multiple possible field names for locations
              List<dynamic> locationIds = [];
              if (data['locationIds'] != null) {
                final rawIds = data['locationIds'];
                if (rawIds is List) {
                  locationIds = rawIds;
                } else {
                  locationIds = [rawIds];
                }
              } else if (data['locations'] != null) {
                final rawLocs = data['locations'];
                if (rawLocs is List) {
                  locationIds = rawLocs;
                } else {
                  locationIds = [rawLocs];
                }
              } else if (data['location'] != null) {
                locationIds = [data['location']];
              }

              // Try multiple possible field names for checklists
              List<dynamic> checklistIds = [];
              if (data['checklistTemplateIds'] != null) {
                final rawIds = data['checklistTemplateIds'];
                if (rawIds is List) {
                  checklistIds = rawIds;
                } else {
                  checklistIds = [rawIds];
                }
              } else if (data['checklists'] != null) {
                final rawChecklists = data['checklists'];
                if (rawChecklists is List) {
                  checklistIds = rawChecklists;
                } else {
                  checklistIds = [rawChecklists];
                }
              } else if (data['checklistIds'] != null) {
                final rawIds = data['checklistIds'];
                if (rawIds is List) {
                  checklistIds = rawIds;
                } else {
                  checklistIds = [rawIds];
                }
              }

              // Try multiple possible field names for shift name
              String shiftName = '';
              if (data['shiftName'] != null && data['shiftName'].toString().isNotEmpty) {
                shiftName = data['shiftName'].toString();
              } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
                shiftName = data['name'].toString();
              } else {
                shiftName = 'Unnamed Shift';
              }

              return {
                'id': doc.id,
                'name': shiftName,
                'startTime': data['startTime'] ?? '',
                'endTime': data['endTime'] ?? '',
                'locations': locationIds,
                'checklists': checklistIds,
                'active': data['isActive'] ?? data['active'] ?? true,
                'createdAt': data['createdAt'],
                ...data,
              };
            }).toList();

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          shifts =
              shifts.where((shift) {
                return shift['name'].toString().toLowerCase().contains(_searchQuery);
              }).toList();
        }

        if (_selectedLocationId != null) {
          shifts =
              shifts.where((shift) {
                final locationIds = shift['locations'] as List? ?? [];
                return locationIds.contains(_selectedLocationId);
              }).toList();
        }

        // Sort
        if (_sortColumnIndex != null) {
          shifts.sort((a, b) {
            dynamic valueA, valueB;
            switch (_sortColumnIndex) {
              case 0:
                valueA = a['name'];
                valueB = b['name'];
                break;
              case 1: // Time column - sort by start time
                valueA = a['startTime'];
                valueB = b['startTime'];
                break;
              default:
                valueA = a['name'];
                valueB = b['name'];
            }

            int comparison = valueA.toString().compareTo(valueB.toString());
            return _sortAscending ? comparison : -comparison;
          });
        }

        return _buildDataTable(
          columns: [
            DataColumn(
              label: const Text('Shift Name'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            DataColumn(
              label: const Text('Time'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            const DataColumn(label: Text('Checklists')),
            const DataColumn(label: Text('Schedule')),
            const DataColumn(label: Text('Locations')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: shifts,
          buildRow: (shift) => _buildShiftRow(shift),
        );
      },
    );
  }

  DataRow _buildShiftRow(Map<String, dynamic> shift) {
    final locationIds =
        (shift['locations'] as List? ?? []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    final locationNames = locationIds
        .map((id) {
          final location = _availableLocations.firstWhere(
            (loc) => loc['id'] == id,
            orElse: () => {'name': 'Unknown Location'},
          );
          return location['name'] as String;
        })
        .where((name) => name.isNotEmpty)
        .join(', ');

    // Format time as "10:00am - 3:00pm"
    String formatTime(String time) {
      if (time.isEmpty) return '';
      try {
        final parts = time.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          String minute = parts[1];
          String period = hour >= 12 ? 'pm' : 'am';
          if (hour > 12) hour -= 12;
          if (hour == 0) hour = 12;
          return '$hour:$minute$period';
        }
      } catch (e) {
        // If parsing fails, return original time
      }
      return time;
    }

    final startTime = formatTime(shift['startTime'] ?? '');
    final endTime = formatTime(shift['endTime'] ?? '');
    final timeRange = (startTime.isNotEmpty && endTime.isNotEmpty) ? '$startTime - $endTime' : '$startTime$endTime';

    return DataRow(
      cells: [
        DataCell(
          SizedBox(width: 150, child: Text(shift['name'], style: GoogleFonts.comfortaa(color: HandsColors.white))),
        ),
        DataCell(Text(timeRange, style: GoogleFonts.comfortaa(color: HandsColors.white70))),
        DataCell(
          // Checklists column: display as simple comma-separated text
          Builder(
            builder: (context) {
              final tids =
                  (shift['checklists'] as List? ?? []).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
              final names = tids.map((t) => _checklistNameById[t] ?? 'Unknown Checklist').toList();

              return SizedBox(
                width: 250, // Constrains the width, forcing text to wrap
                child: Text(
                  names.isEmpty ? 'No Checklists' : names.join(', '),
                  style: GoogleFonts.comfortaa(color: HandsColors.white70),
                ),
              );
            },
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Text(_formatSchedule(shift), style: GoogleFonts.comfortaa(color: HandsColors.white70)),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150, // Give it a width to wrap
            child: Text(
              locationNames.isNotEmpty ? locationNames : 'No locations',
              style: GoogleFonts.comfortaa(color: HandsColors.white70),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: shift['active'] ? HandsColors.sageGreen : HandsColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              shift['active'] ? 'Active' : 'Inactive',
              style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: HandsColors.handsOrange, size: 20),
                onPressed: () => _editShift(shift),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: HandsColors.white70, size: 20),
                onPressed: () => _duplicateShift(shift),
                tooltip: 'Duplicate',
              ),
              IconButton(
                icon: Icon(shift['active'] ? Icons.archive : Icons.unarchive, color: HandsColors.amber, size: 20),
                onPressed: () => _toggleShiftActive(shift),
                tooltip: shift['active'] ? 'Archive' : 'Restore',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistsTable() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('checklist_templates')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        List<Map<String, dynamic>> checklists =
            docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final tasks = data['tasks'] as List? ?? [];

              return {
                'id': doc.id,
                'name': data['checklistName'] ?? data['name'] ?? 'Unnamed Checklist',
                'description': data['checklistDescription'] ?? data['description'] ?? '',
                'taskCount': tasks.length,
                'createdAt': data['createdAt'],
                ...data,
              };
            }).toList();

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          checklists =
              checklists.where((checklist) {
                return checklist['name'].toString().toLowerCase().contains(_searchQuery) ||
                    checklist['description'].toString().toLowerCase().contains(_searchQuery);
              }).toList();
        }

        // Sort
        if (_sortColumnIndex != null) {
          checklists.sort((a, b) {
            dynamic valueA, valueB;
            switch (_sortColumnIndex) {
              case 0:
                valueA = a['name'];
                valueB = b['name'];
                break;
              case 1:
                valueA = a['taskCount'];
                valueB = b['taskCount'];
                break;
              default:
                valueA = a['name'];
                valueB = b['name'];
            }

            int comparison;
            if (valueA is int && valueB is int) {
              comparison = valueA.compareTo(valueB);
            } else {
              comparison = valueA.toString().compareTo(valueB.toString());
            }
            return _sortAscending ? comparison : -comparison;
          });
        }

        return _buildDataTable(
          columns: [
            DataColumn(
              label: const Text('Checklist Name'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            const DataColumn(label: Text('Description')),
            DataColumn(
              label: const Text('Tasks'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
              numeric: true,
            ),
            const DataColumn(label: Text('Actions')),
            const DataColumn(label: Text('Used in Shifts')),
          ],
          rows: checklists,
          buildRow: (checklist) => _buildChecklistRow(checklist),
        );
      },
    );
  }

  DataRow _buildChecklistRow(Map<String, dynamic> checklist) {
    return DataRow(
      cells: [
        DataCell(Text(checklist['name'], style: GoogleFonts.comfortaa(color: HandsColors.white))),
        DataCell(
          Text(
            checklist['description'].isNotEmpty ? checklist['description'] : 'No description',
            style: GoogleFonts.comfortaa(color: HandsColors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(Text('${checklist['taskCount']} tasks', style: GoogleFonts.comfortaa(color: HandsColors.white70))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: HandsColors.handsOrange, size: 20),
                onPressed: () => _editChecklist(checklist),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: HandsColors.white70, size: 20),
                onPressed: () => _duplicateChecklist(checklist),
                tooltip: 'Duplicate',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: HandsColors.error, size: 20),
                onPressed: () => _deleteChecklist(checklist),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
        DataCell(
          Builder(
            builder: (context) {
              // Filter used shifts by selected location
              final used = _shiftsByChecklistId[checklist['id']] ?? const [];
              List<String> filteredUsed = used;
              if (_selectedLocationId != null) {
                filteredUsed =
                    used.where((sid) {
                      final shiftDoc = _shiftDocs.firstWhere(
                        (s) => s.id == sid,
                        orElse: () => throw Exception('Not found'),
                      );
                      final shiftData = shiftDoc.data();
                      final locationIds = List<String>.from(shiftData['locationIds'] ?? const []);
                      return locationIds.contains(_selectedLocationId);
                    }).toList();
              }
              final labels = filteredUsed.map((sid) => _shiftNameById[sid] ?? 'Shift').toList();
              if (labels.isEmpty) return Text('—', style: GoogleFonts.comfortaa(color: HandsColors.white70));
              if (labels.length <= 3) {
                return Text(labels.join(', '), style: GoogleFonts.comfortaa(color: HandsColors.white70));
              }
              return Text(
                '${labels.take(3).join(', ')} +${labels.length - 3}',
                style: GoogleFonts.comfortaa(color: HandsColors.white70),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTable() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirestoreEnforcer.instance
              .collection('users')
              .where('organizationId', isEqualTo: widget.organizationId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        List<Map<String, dynamic>> users =
            docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
              final locationIds = coerceToLocationIds(data['locationIds'] ?? data['locationId']);

              // Safely convert userRole to int, handling both String and int types
              int userRole = 0;
              final roleData = data['userRole'] ?? data['role'];
              if (roleData is int) {
                userRole = roleData;
              } else if (roleData is String) {
                userRole = int.tryParse(roleData) ?? 0;
              }

              // Create clean user data with converted types
              final cleanData = Map<String, dynamic>.from(data);
              cleanData.remove('role'); // Remove original role to prevent conflicts

              return {
                'id': doc.id,
                'name': name.isNotEmpty ? name : 'Unknown User',
                'email': data['emailAddress'] ?? data['userEmail'] ?? data['email'] ?? 'No email',
                'role': userRole,
                'userRole': userRole, // Include both for compatibility
                'locationIds': locationIds,
                'jobTypes': coerceToJobTypes(data['jobTypes'] ?? data['jobType']),
                'isActive': data['isActive'] ?? true,
                'createdAt': data['createdAt'],
                ...cleanData,
              };
            }).toList();

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          users =
              users.where((user) {
                return user['name'].toString().toLowerCase().contains(_searchQuery) ||
                    user['email'].toString().toLowerCase().contains(_searchQuery);
              }).toList();
        }

        if (_selectedLocationId != null) {
          users =
              users.where((user) {
                final locationIds = user['locationIds'] as List? ?? [];
                final role = user['role'] as int? ?? 0;
                // Always show admins, filter others by location
                return role == 2 || locationIds.contains(_selectedLocationId);
              }).toList();
        }

        // Sort
        if (_sortColumnIndex != null) {
          users.sort((a, b) {
            dynamic valueA, valueB;
            switch (_sortColumnIndex) {
              case 0:
                valueA = a['name'];
                valueB = b['name'];
                break;
              case 1:
                valueA = a['email'];
                valueB = b['email'];
                break;
              case 2:
                valueA = a['role'];
                valueB = b['role'];
                break;
              default:
                valueA = a['name'];
                valueB = b['name'];
            }

            int comparison;
            if (valueA is int && valueB is int) {
              comparison = valueA.compareTo(valueB);
            } else {
              comparison = valueA.toString().compareTo(valueB.toString());
            }
            return _sortAscending ? comparison : -comparison;
          });
        }

        return _buildDataTable(
          columns: [
            DataColumn(
              label: const Text('Name'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            DataColumn(
              label: const Text('Email'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            DataColumn(
              label: const Text('Role'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            const DataColumn(label: Text('Locations')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Actions')),
            const DataColumn(label: Text('Delete')),
          ],
          rows: users,
          buildRow: (user) => _buildUserRow(user),
        );
      },
    );
  }

  DataRow _buildUserRow(Map<String, dynamic> user) {
    final locationIds = user['locationIds'] as List? ?? [];
    final locationNames = locationIds
        .map((id) {
          final location = _availableLocations.firstWhere((loc) => loc['id'] == id, orElse: () => {'name': 'Unknown'});
          return location['name'];
        })
        .join(', ');

    final role = user['role'] as int? ?? 0;
    final roleText = role == 2 ? 'Admin' : (role == 1 ? 'Manager' : 'User');

    return DataRow(
      cells: [
        DataCell(Text(user['name'], style: GoogleFonts.comfortaa(color: HandsColors.white))),
        DataCell(Text(user['email'], style: GoogleFonts.comfortaa(color: HandsColors.white70))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: role == 2 ? HandsColors.handsOrange : (role == 1 ? HandsColors.amber : HandsColors.sageGreen),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              roleText,
              style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        DataCell(
          Text(
            locationNames.isNotEmpty ? locationNames : 'No locations',
            style: GoogleFonts.comfortaa(color: HandsColors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: user['isActive'] ? HandsColors.sageGreen : HandsColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user['isActive'] ? 'Active' : 'Inactive',
              style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: HandsColors.handsOrange, size: 20),
                onPressed: () => _editUser(user),
                tooltip: 'Edit',
              ),
              if (role < 2) // Don't allow archiving admins
                IconButton(
                  icon: Icon(user['isActive'] ? Icons.archive : Icons.unarchive, color: HandsColors.amber, size: 20),
                  onPressed: () => _toggleUserActive(user),
                  tooltip: user['isActive'] ? 'Deactivate' : 'Activate',
                ),
            ],
          ),
        ),
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete, color: HandsColors.error),
            tooltip: 'Delete user',
            onPressed: () async {
              final ok =
                  await showDialog<bool>(
                    context: context,
                    builder:
                        (_) => AlertDialog(
                          title: const Text('Delete user?'),
                          content: const Text('This action cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                  ) ??
                  false;
              if (!ok) return;
              await _deleteUser(user['id']);
              // Data will be updated automatically via StreamBuilder
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationsTable() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('locations')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          logger.e('[WEBAdminDashboard] StreamBuilder error for locations: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          logger.i('[WEBAdminDashboard] Waiting for locations stream...');
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        logger.i('[WEBAdminDashboard] StreamBuilder received ${docs.length} location documents');

        List<Map<String, dynamic>> locations =
            docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              logger.d('[WEBAdminDashboard] Processing location: ${doc.id} -> $data');

              // Try multiple possible field names for location name
              String locationName = '';
              if (data['name'] != null && data['name'].toString().isNotEmpty) {
                locationName = data['name'].toString();
              } else if (data['locationName'] != null && data['locationName'].toString().isNotEmpty) {
                locationName = data['locationName'].toString();
              } else {
                locationName = 'Unnamed Location';
              }

              // Try multiple possible field names for address
              String address = '';
              if (data['address'] != null && data['address'].toString().isNotEmpty) {
                address = data['address'].toString();
              } else if (data['locationAddress'] != null && data['locationAddress'].toString().isNotEmpty) {
                address = data['locationAddress'].toString();
              } else {
                address = 'No address';
              }

              return {
                'id': doc.id,
                'name': locationName,
                'address': address,
                'isActive': data['isActive'] ?? data['active'] ?? true,
                'isPrimary': data['isPrimary'] ?? false,
                'createdAt': data['createdAt'],
                ...data,
              };
            }).toList();

        logger.i('[WEBAdminDashboard] Total locations after processing: ${locations.length}');

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          locations =
              locations.where((location) {
                return location['name'].toString().toLowerCase().contains(_searchQuery) ||
                    location['address'].toString().toLowerCase().contains(_searchQuery);
              }).toList();
        }

        // Sort
        if (_sortColumnIndex != null) {
          locations.sort((a, b) {
            dynamic valueA, valueB;
            switch (_sortColumnIndex) {
              case 0:
                valueA = a['name'];
                valueB = b['name'];
                break;
              case 1:
                valueA = a['address'];
                valueB = b['address'];
                break;
              default:
                valueA = a['name'];
                valueB = b['name'];
            }

            int comparison = valueA.toString().compareTo(valueB.toString());
            return _sortAscending ? comparison : -comparison;
          });
        }

        return _buildDataTable(
          columns: [
            DataColumn(
              label: const Text('Location Name'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            DataColumn(
              label: const Text('Address'),
              onSort: (columnIndex, ascending) {
                setState(() {
                  _sortColumnIndex = columnIndex;
                  _sortAscending = ascending;
                });
              },
            ),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: locations,
          buildRow: (location) => _buildLocationRow(location),
        );
      },
    );
  }

  DataRow _buildLocationRow(Map<String, dynamic> location) {
    return DataRow(
      cells: [
        DataCell(Text(location['name'], style: GoogleFonts.comfortaa(color: HandsColors.white))),
        DataCell(
          Text(
            location['address'],
            style: GoogleFonts.comfortaa(color: HandsColors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: location['isActive'] ? HandsColors.sageGreen : HandsColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              location['isActive'] ? 'Active' : 'Inactive',
              style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: HandsColors.handsOrange, size: 20),
                onPressed: () => _editLocation(location),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(location['isActive'] ? Icons.archive : Icons.unarchive, color: HandsColors.amber, size: 20),
                onPressed: () => _toggleLocationActive(location),
                tooltip: location['isActive'] ? 'Archive' : 'Restore',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: HandsColors.error, size: 20),
                onPressed: () => _deleteLocation(location),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable({
    required List<DataColumn> columns,
    required List<Map<String, dynamic>> rows,
    required DataRow Function(Map<String, dynamic>) buildRow,
  }) {
    final paginatedRows = _paginateRows(rows);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, // Allow horizontal scrolling
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 1000, // Increased min width for better spacing
              ),
              child: DataTable(
                columnSpacing: 8, // Reduced from 12 to 8
                horizontalMargin: 8, // Reduced from 12 to 8
                headingRowHeight: 48,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 56,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                headingRowColor: WidgetStateProperty.all(HandsColors.cardPrimary),
                dataRowColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) ? HandsColors.secondaryContainer : Colors.transparent;
                }),
                headingTextStyle: GoogleFonts.comfortaa(
                  color: HandsColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13, // Reduced from 14
                ),
                dataTextStyle: GoogleFonts.comfortaa(
                  color: HandsColors.white70,
                  fontSize: 12, // Reduced from 13
                ),
                showBottomBorder: true,
                dividerThickness: 1,
                columns: columns,
                rows: paginatedRows.map(buildRow).toList(),
              ),
            ),
          ),
        ),
        _buildPaginationControls(rows.length),
      ],
    );
  }

  List<Map<String, dynamic>> _paginateRows(List<Map<String, dynamic>> rows) {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, rows.length);

    if (startIndex >= rows.length) {
      return [];
    }

    return rows.sublist(startIndex, endIndex);
  }

  Widget _buildPaginationControls(int totalRows) {
    final totalPages = (totalRows / _rowsPerPage).ceil();
    final hasNextPage = _currentPage < totalPages - 1;
    final hasPreviousPage = _currentPage > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HandsColors.cardPrimary,
        border: Border(top: BorderSide(color: HandsColors.white12, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${_currentPage * _rowsPerPage + 1}-${((_currentPage + 1) * _rowsPerPage).clamp(1, totalRows)} of $totalRows',
            style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 12),
          ),
          Row(
            children: [
              DropdownButton<int>(
                value: _rowsPerPage,
                items:
                    [5, 10, 25, 50, 100].map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text('$value per page', style: GoogleFonts.comfortaa(color: HandsColors.white)),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _rowsPerPage = value;
                      _currentPage = 0;
                    });
                  }
                },
                dropdownColor: HandsColors.primaryContainer,
                underline: const SizedBox(),
              ),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: hasPreviousPage ? HandsColors.white : HandsColors.white30,
                onPressed: hasPreviousPage ? () => setState(() => _currentPage--) : null,
              ),
              Text(
                'Page ${_currentPage + 1} of $totalPages',
                style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: hasNextPage ? HandsColors.white : HandsColors.white30,
                onPressed: hasNextPage ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // _buildEditDrawer removed - edit drawer was unused after removing the admin sidebar

  String _getTabDisplayName({bool singular = false}) {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        return singular ? 'Shift' : 'Shifts';
      case WebAdminTab.checklists:
        return singular ? 'Checklist' : 'Checklists';
      case WebAdminTab.users:
        return singular ? 'User' : 'Users';
      case WebAdminTab.locations:
        return singular ? 'Location' : 'Locations';
    }
  }

  bool _shouldShowLocationFilter() {
    return _currentTab == WebAdminTab.shifts || _currentTab == WebAdminTab.users;
  }

  ShiftData? _mapToShiftData(Map<String, dynamic> shiftMap) {
    try {
      return ShiftData(
        shiftId: shiftMap['id'] ?? '',
        shiftName: shiftMap['name'] ?? 'Unnamed Shift',
        createdAt: shiftMap['createdAt']?.toDate() ?? DateTime.now(),
        startTime: shiftMap['startTime'] ?? '',
        endTime: shiftMap['endTime'] ?? '',
        organizationId: widget.organizationId,
        locationIds: List<String>.from(shiftMap['locations'] ?? []),
        checklistTemplateIds: List<String>.from(shiftMap['checklists'] ?? []),
        jobType: List<String>.from(shiftMap['jobType'] ?? []),
        staffingLevels: Map<String, int>.from(shiftMap['staffingLevels'] ?? {}),
        days: List<String>.from(shiftMap['days'] ?? []),
        repeatsDaily: shiftMap['repeatsDaily'] ?? false,
        activeDays: List<int>.from(shiftMap['activeDays'] ?? []),
        assignedUserIds: List<String>.from(shiftMap['assignedUserIds'] ?? []),
        volunteers: List<String>.from(shiftMap['volunteers'] ?? []),
        published: shiftMap['published'] ?? false,
        shiftDate: shiftMap['shiftDate']?.toDate(),
        updatedAt: shiftMap['updatedAt']?.toDate(),
      );
    } catch (e) {
      logger.e('[WEBAdminDashboard] Error mapping shift data: $e');
      return null;
    }
  }

  // Action methods
  void _showCreateDialog() {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        _editShift(null);
        break;
      case WebAdminTab.checklists:
        _editChecklist(null);
        break;
      case WebAdminTab.users:
        _editUser(null);
        break;
      case WebAdminTab.locations:
        _editLocation(null);
        break;
    }
  }

  void _editShift(Map<String, dynamic>? shift) {
    _showEditDialog(
      ShiftTemplateBottomSheet(
        organizationId: widget.organizationId,
        shiftId: shift?['id'],
        shiftData: shift != null ? _mapToShiftData(shift) : null,
        availableLocations: _availableLocations,
        onShiftSaved: () {
          Navigator.of(context).pop();
          _showSnackBar(shift == null ? 'Shift created successfully' : 'Shift updated successfully');
        },
      ),
    );
  }

  void _duplicateShift(Map<String, dynamic> shift) async {
    try {
      // Create a copy without the ID
      final newShiftData = Map<String, dynamic>.from(shift);
      newShiftData.remove('id');
      newShiftData['shiftName'] = '${shift['name']} (Copy)';
      newShiftData['createdAt'] = FieldValue.serverTimestamp();

      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('shifts')
          .add(newShiftData);

      _showSnackBar('Shift duplicated successfully');
    } catch (e) {
      _showSnackBar('Failed to duplicate shift: $e', isError: true);
    }
  }

  void _toggleShiftActive(Map<String, dynamic> shift) async {
    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('shifts')
          .doc(shift['id'])
          .update({'isActive': !shift['active']});

      _showSnackBar('Shift ${shift['active'] ? 'archived' : 'restored'} successfully');
    } catch (e) {
      _showSnackBar('Failed to update shift: $e', isError: true);
    }
  }

  void _editChecklist(Map<String, dynamic>? checklist) {
    _showEditDialog(
      ChecklistBottomSheet(
        organizationId: widget.organizationId,
        locationId: _selectedLocationId ?? _availableLocations.first['id'] ?? '',
        checklistId: checklist?['id'],
        initialData: checklist,
        availableLocations: _availableLocations,
        onSave: (checklistData) {
          Navigator.of(context).pop();
          _showSnackBar(checklist == null ? 'Checklist created successfully' : 'Checklist updated successfully');
        },
      ),
    );
  }

  void _duplicateChecklist(Map<String, dynamic> checklist) async {
    try {
      final newChecklistData = Map<String, dynamic>.from(checklist);
      newChecklistData.remove('id');
      newChecklistData['checklistName'] = '${checklist['name']} (Copy)';
      newChecklistData['createdAt'] = FieldValue.serverTimestamp();

      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('checklist_templates')
          .add(newChecklistData);

      _showSnackBar('Checklist duplicated successfully');
    } catch (e) {
      _showSnackBar('Failed to duplicate checklist: $e', isError: true);
    }
  }

  void _deleteChecklist(Map<String, dynamic> checklist) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: HandsColors.cardPrimary,
            title: Text('Delete Checklist', style: GoogleFonts.comfortaa(color: HandsColors.white)),
            content: Text(
              'Are you sure you want to delete "${checklist['name']}"? This action cannot be undone.',
              style: GoogleFonts.comfortaa(color: HandsColors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: GoogleFonts.comfortaa(color: HandsColors.white70)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete', style: GoogleFonts.comfortaa(color: HandsColors.error)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('checklist_templates')
            .doc(checklist['id'])
            .delete();

        _showSnackBar('Checklist deleted successfully');
      } catch (e) {
        _showSnackBar('Failed to delete checklist: $e', isError: true);
      }
    }
  }

  void _editUser(Map<String, dynamic>? user) {
    _showEditDialog(UserManagementBottomSheet(userData: user, userId: user?['id']));
  }

  void _toggleUserActive(Map<String, dynamic> user) async {
    try {
      await FirestoreEnforcer.instance.collection('users').doc(user['id']).update({'isActive': !user['isActive']});

      _showSnackBar('User ${user['isActive'] ? 'deactivated' : 'activated'} successfully');
    } catch (e) {
      _showSnackBar('Failed to update user: $e', isError: true);
    }
  }

  void _editLocation(Map<String, dynamic>? location) {
    _showEditDialog(
      LocationWizard(
        organizationId: widget.organizationId,
        locationId: location?['id'],
        initialData: location,
        onCompleted: () {
          Navigator.of(context).pop();
          _showSnackBar(location == null ? 'Location created successfully' : 'Location updated successfully');
          _loadLocations(); // Refresh locations list
        },
      ),
    );
  }

  void _toggleLocationActive(Map<String, dynamic> location) async {
    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('locations')
          .doc(location['id'])
          .update({'isActive': !location['isActive']});

      _showSnackBar('Location ${location['isActive'] ? 'archived' : 'restored'} successfully');
    } catch (e) {
      _showSnackBar('Failed to update location: $e', isError: true);
    }
  }

  void _deleteLocation(Map<String, dynamic> location) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: HandsColors.cardPrimary,
            title: Text('Delete Location', style: GoogleFonts.comfortaa(color: HandsColors.white)),
            content: Text(
              'Are you sure you want to delete "${location['name']}"? This action cannot be undone and will affect any shifts or users assigned to this location.',
              style: GoogleFonts.comfortaa(color: HandsColors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: GoogleFonts.comfortaa(color: HandsColors.white70)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete', style: GoogleFonts.comfortaa(color: HandsColors.error)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('locations')
            .doc(location['id'])
            .delete();

        _showSnackBar('Location deleted successfully');

        // Refresh locations list and reload tables
        await _loadLocations();
      } catch (e) {
        _showSnackBar('Failed to delete location: $e', isError: true);
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      logger.d('[WEBAdminDashboard] Starting user deletion for userId: $userId');

      // Call server-side callable 'deleteUser' to remove Auth record + Firestore doc atomically
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('deleteUser');

      logger.d('[WEBAdminDashboard] Calling deleteUser function with uid: $userId');

      final resp = await callable.call(<String, dynamic>{'uid': userId});
      final data = resp.data as Map<String, dynamic>?;

      logger.d('[WEBAdminDashboard] deleteUser function response: $data');

      await _reloadAllTables();
      if (mounted) {
        _showSnackBar(data != null && data['message'] != null ? data['message'] : 'User deleted successfully');
      }
    } on FirebaseFunctionsException catch (e) {
      logger.e(
        '[WEBAdminDashboard] FirebaseFunctionsException: code=${e.code}, message=${e.message}, details=${e.details}',
        e,
      );

      // If the function doesn't exist or fails, try fallback deletion (Firestore only)
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        logger.w('[WEBAdminDashboard] Cloud function not found, attempting Firestore-only deletion');
        await _deleteUserFallback(userId);
      } else {
        if (mounted) {
          _showSnackBar('Error deleting user: ${e.message} (Code: ${e.code})', isError: true);
        }
      }
    } catch (e) {
      logger.e('[WEBAdminDashboard] deleteUser callable error: $e', e);

      // Try fallback deletion
      logger.w('[WEBAdminDashboard] Attempting fallback Firestore-only deletion');
      await _deleteUserFallback(userId);
    }
  }

  Future<void> _deleteUserFallback(String userId) async {
    try {
      logger.d('[WEBAdminDashboard] Starting fallback user deletion for userId: $userId');

      // Delete user document from Firestore (Auth record will remain)
      await FirestoreEnforcer.instance.collection('users').doc(userId).delete();

      logger.d('[WEBAdminDashboard] User document deleted from Firestore: $userId');

      await _reloadAllTables();
      if (mounted) {
        _showSnackBar('User deleted from database. Note: Authentication record may still exist.');
      }
    } catch (e) {
      logger.e('[WEBAdminDashboard] Fallback deletion error: $e', e);
      if (mounted) {
        _showSnackBar('Failed to delete user: $e', isError: true);
      }
    }
  }
}
