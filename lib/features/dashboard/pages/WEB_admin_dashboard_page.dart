import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/services/activity_tracker.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/widgets/welcome_organization_dialog.dart';
import 'package:hands_app/widgets/hands_text_field.dart';

import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/utils/location_helper.dart';
import 'package:hands_app/utils/jobtype_helper.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/widgets/pending_invites_panel.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/features/help/widgets/context_help_trigger.dart';
import 'package:hands_app/features/help/models/guided_tour_step.dart';
import 'package:hands_app/features/help/widgets/guided_tour_host.dart';
import 'package:hands_app/features/crm/widgets/crm_scoped_bottom_nav.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/utils/localized_content.dart';

// Bottom sheet widgets for editing
import 'package:hands_app/features/shifts/shift_template_bottom_sheet.dart';
import 'package:hands_app/ui/checklist_bottom_sheet.dart';
import 'package:hands_app/custom_code/widgets/UserManagementBottomSheet.dart';
import 'package:hands_app/ui/location_bottom_sheet_new.dart';

enum WebAdminTab { shifts, checklists, users, locations }

/// Persistent state manager for admin dashboard settings
class AdminDashboardState {
  static WebAdminTab? _lastTab;
  static int _rowsPerPage = 10;
  static int _currentPage = 0;
  static String _searchQuery = '';
  static int? _sortColumnIndex;
  static bool _sortAscending = true;

  static WebAdminTab? get lastTab => _lastTab;
  static int get rowsPerPage => _rowsPerPage;
  static int get currentPage => _currentPage;
  static String get searchQuery => _searchQuery;
  static int? get sortColumnIndex => _sortColumnIndex;
  static bool get sortAscending => _sortAscending;

  static set lastTab(WebAdminTab? value) => _lastTab = value;
  static set rowsPerPage(int value) {
    print('[AdminDashboardState] Setting rowsPerPage to $value');
    _rowsPerPage = value;
  }

  static set currentPage(int value) {
    print('[AdminDashboardState] Setting currentPage to $value');
    _currentPage = value;
  }

  static set searchQuery(String value) => _searchQuery = value;
  static set sortColumnIndex(int? value) => _sortColumnIndex = value;
  static set sortAscending(bool value) => _sortAscending = value;

  static void resetPagination() {
    _currentPage = 0;
  }
}

class WEBAdminDashboardPage extends StatefulWidget {
  final String organizationId;
  final WebAdminTab? initialTab;
  final bool usePortalLayout;
  final bool isNewOrganizationSetup;
  final bool allowPlatformAccess;

  const WEBAdminDashboardPage({
    super.key,
    required this.organizationId,
    this.initialTab,
    this.usePortalLayout = false,
    this.isNewOrganizationSetup = false,
    this.allowPlatformAccess = false,
  });

  @override
  State<WEBAdminDashboardPage> createState() => _WEBAdminDashboardPageState();
}

class _WEBAdminDashboardPageState extends State<WEBAdminDashboardPage>
    with ActivityTrackingMixin {
  int? userRole;
  bool isLoading = true;
  bool _accessDenied = false;

  // Current active tab - use persistent state
  late WebAdminTab _currentTab;

  // Available locations for filtering
  List<Map<String, dynamic>> _availableLocations = [];
  String? _selectedLocationId;
  String? _selectedLocationName;

  // Data caches
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _shiftDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _checklistDocs = [];
  int _teamMemberCount = 0;

  // Lookups
  final Map<String, String> _checklistNameById = {}; // templateId -> name
  final Map<String, String> _shiftNameById = {}; // shiftId -> name
  final Map<String, List<String>> _checklistsByShiftId =
      {}; // shiftId -> [templateIds]
  final Map<String, List<String>> _shiftsByChecklistId =
      {}; // checklistTemplateId -> [shiftIds]
  final Map<String, List<String>> _locationIdsByShiftId =
      {}; // shiftId -> [locationIds]

  // Search and filtering - use persistent state
  final TextEditingController _searchController = TextEditingController();

  // Loading state to prevent flashing during operations
  final bool _isDeleting = false;
  String? _deletingChecklistId;

  // Pagination and sorting - use persistent state manager
  int get _rowsPerPage => AdminDashboardState.rowsPerPage;
  int get _currentPage => AdminDashboardState.currentPage;
  String get _searchQuery => AdminDashboardState.searchQuery;
  int? get _sortColumnIndex => AdminDashboardState.sortColumnIndex;
  bool get _sortAscending => AdminDashboardState.sortAscending;

  // Scroll controllers (web scrolling fix)
  final ScrollController _verticalTableController = ScrollController();
  // Guard to avoid repeatedly showing the welcome dialog
  bool _welcomeShown = false;

  final GlobalKey _tourLocationScopeKey = GlobalKey();
  final GlobalKey _tourNavigationKey = GlobalKey();
  final GlobalKey _tourContentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentTab =
        widget.initialTab ?? AdminDashboardState.lastTab ?? WebAdminTab.shifts;
    // Initialize search controller with persistent search query
    _searchController.text = AdminDashboardState.searchQuery;
    // Seed selected location from global persisted value if available
    _selectedLocationId = LocationSelectionService.instance.currentLocationId;
    // Keep in sync with global location selection changes from other pages/dialogs.
    LocationSelectionService.instance.listenable.addListener(
      _onGlobalLocationChanged,
    );
    _checkUserAccess();
    _searchController.addListener(_onSearchChanged);

    // Do not show welcome here; defer until locations have been loaded
  }

  void _onGlobalLocationChanged() {
    final globalId = LocationSelectionService.instance.currentLocationId;
    final globalName = LocationSelectionService.instance.currentLocationName;
    if (globalId == _selectedLocationId &&
        globalName == _selectedLocationName) {
      return;
    }
    setState(() {
      _selectedLocationId = globalId;
      if (globalId == null) {
        _selectedLocationName = null;
      } else {
        final match = _availableLocations.firstWhere(
          (l) => l['id'] == globalId,
          orElse: () => {'name': globalName ?? _selectedLocationName},
        );
        _selectedLocationName =
            match['name'] as String? ?? globalName ?? _selectedLocationName;
      }
    });
    // Reload data scoped to new location
    unawaited(_reloadAllTables());
  }

  @override
  void dispose() {
    LocationSelectionService.instance.listenable.removeListener(
      _onGlobalLocationChanged,
    );
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _verticalTableController.dispose();
    super.dispose();
  }

  // Show welcome dialog for new organization setup
  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => WelcomeOrganizationDialog(
            onProceedToLocationSetup: _showLocationWizard,
          ),
    );
  }

  // Show location wizard for first location setup
  void _showLocationWizard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // Don't allow dismissing during setup
      enableDrag: false, // Don't allow dragging to dismiss
      builder:
          (context) => LocationWizard(
            organizationId: widget.organizationId,
            onCompleted: () async {
              // LocationWizard now handles closing automatically
              // Refresh the page data after location is created
              await _reloadAllTables();
            },
          ),
    );
  }

  // Reload on mount after access check sets up org
  Future<void> _reloadAllTables() async {
    await Future.wait([
      _loadChecklistsTable(),
      _loadShiftsTable(),
      _loadTeamMemberCount(),
    ]);
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
      _shiftDocs =
          snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

      // Build lookups
      _shiftNameById.clear();
      _checklistsByShiftId.clear();
      _locationIdsByShiftId.clear();
      for (final d in _shiftDocs) {
        final data = d.data();
        final sid = d.id;
        final rawName = (data['name'] ?? data['shiftName'] ?? '').toString();
        _shiftNameById[sid] = rawName;
        final tids = List<String>.from(
          data['checklistTemplateIds'] ?? const [],
        );
        _checklistsByShiftId[sid] = tids;
        final locIds = List<String>.from(data['locationIds'] ?? const []);
        _locationIdsByShiftId[sid] = locIds;
      }

      // Build reverse index
      _shiftsByChecklistId.clear();
      _checklistsByShiftId.forEach((sid, tids) {
        for (final t in tids) {
          _shiftsByChecklistId.putIfAbsent(t, () => []).add(sid);
        }
      });
      if (mounted) {
        setState(() {});
      }
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
      _checklistDocs =
          snap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

      _checklistNameById.clear();
      for (final d in _checklistDocs) {
        final data = d.data();
        final name = localizedContent(
          data,
          fieldKeys: const ['name', 'checklistName', 'templateName'],
        );
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

  Future<void> _loadTeamMemberCount() async {
    try {
      final snap =
          await FirestoreEnforcer.instance
              .collection('users')
              .where('organizationId', isEqualTo: widget.organizationId)
              .get();
      _teamMemberCount = snap.docs.length;
      if (mounted) {
        setState(() {});
      }
    } catch (e, st) {
      logger.e('[WEBAdminDashboard] _loadTeamMemberCount error: $e\n$st');
    }
  }

  List<String> _extractShiftChecklistIds(Map<String, dynamic> shift) {
    final checklistData =
        shift['checklists'] ??
        shift['checklistTemplateIds'] ??
        shift['checklistIds'] ??
        [];
    return (checklistData as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _workflowSummaryForShift(Map<String, dynamic> shift) {
    final names =
        _extractShiftChecklistIds(shift)
            .map(
              (id) =>
                  _checklistNameById[id] ?? context.l10n.webAdminWorkflowLabel,
            )
            .toList();
    if (names.isEmpty) {
      return context.l10n.adminWorkflowNoneAttached;
    }
    if (names.length == 1) {
      return names.first;
    }
    return '${names.first} +${names.length - 1}';
  }

  void _editWorkflowForShift(Map<String, dynamic> shift) {
    final checklistIds = _extractShiftChecklistIds(shift);
    if (checklistIds.isEmpty) {
      _createWorkflowForShift(shift);
      return;
    }
    final checklistId = checklistIds.first;
    QueryDocumentSnapshot<Map<String, dynamic>>? sourceDoc;
    for (final doc in _checklistDocs) {
      if (doc.id == checklistId) {
        sourceDoc = doc;
        break;
      }
    }
    final initialData = <String, dynamic>{
      'id': checklistId,
      'name':
          _checklistNameById[checklistId] ?? context.l10n.webAdminWorkflowLabel,
      ...?sourceDoc?.data(),
    };
    _editChecklist(initialData);
  }

  void _createWorkflowForShift(Map<String, dynamic> shift) {
    _showEditDialog(
      ChecklistBottomSheet(
        key: UniqueKey(),
        organizationId: widget.organizationId,
        locationId: _selectedLocationId ?? '',
        availableLocations: _availableLocations,
        presetShiftIds: [shift['id'] as String],
        initialTitleSuggestion: context.l10n.webAdminWorkflowSuggestion(
          '${shift['name'] ?? shift['shiftName'] ?? context.l10n.webAdminTabShift}',
        ),
        initialData: const {'tasks': []},
        onSave: (checklistData) async {
          await _saveChecklistFromBottomSheet(checklistData);
          await _loadChecklistsTable();
          _showSnackBar(context.l10n.webAdminWorkflowCreated);
        },
      ),
    );
  }

  String _formatSchedule(Map<String, dynamic> s) {
    final daily = s['repeatsDaily'] == true;
    final days = (s['days'] is List) ? List.from(s['days']) : <dynamic>[];

    if (daily) {
      return context.l10n.webAdminScheduleDaily;
    }

    if (days.isEmpty) {
      return '—';
    }

    mapDay(d) {
      final dd = d.toString().toLowerCase();
      if (dd.startsWith('mon') || dd == '1') return context.l10n.webAdminDayMon;
      if (dd.startsWith('tue') || dd == '2') return context.l10n.webAdminDayTue;
      if (dd.startsWith('wed') || dd == '3') return context.l10n.webAdminDayWed;
      if (dd.startsWith('thu') || dd == '4') return context.l10n.webAdminDayThu;
      if (dd.startsWith('fri') || dd == '5') return context.l10n.webAdminDayFri;
      if (dd.startsWith('sat') || dd == '6') return context.l10n.webAdminDaySat;
      if (dd.startsWith('sun') || dd == '0' || dd == '7')
        return context.l10n.webAdminDaySun;
      return dd.substring(0, 3).toUpperCase();
    }

    final names = days.map(mapDay).toList();
    return names.join(' ');
  }

  Widget _locationPicker(BuildContext context, {bool compact = true}) {
    return PopupMenuButton<String>(
      enabled: _availableLocations.isNotEmpty,
      onSelected: (value) async {
        final selectedLocation = _availableLocations.firstWhere(
          (l) => l['id'] == value,
          orElse: () => {'name': context.l10n.webAdminTabLocation},
        );
        final selectedLocationName = selectedLocation['name'] as String?;
        setState(() {
          _selectedLocationId = value;
          _selectedLocationName = selectedLocationName;
        });
        // Persist globally so other pages adopt the change
        await LocationSelectionService.instance.setLocationAsync(
          value,
          locationName: selectedLocationName,
        );
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
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color:
                            selected
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc['name'],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selected)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check, size: 14),
                        ),
                    ],
                  ),
                );
              }).toList(),
      child:
          compact
              ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HandsColors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedLocationName ??
                            context.l10n.adminSetupSelectLocation,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more_rounded, size: 16),
                  ],
                ),
              )
              : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF21262F),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _currentSectionAccent().withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: HandsColors.handsOrange,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.adminSetupActiveLocation,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: HandsColors.white70,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedLocationName ??
                                context.l10n.adminSetupSelectLocation,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: HandsColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _currentSectionAccent().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _currentSectionAccent().withValues(
                            alpha: 0.18,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Switch',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _currentSectionAccent(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.expand_more_rounded,
                            color: _currentSectionAccent(),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  @override
  void didUpdateWidget(WEBAdminDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update tab when route changes
    if (widget.initialTab != oldWidget.initialTab &&
        widget.initialTab != null) {
      setState(() {
        _currentTab = widget.initialTab!;
        AdminDashboardState.lastTab = _currentTab;
      });
    }
  }

  // (Original dispose merged into enhanced dispose near top adding global listener removal)

  void _onSearchChanged() {
    setState(() {
      AdminDashboardState.searchQuery = _searchController.text.toLowerCase();
      AdminDashboardState.currentPage = 0; // Reset to first page when searching
      AdminDashboardState.resetPagination(); // Persist the reset
    });
  }

  Future<void> _checkUserAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc =
          await FirestoreEnforcer.instance
              .collection('users')
              .doc(user.uid)
              .get();

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

        final hasPlatformAccess =
            widget.allowPlatformAccess && userData['platformAccess'] == true;

        // Only allow normal org admins, except CRM platform users opening
        // customer orgs through the platform-only CRM manage route.
        if ((role != 2 || orgId != widget.organizationId) &&
            !hasPlatformAccess) {
          logger.w(
            '[WEBAdminDashboard] Access denied: role=$role, orgId=$orgId, expectedOrgId=${widget.organizationId}',
          );
          if (mounted) {
            setState(() {
              _accessDenied = true;
              isLoading = false;
            });
          }
          return;
        }

        setState(() {
          _accessDenied = false;
          userRole = hasPlatformAccess ? 2 : role;
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
      logger.i(
        '[WEBAdminDashboard] Loading locations for org: ${widget.organizationId}',
      );

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
                  'name':
                      data['locationName'] ??
                      data['name'] ??
                      context.l10n.webAdminUnnamedLocation,
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
                'name':
                    data['locationName'] ??
                    data['name'] ??
                    context.l10n.webAdminUnnamedLocation,
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
        if (_selectedLocationId != null &&
            _availableLocations.any((l) => l['id'] == _selectedLocationId)) {
          _selectedLocationName =
              _availableLocations.firstWhere(
                    (l) => l['id'] == _selectedLocationId,
                  )['name']
                  as String?;
        } else if ((_selectedLocationId == null ||
                !_availableLocations.any(
                  (l) => l['id'] == _selectedLocationId,
                )) &&
            _availableLocations.isNotEmpty) {
          final primary = _availableLocations.firstWhere(
            (l) => l['isPrimary'] == true,
            orElse: () => _availableLocations.first,
          );
          _selectedLocationId = primary['id'] as String?;
          _selectedLocationName = primary['name'] as String?;
        }
      });

      if (_selectedLocationId != null) {
        await LocationSelectionService.instance.setLocationAsync(
          _selectedLocationId,
          locationName: _selectedLocationName,
        );
      }

      // If this is a new organization setup and there are no locations, show welcome once
      if (mounted &&
          widget.isNewOrganizationSetup &&
          !_welcomeShown &&
          _availableLocations.isEmpty) {
        _welcomeShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showWelcomeDialog();
          }
        });
      }

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
      barrierColor: HandsModalTokens.overlay,
      builder:
          (context) => HandsModalSurface(
            width: MediaQuery.of(context).size.width * 0.82,
            height: MediaQuery.of(context).size.height * 0.84,
            maxWidth: 1180,
            child: child,
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

    if (_accessDenied) {
      return Scaffold(
        backgroundColor: HandsColors.scaffoldBackground,
        appBar: AppBar(
          backgroundColor: HandsColors.cardPrimary,
          title: const Text('Access unavailable'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'You do not have admin access to this organization.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final l10n = context.l10n;
    final adminTourSteps = <GuidedTourStep>[
      GuidedTourStep(
        title: l10n.adminSetupTourWelcomeTitle,
        description: l10n.adminSetupTourWelcomeDescription,
      ),
      if (_availableLocations.length > 1)
        GuidedTourStep(
          targetKey: _tourLocationScopeKey,
          title: l10n.adminSetupTourLocationTitle,
          description: l10n.adminSetupTourLocationDescription,
          topicId: 'admin-multi-location',
        ),
      GuidedTourStep(
        targetKey: _tourNavigationKey,
        title: l10n.adminSetupTourAreasTitle,
        description: l10n.adminSetupTourAreasDescription,
        topicId: 'admin-first-location',
        scrollAlignment: 0.08,
      ),
      GuidedTourStep(
        targetKey: _tourContentKey,
        title: l10n.adminSetupTourPanelTitle,
        description: l10n.adminSetupTourPanelDescription,
        topicId: 'admin-create-shift',
        scrollAlignment: 0.08,
      ),
    ];

    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        leading:
            widget.allowPlatformAccess
                ? IconButton(
                  tooltip: 'Back to CRM',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/crm'),
                )
                : null,
        title:
            widget.allowPlatformAccess
                ? Text(
                  'CRM account workspace',
                  style: GoogleFonts.comfortaa(fontWeight: FontWeight.w800),
                )
                : GenericAppBarContent(
                  appBarTitle: l10n.bottomNavSetup,
                  userRole: userRole,
                ),
        automaticallyImplyLeading: false,
        actions:
            widget.allowPlatformAccess
                ? [
                  TextButton.icon(
                    onPressed: () => context.go('/crm'),
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    label: const Text('Back to CRM'),
                  ),
                  const SizedBox(width: 12),
                ]
                : [
                  // Unified menu button
                  UnifiedMenuButton(
                    userRole: userRole,
                    organizationId: widget.organizationId,
                  ),
                ],
      ),
      body: GuidedTourHost(
        storageKey: 'admin-setup-tour-v2',
        enabled: !isLoading && !widget.allowPlatformAccess,
        steps: adminTourSteps,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F1116), Color(0xFF141820)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                KeyedSubtree(
                  key: _tourNavigationKey,
                  child: _buildLeftNavigation(),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      if (widget.allowPlatformAccess) ...[
                        _buildCrmManageBanner(),
                        const SizedBox(height: 12),
                      ],
                      KeyedSubtree(
                        key: _tourLocationScopeKey,
                        child: _buildFilterBar(),
                      ),
                      if (widget.isNewOrganizationSetup &&
                          !widget.allowPlatformAccess) ...[
                        const SizedBox(height: 10),
                        _buildLaunchChecklistCard(),
                      ],
                      const SizedBox(height: 16),
                      Expanded(
                        child: KeyedSubtree(
                          key: _tourContentKey,
                          child: _buildMainContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          widget.allowPlatformAccess
              ? CrmScopedBottomNav(
                orgId: widget.organizationId,
                currentIndex: 2,
              )
              : BottomNavBar(
                currentIndex: 2,
                userRole: userRole,
              ), // Admin tab is index 2
    );
  }

  Widget _buildLaunchChecklistCard() {
    final locationDone = _availableLocations.isNotEmpty;
    final teamDone = _teamMemberCount > 1;
    final shiftsDone = _shiftDocs.isNotEmpty;
    final workflowsDone = _checklistDocs.isNotEmpty;
    final completeCount =
        [
          locationDone,
          teamDone,
          shiftsDone,
          workflowsDone,
        ].where((done) => done).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111821),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HandsColors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: HandsColors.handsOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.rocket_launch_outlined,
              color: HandsColors.handsOrange,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Launch checklist',
                      style: GoogleFonts.inter(
                        color: HandsColors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTrialPill(),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildLaunchStepChip(
                      label: 'Location',
                      done: locationDone,
                      tab: WebAdminTab.locations,
                    ),
                    _buildLaunchStepChip(
                      label: 'Team',
                      done: teamDone,
                      tab: WebAdminTab.users,
                    ),
                    _buildLaunchStepChip(
                      label: 'Shift',
                      done: shiftsDone,
                      tab: WebAdminTab.shifts,
                    ),
                    _buildLaunchStepChip(
                      label: 'Workflow',
                      done: workflowsDone,
                      tab: WebAdminTab.checklists,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$completeCount/4 ready',
            style: GoogleFonts.inter(
              color: HandsColors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HandsColors.sageGreen.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HandsColors.sageGreen.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Trial active - add billing later in Settings',
        style: GoogleFonts.inter(
          color: HandsColors.sageGreen,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLaunchStepChip({
    required String label,
    required bool done,
    required WebAdminTab tab,
  }) {
    final color = done ? HandsColors.sageGreen : _accentForTab(tab);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          _currentTab = tab;
          AdminDashboardState.lastTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: done ? 0.14 : 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: color,
              size: 13,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                color: HandsColors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrmManageBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: HandsColors.handsOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: HandsColors.handsOrange.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: HandsColors.handsOrange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Viewing this customer setup from CRM. This does not switch your signed-in app org; use Back to CRM when you are finished.',
              style: GoogleFonts.inter(
                color: HandsColors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftNavigation() {
    return Container(
      width: 238,
      decoration: BoxDecoration(
        color: const Color(0xFF171B22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HandsColors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: HandsColors.white12, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.adminSetupHeroTitle,
                  style: GoogleFonts.inter(
                    color: HandsColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.webAdminSidebarSubtitle,
                  style: GoogleFonts.inter(
                    color: HandsColors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                if (_selectedLocationName != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: HandsColors.handsOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: HandsColors.handsOrange.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: HandsColors.handsOrange,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedLocationName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: HandsColors.handsOrange,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              children: [
                _buildNavItem(
                  icon: Icons.location_on,
                  label: context.l10n.adminViewLocations,
                  tab: WebAdminTab.locations,
                  isActive: _currentTab == WebAdminTab.locations,
                ),
                _buildNavItem(
                  icon: Icons.people,
                  label: context.l10n.adminViewTeam,
                  tab: WebAdminTab.users,
                  isActive: _currentTab == WebAdminTab.users,
                ),
                _buildNavItem(
                  icon: Icons.schedule,
                  label: context.l10n.adminViewShifts,
                  tab: WebAdminTab.shifts,
                  isActive: _currentTab == WebAdminTab.shifts,
                ),
                _buildNavItem(
                  icon: Icons.library_books,
                  label: context.l10n.adminViewChecklistLibrary,
                  tab: WebAdminTab.checklists,
                  isActive: _currentTab == WebAdminTab.checklists,
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: HandsColors.white12, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _currentSectionIcon(),
                    color: _currentSectionAccent(),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTabDisplayName(),
                        style: GoogleFonts.inter(
                          color: HandsColors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.webAdminSetupWorkspace,
                        style: GoogleFonts.inter(
                          color: HandsColors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _currentTab = tab;
              AdminDashboardState.lastTab = _currentTab;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? _currentSectionAccent().withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isActive
                        ? _currentSectionAccent().withValues(alpha: 0.22)
                        : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color:
                      isActive ? _currentSectionAccent() : HandsColors.white70,
                  size: 19,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: isActive ? HandsColors.white : HandsColors.white70,
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color:
                      isActive
                          ? _currentSectionAccent()
                          : Colors.white.withValues(alpha: 0.22),
                  size: 18,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HandsColors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _currentSectionAccent().withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _currentSectionEyebrow(),
                        style: GoogleFonts.inter(
                          color: _currentSectionAccent(),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentSectionTitle(),
                      style: GoogleFonts.inter(
                        color: HandsColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _currentSectionSubtitle(),
                      style: GoogleFonts.inter(
                        color: HandsColors.white70,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ContextHelpTrigger(
                title: _currentSectionTitle(),
                subtitle: _currentSectionSubtitle(),
                topicIds: _currentSectionHelpTopics(),
              ),
              const SizedBox(width: 10),
              Container(
                width: 106,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HandsColors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.webAdminScope,
                      style: GoogleFonts.inter(
                        color: HandsColors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 14,
                          color: _currentSectionAccent(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _availableLocations.length > 1
                                ? (_selectedLocationName ??
                                    context.l10n.adminSetupAllLocations)
                                : context.l10n.webAdminAllActive,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: HandsColors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Location indicator (only show if multiple locations exist)
          if (_availableLocations.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: _locationPicker(context, compact: true),
            ),
          ],
          Row(
            children: [
              Expanded(
                flex: 3,
                child: HandsTextField(
                  controller: _searchController,
                  style: GoogleFonts.comfortaa(color: HandsColors.white),
                  decoration: InputDecoration(
                    hintText: context.l10n.webAdminSearchHint(
                      _getTabDisplayName(),
                    ),
                    hintStyle: GoogleFonts.comfortaa(
                      color: HandsColors.white30,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: HandsColors.white30,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: HandsColors.white30,
                              ),
                              onPressed: () => _searchController.clear(),
                            )
                            : null,
                    filled: true,
                    fillColor: const Color(0xFF21262F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (_shouldShowLocationFilter() &&
                  _availableLocations.isNotEmpty) ...[
                SizedBox(width: 210, child: _locationPicker(context)),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  context.l10n.webAdminAddItem(
                    _getTabDisplayName(singular: true),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentSectionAccent(),
                  foregroundColor: HandsColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          // Location filter for mobile/smaller screens (if needed)
          if (_shouldShowLocationFilter() &&
              MediaQuery.of(context).size.width < 1200) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 250, child: _locationPicker(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HandsColors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _currentSectionAccent().withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _currentSectionIcon(),
                    color: _currentSectionAccent(),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentSectionTitle(),
                        style: GoogleFonts.inter(
                          color: HandsColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentSectionTableSubtitle(),
                        style: GoogleFonts.inter(
                          color: HandsColors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: switch (_currentTab) {
                WebAdminTab.shifts => _buildShiftsTable(),
                WebAdminTab.checklists => _buildChecklistsTable(),
                WebAdminTab.users => _buildUsersTable(),
                WebAdminTab.locations => _buildLocationsTable(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftsTable() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('shifts')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(context.l10n.webAdminStreamError('${snapshot.error}')),
          );
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
              if (data['shiftName'] != null &&
                  data['shiftName'].toString().isNotEmpty) {
                shiftName = data['shiftName'].toString();
              } else if (data['name'] != null &&
                  data['name'].toString().isNotEmpty) {
                shiftName = data['name'].toString();
              } else {
                shiftName = context.l10n.webAdminUnnamedShift;
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
                return shift['name'].toString().toLowerCase().contains(
                  _searchQuery,
                );
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

        // Ensure archived/inactive shifts (active == false) appear at bottom (stable grouping)
        shifts.sort((a, b) {
          final aInactive = (a['active'] ?? true) == false;
          final bInactive = (b['active'] ?? true) == false;
          if (aInactive == bInactive) return 0;
          return aInactive ? 1 : -1; // inactive last
        });

        return _buildDataTable(
          columns: [
            DataColumn(
              label: Text(context.l10n.webAdminColumnShiftName),
              onSort: (columnIndex, ascending) {
                setState(() {
                  AdminDashboardState.sortColumnIndex = columnIndex;
                  AdminDashboardState.sortAscending = ascending;
                });
              },
            ),
            DataColumn(
              label: Text(context.l10n.webAdminColumnTime),
              onSort: (columnIndex, ascending) {
                setState(() {
                  AdminDashboardState.sortColumnIndex = columnIndex;
                  AdminDashboardState.sortAscending = ascending;
                });
              },
            ),
            DataColumn(label: Text(context.l10n.webAdminWorkflowLabel)),
            DataColumn(label: Text(context.l10n.webAdminColumnSchedule)),
            // Locations column removed - locations are now managed uniquely and should not be displayed here
            DataColumn(label: Text(context.l10n.webAdminColumnStatus)),
            DataColumn(label: Text(context.l10n.webAdminColumnActions)),
          ],
          rows: shifts,
          buildRow: (shift) => _buildShiftRow(shift),
        );
      },
    );
  }

  DataRow _buildShiftRow(Map<String, dynamic> shift) {
    // Location IDs and names intentionally not used in web shifts table (locations are managed uniquely)

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
    final timeRange =
        (startTime.isNotEmpty && endTime.isNotEmpty)
            ? '$startTime - $endTime'
            : '$startTime$endTime';

    return DataRow(
      cells: [
        DataCell(
          Text(
            shift['name'],
            style: GoogleFonts.comfortaa(color: HandsColors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Text(
            timeRange,
            style: GoogleFonts.comfortaa(color: HandsColors.white70),
          ),
        ),
        DataCell(
          // Workflow column: show the primary attached checklist template
          Builder(
            builder: (context) {
              return Text(
                _workflowSummaryForShift(shift),
                style: GoogleFonts.comfortaa(
                  color:
                      _extractShiftChecklistIds(shift).isEmpty
                          ? HandsColors.white30
                          : HandsColors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ),
        DataCell(
          Text(
            _formatSchedule(shift),
            style: GoogleFonts.comfortaa(color: HandsColors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Locations cell removed - do not display location names in shifts table
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  shift['active'] ? HandsColors.sageGreen : HandsColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              shift['active']
                  ? context.l10n.webAdminStatusActive
                  : context.l10n.webAdminStatusInactive,
              style: GoogleFonts.comfortaa(
                color: HandsColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: HandsColors.handsOrange,
                  size: 20,
                ),
                onPressed: () => _editShift(shift),
                tooltip: context.l10n.webAdminActionEdit,
              ),
              IconButton(
                icon: Icon(
                  _extractShiftChecklistIds(shift).isEmpty
                      ? Icons.add_task_rounded
                      : Icons.rule_folder_outlined,
                  color: HandsColors.handsOrange,
                  size: 20,
                ),
                onPressed: () => _editWorkflowForShift(shift),
                tooltip:
                    _extractShiftChecklistIds(shift).isEmpty
                        ? context.l10n.webAdminActionCreateWorkflow
                        : context.l10n.webAdminActionEditWorkflow,
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy,
                  color: HandsColors.white70,
                  size: 20,
                ),
                onPressed: () => _duplicateShift(shift),
                tooltip: context.l10n.webAdminActionDuplicate,
              ),
              IconButton(
                icon: Icon(
                  shift['active'] ? Icons.archive : Icons.unarchive,
                  color: HandsColors.amber,
                  size: 20,
                ),
                onPressed: () => _toggleShiftActive(shift),
                tooltip:
                    shift['active']
                        ? context.l10n.webAdminActionArchive
                        : context.l10n.webAdminActionRestore,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete,
                  color: HandsColors.error,
                  size: 20,
                ),
                onPressed: () => _deleteShift(shift),
                tooltip: context.l10n.commonDelete,
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
          return Center(
            child: Text(context.l10n.webAdminStreamError('${snapshot.error}')),
          );
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
                'name': localizedContent(
                  data,
                  fieldKeys: const ['name', 'checklistName', 'templateName'],
                  fallback: context.l10n.webAdminUnnamedTemplate,
                ),
                'description': localizedContent(
                  data,
                  fieldKeys: const ['checklistDescription', 'description'],
                ),
                'taskCount': tasks.length,
                'createdAt': data['createdAt'],
                ...data,
              };
            }).toList();

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          checklists =
              checklists.where((checklist) {
                return checklist['name'].toString().toLowerCase().contains(
                      _searchQuery,
                    ) ||
                    checklist['description'].toString().toLowerCase().contains(
                      _searchQuery,
                    );
              }).toList();
        }

        // Filter by selected location if one is selected
        if (_selectedLocationId != null) {
          checklists =
              checklists.where((checklist) {
                final data = checklist;
                final rawLocs = data['locationIds'];
                if (rawLocs == null) {
                  return true; // global template (legacy) -> show
                }
                if (rawLocs is Iterable) {
                  return rawLocs
                      .map((e) => e.toString())
                      .contains(_selectedLocationId);
                }
                return true; // unexpected type -> don't hide
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

        // Ensure archived checklists (archived == true) appear at bottom
        checklists.sort((a, b) {
          final aArchived = (a['archived'] ?? false) == true;
          final bArchived = (b['archived'] ?? false) == true;
          if (aArchived == bArchived) return 0;
          return aArchived ? 1 : -1; // archived last
        });

        return _buildDataTable(
          columns: [
            DataColumn(
              label: Text(context.l10n.webAdminColumnTemplateName),
              onSort: (columnIndex, ascending) {
                setState(() {
                  AdminDashboardState.sortColumnIndex = columnIndex;
                  AdminDashboardState.sortAscending = ascending;
                });
              },
            ),
            DataColumn(label: Text(context.l10n.webAdminColumnDescription)),
            DataColumn(
              label: Text(context.l10n.webAdminColumnTasks),
              onSort: (columnIndex, ascending) {
                setState(() {
                  AdminDashboardState.sortColumnIndex = columnIndex;
                  AdminDashboardState.sortAscending = ascending;
                });
              },
              numeric: true,
            ),
            DataColumn(label: Text(context.l10n.webAdminColumnUsedInShifts)),
            DataColumn(label: Text(context.l10n.webAdminColumnStatus)),
            DataColumn(label: Text(context.l10n.webAdminColumnActions)),
          ],
          rows: checklists,
          buildRow: (checklist) => _buildChecklistRow(checklist),
        );
      },
    );
  }

  DataRow _buildChecklistRow(Map<String, dynamic> checklist) {
    final isBeingDeleted =
        _isDeleting && _deletingChecklistId == checklist['id'];

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              if (isBeingDeleted) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  checklist['name'],
                  style: GoogleFonts.comfortaa(
                    color:
                        isBeingDeleted
                            ? HandsColors.white30
                            : HandsColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            checklist['description'].isNotEmpty
                ? checklist['description']
                : context.l10n.webAdminNoDescription,
            style: GoogleFonts.comfortaa(
              color: isBeingDeleted ? HandsColors.white30 : HandsColors.white70,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Text(
            context.l10n.webAdminTaskCount(checklist['taskCount'] as int),
            style: GoogleFonts.comfortaa(
              color: isBeingDeleted ? HandsColors.white30 : HandsColors.white70,
            ),
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
                    used
                        .where(
                          (sid) =>
                              (_locationIdsByShiftId[sid] ?? const <String>[])
                                  .contains(_selectedLocationId),
                        )
                        .toList();
              }
              final labels =
                  filteredUsed
                      .map((sid) => _shiftNameById[sid] ?? 'Shift')
                      .map(
                        (name) =>
                            name == 'Shift'
                                ? context.l10n.webAdminTabShift
                                : name,
                      )
                      .toList();
              if (labels.isEmpty) {
                return Text(
                  '—',
                  style: GoogleFonts.comfortaa(
                    color:
                        isBeingDeleted
                            ? HandsColors.white30
                            : HandsColors.white70,
                  ),
                );
              }
              if (labels.length <= 3) {
                return Text(
                  labels.join(', '),
                  style: GoogleFonts.comfortaa(
                    color:
                        isBeingDeleted
                            ? HandsColors.white30
                            : HandsColors.white70,
                  ),
                );
              }
              return Text(
                '${labels.take(3).join(', ')} +${labels.length - 3}',
                style: GoogleFonts.comfortaa(
                  color:
                      isBeingDeleted
                          ? HandsColors.white30
                          : HandsColors.white70,
                ),
              );
            },
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (checklist['archived'] ?? false) == true
                      ? HandsColors.error
                      : HandsColors.sageGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (checklist['archived'] ?? false) == true
                  ? context.l10n.webAdminStatusArchived
                  : context.l10n.webAdminStatusActive,
              style: GoogleFonts.comfortaa(
                color: isBeingDeleted ? HandsColors.white30 : HandsColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color:
                      isBeingDeleted
                          ? HandsColors.white30
                          : HandsColors.handsOrange,
                  size: 20,
                ),
                onPressed:
                    isBeingDeleted ? null : () => _editChecklist(checklist),
                tooltip: context.l10n.webAdminActionEdit,
              ),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color:
                      isBeingDeleted
                          ? HandsColors.white30
                          : HandsColors.white70,
                  size: 20,
                ),
                onPressed:
                    isBeingDeleted
                        ? null
                        : () => _duplicateChecklist(checklist),
                tooltip: context.l10n.webAdminActionDuplicate,
              ),
              IconButton(
                icon: Icon(
                  (checklist['archived'] ?? false)
                      ? Icons.unarchive
                      : Icons.archive,
                  color:
                      isBeingDeleted ? HandsColors.white30 : HandsColors.amber,
                  size: 20,
                ),
                onPressed:
                    isBeingDeleted
                        ? null
                        : () => _toggleChecklistArchived(checklist),
                tooltip:
                    (checklist['archived'] ?? false)
                        ? context.l10n.webAdminActionRestore
                        : context.l10n.webAdminActionArchive,
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color:
                      isBeingDeleted ? HandsColors.white30 : HandsColors.error,
                  size: 20,
                ),
                onPressed:
                    isBeingDeleted ? null : () => _deleteChecklist(checklist),
                tooltip: context.l10n.commonDelete,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTable() {
    return Column(
      children: [
        PendingInvitesPanel(organizationId: widget.organizationId),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirestoreEnforcer.instance
                    .collection('users')
                    .where('organizationId', isEqualTo: widget.organizationId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    context.l10n.webAdminStreamError('${snapshot.error}'),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              List<Map<String, dynamic>> users =
                  docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name =
                        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                            .trim();
                    final locationIds = coerceToLocationIds(
                      data['locationIds'] ?? data['locationId'],
                    );

                    int userRole = 0;
                    final roleData = data['userRole'] ?? data['role'];
                    if (roleData is int) {
                      userRole = roleData;
                    } else if (roleData is String) {
                      userRole = int.tryParse(roleData) ?? 0;
                    }

                    final cleanData = Map<String, dynamic>.from(data);
                    cleanData.remove('role');

                    return {
                      'id': doc.id,
                      'name':
                          name.isNotEmpty
                              ? name
                              : context.l10n.webAdminUnknownUser,
                      'email':
                          data['emailAddress'] ??
                          data['userEmail'] ??
                          data['email'] ??
                          context.l10n.webAdminNoEmail,
                      'role': userRole,
                      'userRole': userRole,
                      'locationIds': locationIds,
                      'jobTypes': coerceToJobTypes(
                        data['jobTypes'] ?? data['jobType'],
                      ),
                      'isActive': data['isActive'] ?? true,
                      'createdAt': data['createdAt'],
                      ...cleanData,
                    };
                  }).toList();

              if (_searchQuery.isNotEmpty) {
                users =
                    users.where((user) {
                      return user['name'].toString().toLowerCase().contains(
                            _searchQuery,
                          ) ||
                          user['email'].toString().toLowerCase().contains(
                            _searchQuery,
                          );
                    }).toList();
              }

              if (_selectedLocationId != null) {
                users =
                    users.where((user) {
                      final locationIds = user['locationIds'] as List? ?? [];
                      final role = user['role'] as int? ?? 0;
                      return role == 2 ||
                          locationIds.contains(_selectedLocationId);
                    }).toList();
              }

              if (_sortColumnIndex != null) {
                users.sort((a, b) {
                  dynamic valueA;
                  dynamic valueB;
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

              users.sort((a, b) {
                final aInactive = (a['isActive'] ?? true) == false;
                final bInactive = (b['isActive'] ?? true) == false;
                if (aInactive == bInactive) return 0;
                return aInactive ? 1 : -1;
              });

              return _buildDataTable(
                columns: [
                  DataColumn(
                    label: Text(context.l10n.commonName),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        AdminDashboardState.sortColumnIndex = columnIndex;
                        AdminDashboardState.sortAscending = ascending;
                      });
                    },
                  ),
                  DataColumn(
                    label: Text(context.l10n.commonEmail),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        AdminDashboardState.sortColumnIndex = columnIndex;
                        AdminDashboardState.sortAscending = ascending;
                      });
                    },
                  ),
                  DataColumn(
                    label: Text(context.l10n.commonRole),
                    onSort: (columnIndex, ascending) {
                      setState(() {
                        AdminDashboardState.sortColumnIndex = columnIndex;
                        AdminDashboardState.sortAscending = ascending;
                      });
                    },
                  ),
                  DataColumn(label: Text(context.l10n.adminViewLocations)),
                  DataColumn(label: Text(context.l10n.webAdminColumnStatus)),
                  DataColumn(label: Text(context.l10n.webAdminColumnActions)),
                ],
                rows: users,
                buildRow: (user) => _buildUserRow(user),
              );
            },
          ),
        ),
      ],
    );
  }

  DataRow _buildUserRow(Map<String, dynamic> user) {
    final locationIds = user['locationIds'] as List? ?? [];
    final locationNames = locationIds
        .map((id) {
          final location = _availableLocations.firstWhere(
            (loc) => loc['id'] == id,
            orElse: () => {'name': 'Unknown'},
          );
          return location['name'];
        })
        .join(', ');

    final role = user['role'] as int? ?? 0;
    final roleText =
        role == 2
            ? context.l10n.welcomeRoleAdmin
            : (role == 1
                ? context.l10n.welcomeRoleManager
                : context.l10n.welcomeRoleUser);

    return DataRow(
      cells: [
        DataCell(
          Text(
            user['name'],
            style: GoogleFonts.comfortaa(color: HandsColors.white),
          ),
        ),
        DataCell(
          Text(
            user['email'],
            style: GoogleFonts.comfortaa(color: HandsColors.white70),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  role == 2
                      ? HandsColors.handsOrange
                      : (role == 1 ? HandsColors.amber : HandsColors.sageGreen),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              roleText,
              style: GoogleFonts.comfortaa(
                color: HandsColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            locationNames.isNotEmpty
                ? locationNames
                : context.l10n.adminSetupAllLocations,
            style: GoogleFonts.comfortaa(color: HandsColors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  user['isActive'] ? HandsColors.sageGreen : HandsColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user['isActive']
                  ? context.l10n.webAdminStatusActive
                  : context.l10n.webAdminStatusInactive,
              style: GoogleFonts.comfortaa(
                color: HandsColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: HandsColors.handsOrange,
                  size: 20,
                ),
                onPressed: () => _editUser(user),
                tooltip: context.l10n.webAdminActionEdit,
              ),
              if (role < 2)
                IconButton(
                  icon: Icon(
                    user['isActive'] ? Icons.archive : Icons.unarchive,
                    color: HandsColors.amber,
                    size: 20,
                  ),
                  onPressed: () => _toggleUserActive(user),
                  tooltip:
                      user['isActive']
                          ? context.l10n.webAdminActionDeactivate
                          : context.l10n.webAdminActionActivate,
                ),
              IconButton(
                icon: const Icon(Icons.delete, color: HandsColors.error),
                tooltip: context.l10n.webAdminActionDeleteUser,
                onPressed: () async {
                  print(
                    '🔴 DELETE USER BUTTON CLICKED! User: ${user['firstName']} ${user['lastName']} (${user['id']})',
                  );

                  // Capture context and user data before dialog
                  final currentContext = context;
                  final userId = user['id'] as String;
                  final userName = '${user['firstName']} ${user['lastName']}';

                  // Create standalone deletion function
                  Future<void> executeUserDeletion() async {
                    try {
                      await _deleteUser(userId);
                      if (currentContext.mounted) {
                        try {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.webAdminUserDeleted),
                            ),
                          );
                        } catch (e) {
                          print(
                            '🔴 USER DELETE: Could not show snackbar (context invalid): $e',
                          );
                        }
                      }
                    } catch (e) {
                      print('🔴 USER DELETE: Error during execution: $e');
                      if (currentContext.mounted) {
                        try {
                          ScaffoldMessenger.of(currentContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.webAdminUserDeleteFailed('$e'),
                              ),
                            ),
                          );
                        } catch (contextError) {
                          print(
                            '🔴 USER DELETE: Could not show error snackbar (context invalid): $contextError',
                          );
                        }
                      }
                    }
                  }

                  final ok = await _showStableDialog(
                    builder: (closeDialog) {
                      print('🔴 USER DELETE DIALOG BUILDING!');
                      return AlertDialog(
                        title: Text(context.l10n.webAdminDeleteUserTitle),
                        content: Text(
                          context.l10n.webAdminDeleteUserBody(userName),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              print('🔴 USER DELETE CANCELLED');
                              closeDialog(false);
                            },
                            child: Text(context.l10n.commonCancel),
                          ),
                          FilledButton(
                            onPressed: () {
                              print('🔴 USER DELETE CONFIRMED');
                              closeDialog(true);
                            },
                            child: Text(context.l10n.commonDelete),
                          ),
                        ],
                      );
                    },
                  );

                  if (ok != true) {
                    print('🔴 USER DELETE CANCELLED BY USER');
                    return;
                  }

                  // Execute deletion regardless of widget state
                  print(
                    '🔴 USER DELETE PROCEEDING... (widget may be unmounted)',
                  );
                  await executeUserDeletion();
                },
              ),
            ],
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
          logger.e(
            '[WEBAdminDashboard] StreamBuilder error for locations: ${snapshot.error}',
          );
          return Center(
            child: Text(context.l10n.webAdminStreamError('${snapshot.error}')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          logger.i('[WEBAdminDashboard] Waiting for locations stream...');
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        logger.i(
          '[WEBAdminDashboard] StreamBuilder received ${docs.length} location documents',
        );

        List<Map<String, dynamic>> locations =
            docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              logger.d(
                '[WEBAdminDashboard] Processing location: ${doc.id} -> $data',
              );

              // Try multiple possible field names for location name
              String locationName = '';
              if (data['name'] != null && data['name'].toString().isNotEmpty) {
                locationName = data['name'].toString();
              } else if (data['locationName'] != null &&
                  data['locationName'].toString().isNotEmpty) {
                locationName = data['locationName'].toString();
              } else {
                locationName = context.l10n.webAdminUnnamedLocation;
              }

              // Try multiple possible field names for address
              String address = '';
              if (data['address'] != null &&
                  data['address'].toString().isNotEmpty) {
                address = data['address'].toString();
              } else if (data['locationAddress'] != null &&
                  data['locationAddress'].toString().isNotEmpty) {
                address = data['locationAddress'].toString();
              } else {
                address = context.l10n.webAdminNoAddress;
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

        logger.i(
          '[WEBAdminDashboard] Total locations after processing: ${locations.length}',
        );

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          locations =
              locations.where((location) {
                return location['name'].toString().toLowerCase().contains(
                      _searchQuery,
                    ) ||
                    location['address'].toString().toLowerCase().contains(
                      _searchQuery,
                    );
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

        // Ensure inactive locations (isActive == false) appear at bottom
        locations.sort((a, b) {
          final aInactive = (a['isActive'] ?? true) == false;
          final bInactive = (b['isActive'] ?? true) == false;
          if (aInactive == bInactive) return 0;
          return aInactive ? 1 : -1;
        });

        return _buildDataTable(
          columns: [
            DataColumn(
              label: Text(context.l10n.webAdminColumnLocationName),
              onSort: (columnIndex, ascending) {
                setState(() {
                  AdminDashboardState.sortColumnIndex = columnIndex;
                  AdminDashboardState.sortAscending = ascending;
                });
              },
            ),
            DataColumn(
              label: Text(context.l10n.webAdminColumnAddress),
              onSort: (columnIndex, ascending) {
                setState(() {
                  AdminDashboardState.sortColumnIndex = columnIndex;
                  AdminDashboardState.sortAscending = ascending;
                });
              },
            ),
            DataColumn(label: Text(context.l10n.webAdminColumnStatus)),
            DataColumn(label: Text(context.l10n.webAdminColumnActions)),
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
        DataCell(
          Text(
            location['name'],
            style: GoogleFonts.comfortaa(color: HandsColors.white),
          ),
        ),
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
              color:
                  location['isActive']
                      ? HandsColors.sageGreen
                      : HandsColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              location['isActive']
                  ? context.l10n.webAdminStatusActive
                  : context.l10n.webAdminStatusInactive,
              style: GoogleFonts.comfortaa(
                color: HandsColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: HandsColors.handsOrange,
                  size: 20,
                ),
                onPressed: () => _editLocation(location),
                tooltip: context.l10n.webAdminActionEdit,
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy,
                  color: HandsColors.white70,
                  size: 20,
                ),
                onPressed: () => _duplicateLocation(location),
                tooltip: context.l10n.webAdminActionDuplicate,
              ),
              IconButton(
                icon: Icon(
                  location['isActive'] ? Icons.archive : Icons.unarchive,
                  color: HandsColors.amber,
                  size: 20,
                ),
                onPressed: () => _toggleLocationActive(location),
                tooltip:
                    location['isActive']
                        ? context.l10n.webAdminActionArchive
                        : context.l10n.webAdminActionRestore,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete,
                  color: HandsColors.error,
                  size: 20,
                ),
                onPressed: () => _deleteLocation(location),
                tooltip: context.l10n.commonDelete,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    String title;
    String description;
    String actionText;
    IconData icon;
    String supportLabel;
    String supportValue;
    String secondaryLabel;
    String secondaryValue;

    switch (_currentTab) {
      case WebAdminTab.shifts:
        title = context.l10n.webAdminEmptyTitleShifts;
        description = context.l10n.webAdminEmptyDescriptionShifts;
        actionText = context.l10n.webAdminEmptyActionShifts;
        icon = Icons.schedule;
        supportLabel = context.l10n.webAdminEmptySupportLabelShifts;
        supportValue = context.l10n.webAdminEmptySupportValueShifts;
        secondaryLabel = context.l10n.webAdminEmptySecondaryLabelShifts;
        secondaryValue = context.l10n.webAdminEmptySecondaryValueShifts;
        break;
      case WebAdminTab.checklists:
        title = context.l10n.webAdminEmptyTitleChecklists;
        description = context.l10n.webAdminEmptyDescriptionChecklists;
        actionText = context.l10n.webAdminEmptyActionChecklists;
        icon = Icons.library_books;
        supportLabel = context.l10n.webAdminEmptySupportLabelChecklists;
        supportValue = context.l10n.webAdminEmptySupportValueChecklists;
        secondaryLabel = context.l10n.webAdminEmptySecondaryLabelChecklists;
        secondaryValue = context.l10n.webAdminEmptySecondaryValueChecklists;
        break;
      case WebAdminTab.users:
        title = context.l10n.webAdminEmptyTitleUsers;
        description = context.l10n.webAdminEmptyDescriptionUsers;
        actionText = context.l10n.webAdminEmptyActionUsers;
        icon = Icons.people;
        supportLabel = context.l10n.webAdminEmptySupportLabelUsers;
        supportValue = context.l10n.webAdminEmptySupportValueUsers;
        secondaryLabel = context.l10n.webAdminEmptySecondaryLabelUsers;
        secondaryValue = context.l10n.webAdminEmptySecondaryValueUsers;
        break;
      case WebAdminTab.locations:
        title = context.l10n.webAdminEmptyTitleLocations;
        description = context.l10n.webAdminEmptyDescriptionLocations;
        actionText = context.l10n.webAdminEmptyActionLocations;
        icon = Icons.location_on;
        supportLabel = context.l10n.webAdminEmptySupportLabelLocations;
        supportValue = context.l10n.webAdminEmptySupportValueLocations;
        secondaryLabel = context.l10n.webAdminEmptySecondaryLabelLocations;
        secondaryValue = context.l10n.webAdminEmptySecondaryValueLocations;
        break;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF181D25), Color(0xFF12161D)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HandsColors.white12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 24,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _currentSectionAccent().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _currentSectionAccent().withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(icon, size: 28, color: _currentSectionAccent()),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.75,
                            color: HandsColors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: HandsColors.white70,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      actionText,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentSectionAccent(),
                      foregroundColor: HandsColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      elevation: 0,
                    ),
                  ),
                  _buildEmptyStateMetric(
                    label: supportLabel,
                    value: supportValue,
                  ),
                  _buildEmptyStateMetric(
                    label: secondaryLabel,
                    value: secondaryValue,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.webAdminEmptyFooter,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: HandsColors.white30,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateMetric({
    required String label,
    required String value,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HandsColors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: HandsColors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: HandsColors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable({
    required List<DataColumn> columns,
    required List<Map<String, dynamic>> rows,
    required DataRow Function(Map<String, dynamic>) buildRow,
  }) {
    // If no data, show helpful empty state instead of empty table
    if (rows.isEmpty) {
      return _buildEmptyState();
    }

    final paginatedRows = _paginateRows(rows);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141920),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HandsColors.white12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rows.length} ${_getTabDisplayName()}',
                        style: GoogleFonts.inter(
                          color: HandsColors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentSectionTableSubtitle(),
                        style: GoogleFonts.inter(
                          color: HandsColors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _currentSectionAccent().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _searchQuery.isEmpty ? 'All visible' : 'Filtered',
                    style: GoogleFonts.inter(
                      color: _currentSectionAccent(),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(height: 1, color: HandsColors.white12),
          ),
          // Allow both vertical and horizontal scrolling for large tables on web
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = constraints.maxWidth;
                final tableWidth = math.max(viewportWidth, 1000.0).toDouble();

                return Scrollbar(
                  controller: _verticalTableController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalTableController,
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: SizedBox(
                        width: tableWidth,
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: HandsColors.white12),
                          child: DataTable(
                            columnSpacing: 18,
                            horizontalMargin: 12,
                            headingRowHeight: 38,
                            dataRowMinHeight: 42,
                            dataRowMaxHeight: 46,
                            sortColumnIndex: _sortColumnIndex,
                            sortAscending: _sortAscending,
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFF1C2129),
                            ),
                            dataRowColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              return states.contains(WidgetState.selected)
                                  ? HandsColors.secondaryContainer
                                  : Colors.transparent;
                            }),
                            headingTextStyle: GoogleFonts.inter(
                              color: HandsColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                            dataTextStyle: GoogleFonts.inter(
                              color: HandsColors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                            showBottomBorder: true,
                            dividerThickness: 1,
                            columns: columns,
                            rows: paginatedRows.map(buildRow).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildPaginationControls(rows.length),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _paginateRows(List<Map<String, dynamic>> rows) {
    print(
      '[WEB_admin_dashboard_page] _paginateRows called with ${rows.length} rows, _rowsPerPage=$_rowsPerPage, _currentPage=$_currentPage',
    );

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, rows.length);

    print(
      '[WEB_admin_dashboard_page] Pagination: startIndex=$startIndex, endIndex=$endIndex',
    );

    if (startIndex >= rows.length) {
      print(
        '[WEB_admin_dashboard_page] startIndex >= rows.length, returning empty list',
      );
      return [];
    }

    final result = rows.sublist(startIndex, endIndex);
    print('[WEB_admin_dashboard_page] Returning ${result.length} rows');
    return result;
  }

  Widget _buildPaginationControls(int totalRows) {
    // Guard against zero rows; previous logic caused clamp(1,0) ArgumentError when totalRows == 0
    final totalPages = totalRows == 0 ? 0 : (totalRows / _rowsPerPage).ceil();
    // Use a local page index for display to avoid mutating state during build
    final displayPage =
        (totalPages == 0)
            ? 0
            : _currentPage.clamp(
              0,
              totalPages - 1,
            ); // clamp in case underlying data shrank
    final hasNextPage = totalPages == 0 ? false : displayPage < totalPages - 1;
    final hasPreviousPage = totalPages == 0 ? false : displayPage > 0;
    final startRow = totalRows == 0 ? 0 : displayPage * _rowsPerPage + 1;
    final endRow =
        totalRows == 0
            ? 0
            : (((displayPage + 1) * _rowsPerPage) > totalRows
                ? totalRows
                : ((displayPage + 1) * _rowsPerPage));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF141920),
        border: Border(top: BorderSide(color: HandsColors.white12, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalRows == 0
                ? 'Showing 0 of 0'
                : 'Showing $startRow-$endRow of $totalRows',
            style: GoogleFonts.inter(
              color: HandsColors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  print(
                    '[WEB_admin_dashboard_page] Custom dropdown tapped, cycling rows per page',
                  );
                  // Cycle through pagination options without any complex widgets
                  final currentValue = AdminDashboardState.rowsPerPage;
                  final options = [5, 10, 25, 50, 100];
                  final currentIndex = options.indexOf(currentValue);
                  final nextIndex = (currentIndex + 1) % options.length;
                  final newValue = options[nextIndex];

                  print(
                    '[WEB_admin_dashboard_page] Cycling from $currentValue to $newValue',
                  );
                  AdminDashboardState.rowsPerPage = newValue;
                  AdminDashboardState.currentPage = 0;
                  print(
                    '[WEB_admin_dashboard_page] Updated AdminDashboardState: rowsPerPage = ${AdminDashboardState.rowsPerPage}, currentPage = ${AdminDashboardState.currentPage}',
                  );

                  // Test if simple setState works without route rebuilds
                  if (mounted) {
                    setState(() {
                      // Simple state update
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: HandsColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HandsColors.white30, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_rowsPerPage per page',
                        style: GoogleFonts.comfortaa(
                          color: HandsColors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.refresh,
                        color: HandsColors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color:
                    hasPreviousPage ? HandsColors.white : HandsColors.white30,
                onPressed:
                    hasPreviousPage
                        ? () {
                          AdminDashboardState.currentPage =
                              AdminDashboardState.currentPage - 1;
                          // TESTING: No setState to avoid route rebuilds
                        }
                        : null,
              ),
              Text(
                totalPages == 0
                    ? 'Page 0 of 0'
                    : 'Page ${displayPage + 1} of $totalPages',
                style: GoogleFonts.comfortaa(
                  color: HandsColors.white70,
                  fontSize: 12,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: hasNextPage ? HandsColors.white : HandsColors.white30,
                onPressed:
                    hasNextPage
                        ? () {
                          AdminDashboardState.currentPage =
                              AdminDashboardState.currentPage + 1;
                          // TESTING: No setState to avoid route rebuilds
                        }
                        : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // _buildEditDrawer removed - edit drawer was unused after removing the admin sidebar

  IconData _currentSectionIcon() {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        return Icons.schedule_rounded;
      case WebAdminTab.checklists:
        return Icons.library_books_rounded;
      case WebAdminTab.users:
        return Icons.group_rounded;
      case WebAdminTab.locations:
        return Icons.location_on_rounded;
    }
  }

  Color _currentSectionAccent() {
    return _accentForTab(_currentTab);
  }

  Color _accentForTab(WebAdminTab tab) {
    switch (tab) {
      case WebAdminTab.shifts:
        return const Color(0xFF4DA3FF);
      case WebAdminTab.checklists:
        return const Color(0xFF49C98A);
      case WebAdminTab.users:
        return const Color(0xFFFF8A4C);
      case WebAdminTab.locations:
        return const Color(0xFFF4B844);
    }
  }

  String _currentSectionEyebrow() {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        return context.l10n.webAdminSectionEyebrowShifts;
      case WebAdminTab.checklists:
        return context.l10n.webAdminSectionEyebrowChecklists;
      case WebAdminTab.users:
        return context.l10n.webAdminSectionEyebrowUsers;
      case WebAdminTab.locations:
        return context.l10n.webAdminSectionEyebrowLocations;
    }
  }

  String _currentSectionTitle() {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        return context.l10n.webAdminSectionTitleShifts;
      case WebAdminTab.checklists:
        return context.l10n.webAdminSectionTitleChecklists;
      case WebAdminTab.users:
        return context.l10n.webAdminSectionTitleUsers;
      case WebAdminTab.locations:
        return context.l10n.webAdminSectionTitleLocations;
    }
  }

  String _currentSectionSubtitle() {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        return context.l10n.webAdminSectionSubtitleShifts;
      case WebAdminTab.checklists:
        return context.l10n.webAdminSectionSubtitleChecklists;
      case WebAdminTab.users:
        return context.l10n.webAdminSectionSubtitleUsers;
      case WebAdminTab.locations:
        return context.l10n.webAdminSectionSubtitleLocations;
    }
  }

  List<String> _currentSectionHelpTopics() {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        return const ['admin-create-shift', 'admin-attach-workflow'];
      case WebAdminTab.checklists:
        return const ['admin-checklist-library', 'admin-attach-workflow'];
      case WebAdminTab.users:
        return const ['admin-invite-team'];
      case WebAdminTab.locations:
        return const ['admin-first-location', 'admin-multi-location'];
    }
  }

  String _currentSectionTableSubtitle() {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        return context.l10n.webAdminSectionTableSubtitleShifts;
      case WebAdminTab.checklists:
        return context.l10n.webAdminSectionTableSubtitleChecklists;
      case WebAdminTab.users:
        return context.l10n.webAdminSectionTableSubtitleUsers;
      case WebAdminTab.locations:
        return context.l10n.webAdminSectionTableSubtitleLocations;
    }
  }

  String _getTabDisplayName({bool singular = false}) {
    switch (_currentTab) {
      case WebAdminTab.shifts:
        return singular
            ? context.l10n.webAdminTabShift
            : context.l10n.adminViewShifts;
      case WebAdminTab.checklists:
        return singular
            ? context.l10n.webAdminTabTemplate
            : context.l10n.adminViewChecklistLibrary;
      case WebAdminTab.users:
        return singular
            ? context.l10n.webAdminTabTeamMember
            : context.l10n.adminViewTeam;
      case WebAdminTab.locations:
        return singular
            ? context.l10n.webAdminTabLocation
            : context.l10n.adminViewLocations;
    }
  }

  // Global overlay dialog that completely bypasses navigation
  Future<bool?> _showStableDialog({
    required Widget Function(void Function(bool?)) builder,
  }) async {
    final completer = Completer<bool?>();
    OverlayEntry? overlayEntry;

    void closeDialog(bool? result) {
      if (!completer.isCompleted) {
        overlayEntry?.remove();
        completer.complete(result);
      }
    }

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Material(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () => closeDialog(false),
            child: Container(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {}, // Prevent tap through
                child: builder(closeDialog),
              ),
            ),
          ),
        );
      },
    );

    // Add overlay to the root overlay
    Overlay.of(context, rootOverlay: true).insert(overlayEntry);

    return completer.future;
  }

  Future<void> _deleteShift(Map<String, dynamic> shift) async {
    final l10n = context.l10n;
    print(
      '🔴 DELETE SHIFT BUTTON CLICKED! Shift: ${shift['name']} (${shift['id']})',
    );

    // Capture context before dialog to avoid mounting issues
    final currentContext = context;
    final orgId = widget.organizationId;
    final shiftId = shift['id'] as String;

    final ok = await _showStableDialog(
      builder: (closeDialog) {
        print('🔴 SHIFT DELETE DIALOG BUILDING!');
        return AlertDialog(
          title: Text(l10n.webAdminDeleteShiftTitle),
          content: Text(l10n.webAdminDeleteShiftBody('${shift['name']}')),
          actions: [
            TextButton(
              onPressed: () {
                print('🔴 SHIFT DELETE CANCELLED');
                closeDialog(false);
              },
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                print('🔴 SHIFT DELETE CONFIRMED');
                closeDialog(true);
              },
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (ok != true) {
      print('🔴 SHIFT DELETE CANCELLED BY USER');
      return;
    }

    // Execute deletion regardless of mounted state
    print('🔴 SHIFT DELETE PROCEEDING... (ignoring mounted state: $mounted)');

    // Use captured values instead of widget state
    try {
      print('🔴 SHIFT DELETE: Starting Firestore operation...');
      final shiftRef = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(orgId)
          .collection('shifts')
          .doc(shiftId);
      final snap = await shiftRef.get();
      if (!snap.exists) {
        print('🔴 SHIFT DELETE: Document does not exist');
        return;
      }
      final data = snap.data() as Map<String, dynamic>;
      final List<String> locs =
          (data['locationIds'] is Iterable)
              ? List<String>.from(data['locationIds'])
              : (data['locationIds'] is String &&
                  (data['locationIds'] as String).isNotEmpty)
              ? [data['locationIds'] as String]
              : <String>[];

      if (_selectedLocationId != null && _selectedLocationId!.isNotEmpty) {
        print('🔴 SHIFT DELETE: Removing from location $_selectedLocationId');
        final newLocs = List<String>.from(locs)..remove(_selectedLocationId);
        if (newLocs.isEmpty) {
          print('🔴 SHIFT DELETE: No locations left, deleting entire shift');
          await shiftRef.delete();
        } else {
          print('🔴 SHIFT DELETE: Updating locations list');
          await shiftRef.update({
            'locationIds': newLocs,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        print('🔴 SHIFT DELETE: No location filter, deleting entire shift');
        await shiftRef.delete();
      }

      print('🔴 SHIFT DELETE: Firestore operation completed successfully');

      // Only show snackbar if context is still valid
      if (currentContext.mounted) {
        try {
          ScaffoldMessenger.of(
            currentContext,
          ).showSnackBar(SnackBar(content: Text(l10n.webAdminShiftUpdated)));
        } catch (e) {
          print(
            '🔴 SHIFT DELETE: Could not show snackbar (context invalid): $e',
          );
        }
      }
    } catch (e, st) {
      print('🔴 SHIFT DELETE ERROR: $e');
      logger.e('Failed to update shift', e, st);
      if (currentContext.mounted) {
        try {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text(l10n.webAdminShiftUpdateFailed('$e'))),
          );
        } catch (contextError) {
          print(
            '🔴 SHIFT DELETE: Could not show error snackbar (context invalid): $contextError',
          );
        }
      }
    }
  }

  Future<void> _toggleChecklistArchived(Map<String, dynamic> checklist) async {
    final l10n = context.l10n;
    final archived = (checklist['archived'] ?? false) == true;
    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('checklist_templates')
          .doc(checklist['id'])
          .update({
            'archived': !archived,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      _showSnackBar(
        archived
            ? l10n.webAdminTemplateRestored
            : l10n.webAdminTemplateArchived,
      );
    } catch (e) {
      _showSnackBar(l10n.webAdminChecklistUpdateFailed, isError: true);
    }
  }

  Future<void> _deleteChecklist(Map<String, dynamic> checklist) async {
    final l10n = context.l10n;
    print(
      '🔴 DELETE BUTTON CLICKED! Checklist: ${checklist['name']} (${checklist['id']})',
    );
    logger.i(
      '[WEBAdminDashboard] Starting checklist deletion for: ${checklist['id']} - "${checklist['name']}"',
    );

    // Capture all necessary data BEFORE showing dialog
    final currentContext = context;
    final currentOrgId = widget.organizationId;
    final checklistId = checklist['id'] as String;
    final checklistName = checklist['name'] as String;

    // Create a standalone deletion function that doesn't depend on widget state
    Future<void> executeChecklistDeletion() async {
      try {
        logger.i('[WEBAdminDashboard] User confirmed deletion, proceeding...');

        final orgRef = FirestoreEnforcer.instance
            .collection('organizations')
            .doc(currentOrgId);

        // Delete the checklist template
        logger.i(
          '[WEBAdminDashboard] Attempting to delete checklist document: $checklistId',
        );
        final checklistRef = orgRef
            .collection('checklist_templates')
            .doc(checklistId);
        await checklistRef.delete();
        logger.i(
          '[WEBAdminDashboard] Delete operation completed, verifying...',
        );

        // Verify deletion (surface a clear error if blocked by rules)
        final verifySnap = await checklistRef.get();
        if (verifySnap.exists) {
          logger.e(
            '[WEBAdminDashboard] Verification failed: document still exists after delete',
          );
          throw Exception(
            'Checklist still exists after delete; check Firestore rules or references',
          );
        }
        logger.i(
          '[WEBAdminDashboard] Verification passed: document successfully deleted',
        );

        // Remove references from shifts
        logger.i(
          '[WEBAdminDashboard] Removing checklist references from shifts...',
        );
        final shiftsSnap = await orgRef.collection('shifts').get();
        WriteBatch batch = FirestoreEnforcer.instance.batch();
        int ops = 0;
        int shiftsUpdated = 0;
        for (final s in shiftsSnap.docs) {
          final data = s.data();
          final List<dynamic> tidsDyn =
              (data['checklistTemplateIds'] as List?) ?? const [];
          final filtered = tidsDyn.where((e) => e != checklistId).toList();
          if (filtered.length != tidsDyn.length) {
            batch.update(s.reference, {'checklistTemplateIds': filtered});
            ops++;
            shiftsUpdated++;
            if (ops >= 450) {
              await batch.commit();
              batch = FirestoreEnforcer.instance.batch();
              ops = 0;
            }
          }
        }
        if (ops > 0) await batch.commit();
        logger.i(
          '[WEBAdminDashboard] Updated $shiftsUpdated shifts to remove checklist references',
        );

        // Wait a moment for Firestore streams to propagate the deletion
        await Future.delayed(const Duration(milliseconds: 500));

        logger.i('[WEBAdminDashboard] Reloading checklists table...');

        if (currentContext.mounted) {
          try {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text(l10n.webAdminTemplateDeleted)),
            );
          } catch (e) {
            print(
              '🔴 CHECKLIST DELETE: Could not show snackbar (context invalid): $e',
            );
          }
          logger.i('[WEBAdminDashboard] Success: checklist deletion completed');
        }
      } catch (e, st) {
        logger.e('[WEBAdminDashboard] Failed to delete checklist: $e', e, st);
        if (currentContext.mounted) {
          try {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text(l10n.webAdminTemplateDeleteFailed('$e'))),
            );
          } catch (contextError) {
            print(
              '🔴 CHECKLIST DELETE: Could not show error snackbar (context invalid): $contextError',
            );
          }
        }
      }
    }

    final confirm = await _showStableDialog(
      builder: (closeDialog) {
        print('🔴 DIALOG BUILDING! About to show delete confirmation');
        return AlertDialog(
          title: Text(l10n.webAdminDeleteTemplateTitle),
          content: Text(l10n.webAdminDeleteTemplateBody(checklistName)),
          actions: [
            TextButton(
              onPressed: () {
                print('🔴 CANCEL CLICKED');
                closeDialog(false);
              },
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                print('🔴 DELETE CONFIRMED');
                closeDialog(true);
              },
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      print('🔴 CHECKLIST DELETE CANCELLED BY USER');
      logger.i('[WEBAdminDashboard] Checklist deletion cancelled by user');
      return;
    }

    // Execute deletion regardless of widget state
    print('🔴 CHECKLIST DELETE PROCEEDING... (widget may be unmounted)');
    await executeChecklistDeletion();
  }

  Future<void> _duplicateLocation(Map<String, dynamic> location) async {
    final l10n = context.l10n;
    try {
      final newData =
          Map<String, dynamic>.from(location)
            ..remove('id')
            ..remove('createdAt')
            ..remove('updatedAt')
            ..['name'] = l10n.webAdminCopyName('${location['name']}')
            ..['createdAt'] = FieldValue.serverTimestamp();
      final ref =
          FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('locations')
              .doc();
      await ref.set(newData);
      _showSnackBar(l10n.webAdminLocationDuplicated);
    } catch (e) {
      _showSnackBar(l10n.webAdminDuplicateFailed, isError: true);
    }
  }

  bool _shouldShowLocationFilter() {
    return _currentTab == WebAdminTab.shifts ||
        _currentTab == WebAdminTab.checklists ||
        _currentTab == WebAdminTab.users;
  }

  ShiftData? _mapToShiftData(Map<String, dynamic> shiftMap) {
    try {
      return ShiftData(
        shiftId: shiftMap['id'] ?? '',
        shiftName: shiftMap['name'] ?? context.l10n.webAdminUnnamedShift,
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
    final l10n = context.l10n;
    // Ensure we always open the editor and avoid throwing on legacy/malformed docs.
    // _mapToShiftData may return null; if so build a resilient fallback using safe
    // coercion helpers and guard with try/catch so the UI still opens.
    logger.i(
      '[WEBAdminDashboard] _editShift invoked for shiftId=${shift?['id']} name=${shift?['name']}',
    );
    ShiftData? shiftData;
    if (shift != null) {
      shiftData = _mapToShiftData(shift);
      if (shiftData == null) {
        // Local helpers to coerce dynamic Firestore values into safe types.
        List<String> coerceStringList(dynamic v) {
          if (v == null) return [];
          if (v is List) {
            return v
                .map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .toList();
          }
          return [v.toString()];
        }

        Map<String, int> coerceIntMap(dynamic v) {
          final out = <String, int>{};
          if (v == null) return out;
          if (v is Map) {
            v.forEach((key, value) {
              try {
                if (value is int) {
                  out[key.toString()] = value;
                } else if (value is String) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) out[key.toString()] = parsed;
                } else if (value is double)
                  out[key.toString()] = value.toInt();
              } catch (_) {}
            });
          }
          return out;
        }

        DateTime? toDate(dynamic v) {
          if (v == null) return null;
          if (v is Timestamp) return v.toDate();
          if (v is DateTime) return v;
          try {
            return DateTime.parse(v.toString());
          } catch (_) {
            return null;
          }
        }

        try {
          shiftData = ShiftData(
            shiftId: shift['id'] ?? '',
            shiftName:
                shift['name'] ??
                shift['shiftName'] ??
                l10n.webAdminUnnamedShift,
            createdAt: toDate(shift['createdAt']) ?? DateTime.now(),
            startTime: shift['startTime'] ?? '',
            endTime: shift['endTime'] ?? '',
            organizationId: widget.organizationId,
            locationIds: coerceStringList(
              shift['locations'] ?? shift['locationIds'] ?? shift['location'],
            ),
            checklistTemplateIds: coerceStringList(
              shift['checklists'] ??
                  shift['checklistTemplateIds'] ??
                  shift['checklistIds'],
            ),
            jobType: coerceStringList(shift['jobType'] ?? shift['jobTypes']),
            staffingLevels: coerceIntMap(shift['staffingLevels']),
            days: coerceStringList(shift['days']),
            repeatsDaily: shift['repeatsDaily'] ?? false,
            activeDays:
                (shift['activeDays'] is List)
                    ? (shift['activeDays'] as List)
                        .map((e) => int.tryParse(e.toString()) ?? 0)
                        .where((i) => i != 0)
                        .toList()
                    : [],
            assignedUserIds: coerceStringList(shift['assignedUserIds']),
            volunteers: coerceStringList(shift['volunteers']),
            published: shift['published'] ?? false,
            shiftDate: toDate(shift['shiftDate']),
            updatedAt: toDate(shift['updatedAt']),
          );
        } catch (e, st) {
          logger.e(
            '[WEBAdminDashboard] Error building fallback ShiftData: $e\n$st',
          );
          // Fallback to minimal ShiftData so the editor still opens.
          shiftData = ShiftData(
            shiftId: shift['id'] ?? '',
            shiftName:
                shift['name'] ??
                shift['shiftName'] ??
                l10n.webAdminUnnamedShift,
            createdAt: DateTime.now(),
            startTime: shift['startTime'] ?? '',
            endTime: shift['endTime'] ?? '',
            organizationId: widget.organizationId,
          );
        }
      }
    }

    // Always attempt to open the edit dialog; if shiftData is null the editor will
    // open in create mode, otherwise it'll populate fields.
    try {
      _showEditDialog(
        ShiftTemplateBottomSheet(
          key: UniqueKey(), // force rebuild each time
          organizationId: widget.organizationId,
          shiftId: shift?['id'],
          shiftData: shiftData,
          availableLocations: _availableLocations,
          selectedLocationId: _selectedLocationId,
          onShiftSaved: () {
            _showSnackBar(
              shift == null
                  ? l10n.webAdminShiftCreated
                  : l10n.webAdminShiftSaved,
            );
          },
        ),
      );
    } catch (e, st) {
      logger.e(
        '[WEBAdminDashboard] Failed to open shift editor dialog: $e\n$st',
      );
      _showSnackBar(l10n.webAdminShiftEditorOpenFailed, isError: true);
    }
  }

  void _duplicateShift(Map<String, dynamic> shift) async {
    final l10n = context.l10n;
    try {
      // Create a copy without the ID
      final newShiftData = Map<String, dynamic>.from(shift);
      newShiftData.remove('id');
      newShiftData['shiftName'] = l10n.webAdminCopyName('${shift['name']}');
      newShiftData['createdAt'] = FieldValue.serverTimestamp();

      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('shifts')
          .add(newShiftData);

      _showSnackBar(l10n.webAdminShiftDuplicated);
    } catch (e) {
      _showSnackBar(l10n.webAdminShiftDuplicateFailed('$e'), isError: true);
    }
  }

  void _toggleShiftActive(Map<String, dynamic> shift) async {
    final l10n = context.l10n;
    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('shifts')
          .doc(shift['id'])
          .update({'isActive': !shift['active']});

      _showSnackBar(
        shift['active']
            ? l10n.webAdminShiftArchived
            : l10n.webAdminShiftRestored,
      );
    } catch (e) {
      _showSnackBar(l10n.webAdminShiftUpdateFailed('$e'), isError: true);
    }
  }

  Future<void> _editChecklist(Map<String, dynamic>? checklist) async {
    final l10n = context.l10n;
    logger.i(
      '[WEBAdminDashboard] _editChecklist invoked for checklistId=${checklist?['id']} name=${checklist?['name']}',
    );

    // Resolve a safe locationId fallback.
    final safeLocationId =
        _selectedLocationId ??
        (_availableLocations.isNotEmpty
            ? (_availableLocations.first['id'] as String? ?? '')
            : '');

    try {
      _showEditDialog(
        ChecklistBottomSheet(
          key: UniqueKey(), // force rebuild each open
          organizationId: widget.organizationId,
          locationId: safeLocationId,
          checklistId: checklist?['id'],
          initialData: checklist,
          availableLocations: _availableLocations,
          onSave: (checklistData) async {
            logger.d(
              '[WEBAdminDashboard] onSave callback triggered with data: ${checklistData.keys}',
            );
            try {
              // Persist checklist to Firestore (save + update shifts + tasks)
              await _saveChecklistFromBottomSheet(
                checklistData,
                existingChecklistId: checklist?['id'],
              );

              // Refresh the cached checklist table so other views reflect the changes
              await _loadChecklistsTable();

              // Show success message
              _showSnackBar(
                checklist == null
                    ? l10n.webAdminTemplateCreated
                    : l10n.webAdminTemplateSaved,
              );
              logger.d('[WEBAdminDashboard] Checklist saved successfully');
            } catch (e) {
              logger.e(
                '[WEBAdminDashboard] Error saving checklist from bottom sheet: $e',
                e,
              );
              // Show error message to user
              _showSnackBar(
                l10n.webAdminTemplateSaveFailed('$e'),
                isError: true,
              );
              // Rethrow to prevent the dialog from closing on error
              rethrow;
            }
          },
        ),
      );
    } catch (e, st) {
      logger.e(
        '[WEBAdminDashboard] Failed to open checklist editor dialog: $e\n$st',
      );
      _showSnackBar(l10n.webAdminTemplateEditorOpenFailed, isError: true);
    }
  }

  void _duplicateChecklist(Map<String, dynamic> checklist) async {
    final l10n = context.l10n;
    try {
      final newChecklistData = Map<String, dynamic>.from(checklist);
      newChecklistData.remove('id');
      newChecklistData['checklistName'] = l10n.webAdminCopyName(
        '${checklist['name']}',
      );
      newChecklistData['createdAt'] = FieldValue.serverTimestamp();

      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('checklist_templates')
          .add(newChecklistData);

      _showSnackBar(l10n.webAdminTemplateDuplicated);
    } catch (e) {
      _showSnackBar(l10n.webAdminTemplateDuplicateFailed('$e'), isError: true);
    }
  }

  /// Persist checklist data coming from the ChecklistBottomSheet.
  /// Minimal implementation mirroring admin save: writes the template doc,
  /// updates shift associations, and replaces subcollection tasks.
  Future<void> _saveChecklistFromBottomSheet(
    Map<String, dynamic> result, {
    String? existingChecklistId,
  }) async {
    if (widget.organizationId.isEmpty) return;

    final checklistData =
        (result['checklistData'] ?? {}) as Map<String, dynamic>;
    final selectedShiftIds =
        (result['selectedShiftIds'] is Iterable)
            ? List<String>.from(result['selectedShiftIds'])
            : <String>[];
    // Newly added: location scoping. The bottom sheet provides selectedLocationIds (additional)
    // and the active location passed as widget.locationId when opened. Persist union as locationIds.
    final additionalLocIds =
        (result['selectedLocationIds'] is Iterable)
            ? List<String>.from(result['selectedLocationIds'])
            : <String>[];
    final Set<String> unionLocs = {
      if (_selectedLocationId != null && _selectedLocationId!.isNotEmpty)
        _selectedLocationId!,
      ...additionalLocIds.where((e) => e.isNotEmpty),
    };
    final checklistTemplatesRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('checklist_templates');
    final Set<String> previousChecklistLocationIds = <String>{};

    if (existingChecklistId != null) {
      try {
        final existingChecklistSnap =
            await checklistTemplatesRef.doc(existingChecklistId).get();
        final existingChecklistData = existingChecklistSnap.data();
        if (existingChecklistData != null) {
          previousChecklistLocationIds.addAll(
            coerceToLocationIds(existingChecklistData['locationIds']),
          );
        }
      } catch (e) {
        logger.w(
          '[WEBAdminDashboard] Unable to load existing checklist locations for $existingChecklistId: $e',
        );
      }
    }
    final batch = FirestoreEnforcer.instance.batch();

    final mainChecklistRef =
        existingChecklistId != null
            ? checklistTemplatesRef.doc(existingChecklistId)
            : checklistTemplatesRef
                .doc(); // Auto-generate ID for new checklists
    final mainChecklistId = mainChecklistRef.id;

    final tasksArray =
        (checklistData['tasks'] is List)
            ? List<Map<String, dynamic>>.from(checklistData['tasks'])
            : <Map<String, dynamic>>[];

    final checklistDocPayload = {
      ...checklistData,
      'taskCount': tasksArray.length,
      'updatedAt': FieldValue.serverTimestamp(),
      if (unionLocs.isNotEmpty) 'locationIds': unionLocs.toList(),
      if (existingChecklistId == null)
        'createdAt': FieldValue.serverTimestamp(),
    };

    batch.set(mainChecklistRef, checklistDocPayload, SetOptions(merge: true));

    final shiftsCollection = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('shifts');

    if (existingChecklistId != null) {
      final shiftsWithChecklistSnapshot =
          await shiftsCollection
              .where('checklistTemplateIds', arrayContains: existingChecklistId)
              .get();

      for (final shiftDoc in shiftsWithChecklistSnapshot.docs) {
        if (!selectedShiftIds.contains(shiftDoc.id)) {
          batch.update(shiftDoc.reference, {
            'checklistTemplateIds': FieldValue.arrayRemove([
              existingChecklistId,
            ]),
          });
        }
      }
    }

    for (final shiftId in selectedShiftIds) {
      batch.update(shiftsCollection.doc(shiftId), {
        'checklistTemplateIds': FieldValue.arrayUnion([mainChecklistId]),
      });
    }

    try {
      await batch.commit();

      // Replace tasks in the checklist's tasks subcollection
      final tasksColl = mainChecklistRef.collection('tasks');
      final existingTasks = await tasksColl.get();
      if (existingTasks.docs.isNotEmpty) {
        final delBatch = FirestoreEnforcer.instance.batch();
        for (final d in existingTasks.docs) {
          delBatch.delete(d.reference);
        }
        await delBatch.commit();
      }

      if (tasksArray.isNotEmpty) {
        // Add new tasks with auto IDs
        WriteBatch addBatch = FirestoreEnforcer.instance.batch();
        int opCount = 0;
        for (final t in tasksArray) {
          final docRef = tasksColl.doc();
          addBatch.set(docRef, {
            'taskName': t['name'] ?? t['taskName'] ?? 'Untitled Task',
            'name': t['name'] ?? t['taskName'] ?? 'Untitled Task',
            'photoRequired': t['photoRequired'] ?? false,
            'order': t['order'] ?? 0,
            'organizationId': widget.organizationId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          opCount++;
          if (opCount >= 450) {
            await addBatch.commit();
            addBatch = FirestoreEnforcer.instance.batch();
            opCount = 0;
          }
        }
        if (opCount > 0) await addBatch.commit();
      }

      try {
        final dcs = DailyChecklistService();
        final now = DateTime.now();
        final dateStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final checklistLocationIds =
            {
              ...unionLocs,
              ...previousChecklistLocationIds,
            }.where((id) => id.isNotEmpty).toList();

        for (final locationId in checklistLocationIds) {
          final existingDaily =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(widget.organizationId)
                  .collection('locations')
                  .doc(locationId)
                  .collection('daily_checklists')
                  .where('date', isEqualTo: dateStr)
                  .where('checklistTemplateId', isEqualTo: mainChecklistId)
                  .get();

          for (final checklistDoc in existingDaily.docs) {
            try {
              await dcs.reseedChecklistTasksFromTemplate(
                organizationId: widget.organizationId,
                locationId: locationId,
                checklistId: checklistDoc.id,
              );
            } catch (e) {
              logger.e(
                '[WEBAdminDashboard] Error reseeding checklist ${checklistDoc.id}: $e',
              );
            }
          }
        }
      } catch (e) {
        logger.e('[WEBAdminDashboard] Reseed step failed: $e');
      }

      logger.d(
        '[WEBAdminDashboard] Successfully saved checklist with ${tasksArray.length} tasks',
      );
    } catch (e, st) {
      logger.e('[WEBAdminDashboard] Error persisting checklist: $e\n$st');
      // Rethrow the error so the calling function can handle it properly
      rethrow;
    }
  }

  void _editUser(Map<String, dynamic>? user) {
    _showEditDialog(
      UserManagementBottomSheet(userData: user, userId: user?['id']),
    );
  }

  void _toggleUserActive(Map<String, dynamic> user) async {
    final l10n = context.l10n;
    try {
      await FirestoreEnforcer.instance
          .collection('users')
          .doc(user['id'])
          .update({'isActive': !user['isActive']});

      _showSnackBar(
        user['isActive']
            ? l10n.webAdminUserDeactivated
            : l10n.webAdminUserActivated,
      );
    } catch (e) {
      _showSnackBar(l10n.webAdminUserUpdateFailed('$e'), isError: true);
    }
  }

  void _editLocation(Map<String, dynamic>? location) {
    final l10n = context.l10n;
    _showEditDialog(
      LocationWizard(
        organizationId: widget.organizationId,
        locationId: location?['id'],
        initialData: location,
        onCompleted: () {
          // LocationWizard now handles closing automatically
          _showSnackBar(
            location == null
                ? l10n.webAdminLocationCreated
                : l10n.webAdminLocationSaved,
          );
          _loadLocations(); // Refresh locations list
        },
      ),
    );
  }

  void _toggleLocationActive(Map<String, dynamic> location) async {
    final l10n = context.l10n;
    try {
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('locations')
          .doc(location['id'])
          .update({'isActive': !location['isActive']});

      _showSnackBar(
        location['isActive']
            ? l10n.webAdminLocationArchived
            : l10n.webAdminLocationRestored,
      );
    } catch (e) {
      _showSnackBar(l10n.webAdminLocationUpdateFailed('$e'), isError: true);
    }
  }

  void _deleteLocation(Map<String, dynamic> location) async {
    final l10n = context.l10n;
    print(
      '🔴 DELETE LOCATION BUTTON CLICKED! Location: ${location['name']} (${location['id']})',
    );

    // Capture all necessary data BEFORE showing dialog
    final currentContext = context;
    final currentOrgId = widget.organizationId;
    final locationId = location['id'] as String;
    final locationName = location['name'] as String;

    // Create a standalone deletion function that doesn't depend on widget state
    Future<void> executeLocationDeletion() async {
      try {
        print('🔴 CALLING FIRESTORE DELETE FOR LOCATION $locationId');

        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(currentOrgId)
            .collection('locations')
            .doc(locationId)
            .delete();

        print('🔴 LOCATION DELETE SUCCESSFUL');

        // Show success message using the captured context
        if (currentContext.mounted) {
          try {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text(l10n.webAdminLocationDeleted)),
            );
          } catch (e) {
            print(
              '🔴 LOCATION DELETE: Could not show snackbar (context invalid): $e',
            );
          }
        }
      } catch (e) {
        print('🔴 LOCATION DELETE ERROR: $e');
        if (currentContext.mounted) {
          try {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text(l10n.webAdminLocationDeleteFailed('$e'))),
            );
          } catch (contextError) {
            print(
              '🔴 LOCATION DELETE: Could not show error snackbar (context invalid): $contextError',
            );
          }
        }
      }
    }

    final confirm = await _showStableDialog(
      builder: (closeDialog) {
        print('🔴 LOCATION DELETE DIALOG BUILDING!');
        return AlertDialog(
          backgroundColor: HandsColors.cardPrimary,
          title: Text(
            l10n.webAdminDeleteLocationTitle,
            style: GoogleFonts.comfortaa(color: HandsColors.white),
          ),
          content: Text(
            l10n.webAdminDeleteLocationBody(locationName),
            style: GoogleFonts.comfortaa(color: HandsColors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('🔴 LOCATION DELETE CANCELLED');
                closeDialog(false);
              },
              child: Text(
                l10n.commonCancel,
                style: GoogleFonts.comfortaa(color: HandsColors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                print('🔴 LOCATION DELETE CONFIRMED');
                closeDialog(true);
              },
              child: Text(
                l10n.commonDelete,
                style: GoogleFonts.comfortaa(color: HandsColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      print('🔴 LOCATION DELETE CANCELLED BY USER');
      return;
    }

    // Execute deletion regardless of widget state
    print('🔴 LOCATION DELETE PROCEEDING... (widget may be unmounted)');
    await executeLocationDeletion();
  }

  Future<void> _deleteUser(String userId) async {
    // Execute deletion operations completely independently of widget state
    try {
      logger.d(
        '[WEBAdminDashboard] Starting user deletion for userId: $userId',
      );

      // Call server-side callable 'deleteUser' to remove Auth record + Firestore doc atomically
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('deleteUser');

      logger.d(
        '[WEBAdminDashboard] Calling deleteUser function with uid: $userId',
      );

      final resp = await callable.call(<String, dynamic>{'uid': userId});
      final data = resp.data as Map<String, dynamic>?;

      logger.d('[WEBAdminDashboard] deleteUser function response: $data');

      // Reload data without depending on widget state
      await _reloadAllTables();

      print('🔴 USER DELETE: Operation completed successfully');
    } on FirebaseFunctionsException catch (e) {
      logger.e(
        '[WEBAdminDashboard] FirebaseFunctionsException: code=${e.code}, message=${e.message}, details=${e.details}',
        e,
      );

      // If the function doesn't exist or fails, try fallback deletion (Firestore only)
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        logger.w(
          '[WEBAdminDashboard] Cloud function not found, attempting Firestore-only deletion',
        );
        await _deleteUserFallback(userId);
      } else {
        print('🔴 USER DELETE ERROR: ${e.message} (Code: ${e.code})');
        rethrow;
      }
    } catch (e) {
      logger.e('[WEBAdminDashboard] deleteUser callable error: $e', e);

      // Try fallback deletion
      logger.w(
        '[WEBAdminDashboard] Attempting fallback Firestore-only deletion',
      );
      await _deleteUserFallback(userId);
    }
  }

  Future<void> _deleteUserFallback(String userId) async {
    try {
      logger.d(
        '[WEBAdminDashboard] Starting fallback user deletion for userId: $userId',
      );

      // Delete user document from Firestore (Auth record will remain)
      await FirestoreEnforcer.instance.collection('users').doc(userId).delete();

      logger.d(
        '[WEBAdminDashboard] User document deleted from Firestore: $userId',
      );

      await _reloadAllTables();
      print('🔴 USER DELETE FALLBACK: Operation completed successfully');
    } catch (e) {
      logger.e('[WEBAdminDashboard] Fallback deletion error: $e', e);
      print('🔴 USER DELETE FALLBACK ERROR: $e');
      rethrow;
    }
  }
}
