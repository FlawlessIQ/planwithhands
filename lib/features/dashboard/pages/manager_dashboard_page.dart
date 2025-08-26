import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/services/organization_setup_service.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/widgets/organization_setup_widget.dart';

class ManagerDashboardPage extends StatefulWidget {
  final String organizationId;
  const ManagerDashboardPage({super.key, required this.organizationId});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage> {
  // User / setup
  int? userRole;
  bool _isLoadingUserRole = true;
  final OrganizationSetupService _setupService = OrganizationSetupService();
  bool _metricsEnabled = false;
  bool _isLoadingSetupStatus = true;

  // Date helpers
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  late final String _todayKey;

  // Locations
  String? _selectedLocationId;
  String? _selectedLocationName;
  List<Map<String, dynamic>> _availableLocations = [];
  bool _isLoadingLocations = true;

  // Missed yesterday
  List<Map<String, dynamic>> _yesterdayMissed = [];
  bool _loadingYesterday = true;

  // 7d trend for missed
  List<int> _missedTrend7d = List<int>.filled(7, 0, growable: false);

  // Live shifts
  List<Map<String, dynamic>> _liveShifts = [];
  bool _loadingLive = true;
  String? _selectedStatusFilter = 'live'; // Changed from role to status filter
  Timer? _refreshTimer;

  // Historic insights
  List<Map<String, dynamic>> _frequentMisses30d = [];
  bool _loadingFrequent = true;
  List<Map<String, dynamic>> _poorShifts30d = [];
  bool _loadingPoorShifts = true;

  // History filters
  DateTimeRange? _selectedDateRange;

  List<Map<String, String>> _shifts = [];
  List<Map<String, String>> _checklists = [];

  // Global location selection service
  final LocationSelectionService _locationSelectionService = LocationSelectionService.instance;

  @override
  void initState() {
    super.initState();
    _todayKey = _dateFormat.format(DateTime.now());
    // Seed from global selection if present before loading
    final globalLoc = _locationSelectionService.currentLocationId;
    if (globalLoc != null && globalLoc.isNotEmpty) {
      _selectedLocationId = globalLoc;
    }
    // Listen for global selection changes
    _locationSelectionService.listenable.addListener(_onGlobalLocationChanged);
    _initializeDashboard();
  }

  // Progressive loading strategy for better performance
  Future<void> _initializeDashboard() async {
    // Phase 1: Essential setup (fast)
    try {
      await Future.wait([_fetchUserRole(), _checkSetupStatus(), _loadLocations()]).timeout(const Duration(seconds: 5));
    } catch (e) {
      logger.e('[Dashboard] Phase 1 initialization failed: $e');
      // Continue with reduced functionality
    }

    // Phase 2: Critical dashboard data (prioritized)
    _loadCriticalData();

    // Phase 3: Background data loading (non-blocking)
    _loadBackgroundData();

    _startAutoRefresh();
  }

  // Load essential data that users see first
  Future<void> _loadCriticalData() async {
    try {
      // Load today's shifts first (most important)
      await _loadLiveShifts().timeout(const Duration(seconds: 8));

      // Then load yesterday's missed tasks
      await _loadYesterdayMissed().timeout(const Duration(seconds: 8));
    } catch (e) {
      logger.e('[Dashboard] Critical data loading failed: $e');
      // Show error state or fallback data
    }
  }

  // Load less critical data in background
  Future<void> _loadBackgroundData() async {
    // Load these without blocking the UI
    _loadMissedTrend7d().timeout(const Duration(seconds: 10)).catchError((e) {
      logger.e('[Dashboard] Missed trend loading failed: $e');
    });
    _loadFrequentMisses30d().timeout(const Duration(seconds: 15)).catchError((e) {
      logger.e('[Dashboard] Frequent misses loading failed: $e');
    });
    _loadPoorShifts30d().timeout(const Duration(seconds: 15)).catchError((e) {
      logger.e('[Dashboard] Poor shifts loading failed: $e');
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Remove global listener
    _locationSelectionService.listenable.removeListener(_onGlobalLocationChanged);
    super.dispose();
  }

  Future<void> _onGlobalLocationChanged() async {
    if (!mounted) return;
    final globalId = _locationSelectionService.currentLocationId;
    if (globalId == _selectedLocationId) return; // no change
    // Resolve name if we already have locations loaded
    String? locName;
    if (_availableLocations.isNotEmpty && globalId != null) {
      try {
        final match = _availableLocations.firstWhere((l) => l['id'] == globalId);
        locName = match['name'] as String?;
      } catch (_) {}
    }
    setState(() {
      _selectedLocationId = globalId;
      if (locName != null) _selectedLocationName = locName;
    });
    if (globalId != null && globalId.isNotEmpty) {
      try {
        await _loadFilterOptions();
        await _loadAll();
      } catch (e) {
        logger.w('[ManagerDashboard] _onGlobalLocationChanged reload failed: $e');
      }
    }
  }

  // ===== Data Loading =====

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingUserRole = false);
      return;
    }
    final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
    if (!mounted) return;
    setState(() {
      userRole = userDoc.data()?['userRole'] ?? 1;
      _isLoadingUserRole = false;
    });
  }

  Future<void> _checkSetupStatus() async {
    setState(() => _isLoadingSetupStatus = true);
    try {
      final isEnabled = await _setupService.isMetricsTrackingEnabled(widget.organizationId);
      if (!mounted) return;
      setState(() {
        _metricsEnabled = isEnabled;
        _isLoadingSetupStatus = false;
      });
      if (_metricsEnabled) {
        await _ensureDailyChecklistsExist();
      }
    } catch (e) {
      logger.e('[ManagerDashboard] Error checking setup status: $e');
      if (!mounted) return;
      setState(() {
        _metricsEnabled = false;
        _isLoadingSetupStatus = false;
      });
    }
  }

  Future<void> _ensureDailyChecklistsExist() async {
    // Temporarily disabled to isolate login issues
    // try {
    //   final service = DailyChecklistService();
    //   await service.generateAllDailyChecklistsForDate(organizationId: widget.organizationId, date: _todayKey);
    // } catch (e) {
    //   logger.w('[ManagerDashboard] generateAllDailyChecklistsForDate failed: $e');
    // }
  }

  Future<void> _loadLocations() async {
    try {
      // Get locations directly from Firestore
      final locationsQuery =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('locations')
              .get();

      final locations =
          locationsQuery.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['locationName'] as String? ?? 'Unknown Location',
              'isPrimary': data['isPrimary'] as bool? ?? false,
            };
          }).toList();

      // Determine the location to use using a global-first policy:
      // 1) If a persisted global location exists and is valid for this org, prefer it.
      // 2) Else if the current local selection is valid, keep it.
      // 3) Else pick the primary/first location as a fallback.
      final globalId = LocationSelectionService.instance.currentLocationId;
      String? locationToSelect;
      String? locationToSelectName;

      final hasGlobalValid = globalId != null && locations.any((l) => l['id'] == globalId);
      final currentIsValid = _selectedLocationId != null && locations.any((l) => l['id'] == _selectedLocationId);

      if (hasGlobalValid) {
        locationToSelect = globalId;
        locationToSelectName = locations.firstWhere((l) => l['id'] == globalId)['name'] as String?;
      } else if (currentIsValid) {
        locationToSelect = _selectedLocationId;
        locationToSelectName = locations.firstWhere((l) => l['id'] == _selectedLocationId)['name'] as String?;
      } else if (locations.isNotEmpty) {
        final primary = locations.firstWhere((l) => l['isPrimary'] == true, orElse: () => locations.first);
        locationToSelect = primary['id'] as String?;
        locationToSelectName = primary['name'] as String?;
      }

      if (!mounted) return;
      setState(() {
        _availableLocations = locations;
        _selectedLocationId = locationToSelect ?? _selectedLocationId;
        _selectedLocationName = locationToSelectName ?? _selectedLocationName;
      });

      // Ensure the global service matches the decided selection
      if (_selectedLocationId != null && LocationSelectionService.instance.currentLocationId != _selectedLocationId) {
        LocationSelectionService.instance.setLocation(_selectedLocationId!);
      }

      if (_selectedLocationId != null) {
        await _loadFilterOptions();
        await _loadAll();
      }
    } catch (e) {
      logger.e('Error loading locations: $e', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load locations: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocations = false);
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    // Shifts (for filters)
    final shiftsSnap =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('shifts')
            .where('locationIds', arrayContains: _selectedLocationId)
            .get();

    // Checklist templates (for filters)
    final templatesSnap =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('checklist_templates')
            .get();

    if (!mounted) return;
    setState(() {
      _shifts =
          shiftsSnap.docs
              .map((d) => {'id': d.id, 'name': (d.data()['shiftName'] ?? 'Unnamed Shift').toString()})
              .toList();
      _checklists =
          templatesSnap.docs
              .map((d) => {'id': d.id, 'name': (d.data()['name'] ?? 'Unnamed Checklist').toString()})
              .toList();
    });
  }

  // Optimized loading - now just triggers the progressive loading sequence
  Future<void> _loadAll() async {
    await _loadCriticalData();
    _loadBackgroundData();
  }

  Future<void> _loadYesterdayMissed() async {
    setState(() {
      _loadingYesterday = true;
    });
    try {
      final service = DailyChecklistService();
      final today = DateTime.now();

      logger.d(
        '[ManagerDashboard] Starting loadYesterdayMissed - today: $today, selectedLocation: $_selectedLocationId',
      );

      // Use the same method as user dashboard to get real-time data from subcollections
      final sections = await service.loadMissedTasksForToday(
        organizationId: widget.organizationId,
        targetDate: today,
        locationId: _selectedLocationId,
      );

      logger.d('[ManagerDashboard] loadMissedTasksForToday returned ${sections.length} sections');

      // Convert sections to the format expected by the manager dashboard
      final Map<String, Map<String, dynamic>> groupedTasks = {};
      for (final section in sections) {
        logger.d('[ManagerDashboard] Processing section: ${section.shiftName} with ${section.tasks.length} tasks');
        for (final task in section.tasks) {
          final taskName = task.taskName;
          final shiftName = section.shiftName;
          final key = '${taskName}_${section.shiftId}';

          logger.d('[ManagerDashboard] Processing task: $taskName, completed: ${task.completed}');

          final group = groupedTasks.putIfAbsent(
            key,
            () => {
              'taskName': taskName,
              'shiftId': section.shiftId,
              'shiftName': shiftName,
              'locationId': section.locationId,
              'count': 0,
              'completedToday': false,
            },
          );

          group['count'] = (group['count'] as int) + 1;
          if (task.completed) {
            group['completedToday'] = true;
          }
        }
      }

      _yesterdayMissed = groupedTasks.values.toList();
      logger.d(
        '[ManagerDashboard] Final result: ${_yesterdayMissed.length} carry-forward groups from yesterday (via subcollections)',
      );
      logger.d(
        '[ManagerDashboard] Groups: ${_yesterdayMissed.map((g) => '${g['taskName']} (${g['shiftName']}): ${g['count']}').join(', ')}',
      );
    } catch (e, st) {
      logger.e('[ManagerDashboard] loadMissedTasksForToday error: $e\n$st');
    } finally {
      if (!mounted) return;
      setState(() => _loadingYesterday = false);
    }
  }

  Future<void> _loadMissedTrend7d() async {
    try {
      logger.d('[ManagerDashboard] Loading 7-day missed tasks trend...');
      final now = DateTime.now();
      final futures = <Future<int>>[];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        futures.add(_countMissedForDate(day));
      }
      final results = await Future.wait(futures);
      if (!mounted) return;
      setState(() => _missedTrend7d = results);
      logger.d(
        '[ManagerDashboard] 7-day trend loaded: $results (total: ${results.fold(0, (sum, val) => sum + val)} missed tasks)',
      );
    } catch (e) {
      logger.w('[ManagerDashboard] _loadMissedTrend7d failed: $e');
    }
  }

  Future<int> _countMissedForDate(DateTime day) async {
    try {
      final service = DailyChecklistService();

      // Use the same subcollection method for consistency
      final sections = await service.loadMissedTasksForToday(
        organizationId: widget.organizationId,
        targetDate: day,
        locationId: _selectedLocationId,
      );

      // Count total missed tasks across all sections
      int totalMissed = 0;
      for (final section in sections) {
        totalMissed += section.tasks.length;
      }

      logger.d('[ManagerDashboard] Counted $totalMissed missed tasks for ${_dateFormat.format(day)}');
      return totalMissed;
    } catch (e) {
      logger.w('[ManagerDashboard] _countMissedForDate failed for ${_dateFormat.format(day)}: $e');
      return 0;
    }
  }

  Future<void> _loadLiveShifts() async {
    setState(() => _loadingLive = true);
    try {
      logger.i('[ManagerDashboard][DEBUG] Entering _loadLiveShifts');
      final todayStr = _todayKey;
      logger.i('[ManagerDashboard][DEBUG] Today string: $todayStr, Selected Location: $_selectedLocationId');
      final shiftsSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('shifts')
              .where('locationIds', arrayContains: _selectedLocationId)
              .get();
      logger.i('[ManagerDashboard][DEBUG] Found ${shiftsSnap.docs.length} shifts for location');

      final List<Map<String, dynamic>> todaysShifts = [];

      for (final shiftDoc in shiftsSnap.docs) {
        final shiftData = shiftDoc.data();
        final shiftName = (shiftData['shiftName'] ?? 'Unnamed Shift').toString();
        final startTime = (shiftData['startTime'] ?? '').toString();
        final endTime = (shiftData['endTime'] ?? '').toString();
        final role = (shiftData['jobType'] ?? shiftData['role'] ?? '').toString();
        logger.i(
          '[ManagerDashboard][DEBUG] Processing shift: $shiftName ($role) $startTime-$endTime, id=${shiftDoc.id}',
        );

        // Compute completion for today
        int totalTasks = 0;
        int completedTasks = 0;
        double completionPct = 0;

        // If no location selected, skip loading checklists for this shift
        if (_selectedLocationId == null || _selectedLocationId!.isEmpty) {
          logger.i(
            '[ManagerDashboard][DEBUG] _loadLiveShifts skipping shift ${shiftDoc.id} because no location selected',
          );
          continue;
        }

        // Query daily_checklists under the selected location (new schema)
        var checklistsSnap =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(widget.organizationId)
                .collection('locations')
                .doc(_selectedLocationId)
                .collection('daily_checklists')
                .where('date', isEqualTo: todayStr)
                .where('shiftId', isEqualTo: shiftDoc.id)
                .limit(50)
                .get();
        logger.i(
          '[ManagerDashboard][DEBUG] Found ${checklistsSnap.docs.length} daily_checklists (location-scoped) for shift $shiftName',
        );

        // If no checklists found under the location-scoped path, try legacy org-root collection
        if (checklistsSnap.docs.isEmpty) {
          logger.i(
            '[ManagerDashboard][DEBUG] No location-scoped daily_checklists found for shift $shiftName; trying org-scoped fallback',
          );
          try {
            final legacySnap =
                await FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(widget.organizationId)
                    .collection('daily_checklists')
                    .where('date', isEqualTo: todayStr)
                    .where('shiftId', isEqualTo: shiftDoc.id)
                    .where('locationId', isEqualTo: _selectedLocationId)
                    .limit(50)
                    .get();
            logger.i(
              '[ManagerDashboard][DEBUG] Org-scoped fallback returned ${legacySnap.docs.length} docs for shift $shiftName',
            );
            if (legacySnap.docs.isNotEmpty) {
              checklistsSnap = legacySnap; // replace local variable with fallback
            }
          } catch (e) {
            logger.w('[ManagerDashboard][DEBUG] Org-scoped fallback failed for shift $shiftName: $e');
          }
        }

        for (final cl in checklistsSnap.docs) {
          final data = cl.data() as Map<String, dynamic>? ?? {};
          List<Map<String, dynamic>> tasks = [];
          logger.i(
            '[ManagerDashboard][DEBUG] Checklist docId: ${cl.id}, has tasks array: "+${data.containsKey('tasks') && data['tasks'] != null}"',
          );

          if (data.containsKey('tasks') && data['tasks'] != null) {
            // Old way: tasks in document
            tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? const []);
            logger.i(
              '[ManagerDashboard][DEBUG] Found ${tasks.length} tasks in document for shift: $shiftName, checklist: ${cl.id}',
            );
          } else {
            // New way: tasks in subcollection
            try {
              final tasksSnap = await cl.reference.collection('tasks').get();
              tasks = tasksSnap.docs.map((taskDoc) => taskDoc.data()).toList();
              logger.i(
                '[ManagerDashboard][DEBUG] Found ${tasks.length} tasks in subcollection for shift: $shiftName, checklist: ${cl.id}',
              );
            } catch (e) {
              logger.e('[ManagerDashboard][DEBUG] Failed to load tasks subcollection for doc ${cl.id}: $e');
            }
          }

          // Filter out carry-forward tasks to avoid contaminating today's shift completion rates
          final todayOnlyTasks = tasks.where((t) => t['isCarryForward'] != true).toList();
          totalTasks += todayOnlyTasks.length;
          for (final t in todayOnlyTasks) {
            final completed = t['completed'] == true || t['isCompleted'] == true || t['status'] == 'completed';
            if (completed) completedTasks += 1;
          }
        }
        logger.i(
          '[ManagerDashboard][DEBUG] Shift $shiftName: $completedTasks/$totalTasks completed (excluding carry-forward)',
        );
        if (totalTasks > 0) completionPct = completedTasks / totalTasks;

        final timeStatus = _calculateTimeStatus(startTime, endTime);

        todaysShifts.add({
          'shiftId': shiftDoc.id,
          'shiftName': shiftName,
          'role': role,
          'startTime': startTime,
          'endTime': endTime,
          'completionPct': completionPct,
          'completedTasks': completedTasks,
          'totalTasks': totalTasks,
          'timeStatus': timeStatus,
        });
      }

      logger.i('[ManagerDashboard][DEBUG] Final live shifts list: $todaysShifts');
      if (!mounted) return;
      setState(() {
        _liveShifts = todaysShifts;
      });
    } catch (e, st) {
      logger.e('[ManagerDashboard][DEBUG] _loadLiveShifts error: $e\n$st', e);
    } finally {
      if (!mounted) return;
      setState(() => _loadingLive = false);
    }
  }

  Future<void> _loadFrequentMisses30d() async {
    setState(() => _loadingFrequent = true);
    try {
      final service = DailyChecklistService();
      final list = await service.getFrequentlyMissedTasks(
        organizationId: widget.organizationId,
        days: 30,
        limit: 10,
        locationId: _selectedLocationId,
      );
      if (!mounted) return;
      setState(() => _frequentMisses30d = list);
    } catch (e, st) {
      logger.e('[ManagerDashboard] getFrequentlyMissedTasks error: $e', e, st);
    } finally {
      if (!mounted) return;
      setState(() => _loadingFrequent = false);
    }
  }

  Future<void> _loadPoorShifts30d() async {
    logger.i('[ManagerDashboard][DEBUG] ALWAYSLOG: Entering _loadPoorShifts30d');
    setState(() => _loadingPoorShifts = true);
    try {
      logger.i('[ManagerDashboard][DEBUG] ===== POOR SHIFTS ANALYSIS STARTING =====');
      logger.i('[ManagerDashboard][DEBUG] _selectedLocationId: $_selectedLocationId');
      logger.i('[ManagerDashboard][DEBUG] organizationId: ${widget.organizationId}');
      logger.i('[ManagerDashboard][DEBUG] Loading poor performing shifts data...');
      final now = DateTime.now();
      final start = _dateFormat.format(now.subtract(const Duration(days: 30)));
      final end = _dateFormat.format(now);

      logger.i('[ManagerDashboard][DEBUG] Querying poor shifts from $start to $end for location: $_selectedLocationId');

      // Determine which location(s) to query. Prefer the selected location but
      // fallback to other available locations if it returns no data.
      final preferredLocation = _selectedLocationId;

      final List<QueryDocumentSnapshot> docs = [];

      Future<List<QueryDocumentSnapshot>> queryForLocation(String locId) async {
        try {
          // Prefer location-scoped daily_checklists (locations/{locId}/daily_checklists)
          final s =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(widget.organizationId)
                  .collection('locations')
                  .doc(locId)
                  .collection('daily_checklists')
                  .where('date', isGreaterThanOrEqualTo: start)
                  .where('date', isLessThanOrEqualTo: end)
                  .get();
          logger.i(
            '[ManagerDashboard][DEBUG] queryForLocation($locId) (location-scoped) returned ${s.docs.length} docs',
          );
          return s.docs;
        } catch (e) {
          logger.w(
            '[ManagerDashboard][DEBUG] queryForLocation($locId) failed (location-scoped), falling back to org-scoped query: $e',
          );
          // Fallback to org-root daily_checklists where we store a locationId field (legacy)
          final s =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(widget.organizationId)
                  .collection('daily_checklists')
                  .where('date', isGreaterThanOrEqualTo: start)
                  .where('date', isLessThanOrEqualTo: end)
                  .where('locationId', isEqualTo: locId)
                  .get();
          logger.i(
            '[ManagerDashboard][DEBUG] queryForLocation($locId) (org-scoped fallback) returned ${s.docs.length} docs',
          );
          return s.docs;
        }
      }

      // Try preferred location first (if any)
      if (preferredLocation != null && preferredLocation.isNotEmpty) {
        logger.i('[ManagerDashboard][DEBUG] Trying selected location for poor shifts: $preferredLocation');
        final r = await queryForLocation(preferredLocation);
        docs.addAll(r);
        logger.i('[ManagerDashboard][DEBUG] Selected location returned ${r.length} docs');
      }

      // If no docs found for preferred location, try other available locations
      if (docs.isEmpty && _availableLocations.isNotEmpty) {
        logger.i(
          '[ManagerDashboard][DEBUG] No checklists found for selected location; trying other available locations',
        );
        for (final loc in _availableLocations) {
          final id = loc['id'] as String?;
          if (id == null) continue;
          if (id == preferredLocation) continue; // already tried
          final r = await queryForLocation(id);
          if (r.isNotEmpty) {
            docs.addAll(r);
            logger.i('[ManagerDashboard][DEBUG] Found ${r.length} docs for fallback location $id');
            // don't break; we may want to aggregate across locations
          }
        }
      }

      // Last resort: if still empty, try querying without a location filter for the date range
      if (docs.isEmpty) {
        logger.i(
          '[ManagerDashboard][DEBUG] No daily_checklists found scoped to locations, falling back to global date-range query',
        );
        final s =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(widget.organizationId)
                .collection('daily_checklists')
                .where('date', isGreaterThanOrEqualTo: start)
                .where('date', isLessThanOrEqualTo: end)
                .get();
        docs.addAll(s.docs);
        logger.i('[ManagerDashboard][DEBUG] Global date-range query returned ${s.docs.length} docs');
      }

      logger.i('[ManagerDashboard][DEBUG] Total daily_checklist docs to process: ${docs.length}');

      final Map<String, Map<String, num>> agg = {}; // key: shiftName, values: {'done':x,'total':y}

      // Cache to avoid repeated reads for the same shiftId
      final Map<String, String> shiftNameCache = {};

      for (final d in docs) {
        final dataRaw = d.data();
        final data = (dataRaw is Map<String, dynamic>) ? dataRaw : <String, dynamic>{};
        final shiftId = (data['shiftId'] ?? '').toString();
        String shiftName = (data['shiftName'] ?? '').toString();

        // Resolve shift name from cache or via lookup when not denormalized
        if (shiftName.isEmpty || shiftName.toLowerCase().contains('unknown')) {
          if (shiftId.isNotEmpty) {
            if (shiftNameCache.containsKey(shiftId)) {
              shiftName = shiftNameCache[shiftId]!;
            } else {
              try {
                final shiftDoc =
                    await FirestoreEnforcer.instance
                        .collection('organizations')
                        .doc(widget.organizationId)
                        .collection('shifts')
                        .doc(shiftId)
                        .get();
                if (shiftDoc.exists) {
                  final sdata = shiftDoc.data();
                  final resolved = (sdata?['shiftName'] ?? sdata?['name'] ?? '').toString();
                  if (resolved.isNotEmpty) {
                    shiftName = resolved;
                    shiftNameCache[shiftId] = resolved;
                  }
                }
              } catch (e) {
                logger.w('[ManagerDashboard][DEBUG] Failed to resolve shiftName for shiftId=$shiftId: $e');
              }
            }
          }
        }

        if (shiftName.isEmpty) shiftName = 'Unknown Shift';
        logger.i('[ManagerDashboard][DEBUG] Processing checklist docId: ${d.id}, shiftName: $shiftName');

        // Check if tasks are in subcollection (new way) or in document (old way)
        List<Map<String, dynamic>> tasks = [];

        if (data.containsKey('tasks') && data['tasks'] != null) {
          // Old way: tasks in document
          tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? const []);
          logger.i(
            '[ManagerDashboard][DEBUG] Found ${tasks.length} tasks in document for shift: $shiftName, checklist: ${d.id}',
          );
        } else {
          // New way: tasks in subcollection - need to fetch them
          try {
            final tasksSnap = await d.reference.collection('tasks').get();
            tasks = tasksSnap.docs.map((taskDoc) => taskDoc.data()).toList();
            logger.i(
              '[ManagerDashboard][DEBUG] Found ${tasks.length} tasks in subcollection for shift: $shiftName, checklist: ${d.id}',
            );
          } catch (e) {
            logger.e('[ManagerDashboard][DEBUG] Failed to load tasks subcollection for doc ${d.id}: $e');
          }
        }

        final total = tasks.length;
        final done =
            tasks.where((t) {
              final completed = t['completed'] == true || t['isCompleted'] == true || t['status'] == 'completed';
              return completed;
            }).length;

        logger.i('[ManagerDashboard][DEBUG] Shift $shiftName: $done/$total completed');

        final entry = agg.putIfAbsent(shiftName, () => {'done': 0, 'total': 0});
        entry['done'] = (entry['done'] ?? 0) + done;
        entry['total'] = (entry['total'] ?? 0) + total;
      }

      final list =
          agg.entries
              .map((e) {
                final done = (e.value['done'] ?? 0).toInt();
                final total = max((e.value['total'] ?? 0).toInt(), 1);
                final pct = done / total;
                return {'shiftName': e.key, 'avgCompletion': pct, 'done': done, 'total': total};
              })
              .where((m) => (m['total'] as int) > 0)
              .toList()
            ..sort((a, b) => (a['avgCompletion'] as double).compareTo(b['avgCompletion'] as double));

      logger.i('[ManagerDashboard][DEBUG] Poor performing shifts analysis complete: ${list.length} shifts found');
      for (final shift in list) {
        final pct = ((shift['avgCompletion'] as double) * 100).toStringAsFixed(1);
        logger.i(
          '[ManagerDashboard][DEBUG] - ${shift['shiftName']}: $pct% completion (${shift['done']}/${shift['total']})',
        );
      }

      // Show shifts with completion rate below 85% as "poor performing"
      final poorShifts = list.where((shift) => (shift['avgCompletion'] as double) < 0.85).toList();
      logger.i('[ManagerDashboard][DEBUG] Found ${poorShifts.length} shifts with completion < 85%');

      logger.i('[ManagerDashboard][DEBUG] Final poorShifts30d: $poorShifts');
      if (!mounted) return;
      setState(() => _poorShifts30d = poorShifts.take(5).toList());
    } catch (e, st) {
      logger.e('[ManagerDashboard][DEBUG] _loadPoorShifts30d failed: $e', e, st);
    } finally {
      if (!mounted) return;
      setState(() => _loadingPoorShifts = false);
      logger.i('[ManagerDashboard][DEBUG] ALWAYSLOG: Exiting _loadPoorShifts30d');
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!mounted || _selectedLocationId == null) return;
      await _loadLiveShifts();
    });
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocations || _isLoadingUserRole || _isLoadingSetupStatus) {
      return Scaffold(
        backgroundColor: HandsColors.scaffoldBackground,
        appBar: AppBar(
          title: Text(
            'MANAGER DASHBOARD',
            style: GoogleFonts.comfortaa(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          backgroundColor: HandsColors.primaryContainer,
          foregroundColor: HandsColors.white,
        ),
        bottomNavigationBar: BottomNavBar(currentIndex: 1, userRole: userRole),
        body: const Center(child: CircularProgressIndicator(color: HandsColors.handsOrange)),
      );
    }

    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(appBarTitle: 'Manager Dashboard', userRole: userRole),
        automaticallyImplyLeading: false,
        actions: [
          if (_metricsEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<String>(
                enabled: _availableLocations.isNotEmpty,
                onSelected: (value) async {
                  logger.i('[ManagerDashboard][DEBUG] Location selected from header: $value');
                  setState(() {
                    _selectedLocationId = value;
                    final matches = _availableLocations.where((loc) => loc['id'] == value).toList();
                    _selectedLocationName =
                        matches.isNotEmpty ? (matches.first['name'] as String?) : 'Unknown Location';
                  });
                  // Persist globally
                  if (value.isNotEmpty) {
                    _locationSelectionService.setLocation(value);
                  }
                  logger.i(
                    '[ManagerDashboard][DEBUG] Updated _selectedLocationId: $_selectedLocationId, name: $_selectedLocationName',
                  );
                  await _loadFilterOptions();
                  await _loadAll();
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
                                  color: selected ? HandsColors.handsOrange : HandsColors.white70,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${loc['name']}',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.comfortaa(
                                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                      color: selected ? HandsColors.handsOrange : HandsColors.white,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(Icons.check, size: 16, color: HandsColors.handsOrange),
                                  ),
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
                          color: HandsColors.handsOrange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on, color: HandsColors.white, size: 20),
                      );
                    } else {
                      // Full desktop version
                      return Container(
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
                      );
                    }
                  },
                ),
              ),
            ),
          UnifiedMenuButton(userRole: userRole),
        ],
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 1, userRole: userRole),
      body: _metricsEnabled ? _buildDashboardGrid() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() =>
      OrganizationSetupWidget(organizationId: widget.organizationId, onMetricsEnabled: _onMetricsEnabled);

  void _onMetricsEnabled() async {
    setState(() => _metricsEnabled = true);
    await _ensureDailyChecklistsExist();
    await _loadAll();
  }

  Widget _buildDashboardGrid() {
    final width = MediaQuery.of(context).size.width;
    // Responsive breakpoints: mobile < 600, tablet/condensed 600-900, desktop > 900
    final isMobile = width < 600;
    final isCondensed = width >= 600 && width < 900;

    // Use the available viewport height to layout cards so the dashboard fits
    // on a single screen without scrolling. LayoutBuilder gives us the max
    // height available inside the scaffold body (after AppBar). We then split
    // the area into two main rows: top (Missed Yesterday + Today's Shifts)
    // and bottom (Frequent Misses + Poor Shifts + action). Heights use flex
    // so the UI adapts between phone and browser sizes.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compact mode when the available body height is small (phones/short view)
        final compact = constraints.maxHeight < 700;

        // Responsive gap and column width
        final gap = compact ? 8.0 : 12.0;
        final colW = (width - gap * 3) / 2;

        // Top row: larger, show missed + live shifts
        // Bottom row: smaller, show frequent misses + poor shifts + button
        return Padding(
          padding: EdgeInsets.all(compact ? gap * 0.5 : gap * 0.75),
          child: Column(
            children: [
              // Top area - stack in mobile/condensed mode so live view remains visible
              Expanded(
                flex:
                    isMobile
                        ? 6 // Reduced from 7 to make room for bottom content
                        : isCondensed
                        ? 6
                        : 6,
                child:
                    (isMobile || isCondensed)
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Missed Yesterday (full width) - allow to size naturally but keep flexible
                            Flexible(
                              flex: 2,
                              child: _SummaryCard(
                                title: 'Missed Yesterday',
                                icon: Icons.report_gmailerrorred,
                                accentColor: HandsColors.error, // Red for missed tasks
                                valueBuilder: () {
                                  final count = _yesterdayMissed.fold<int>(
                                    0,
                                    (sum, e) => sum + (e['count'] as int? ?? 1),
                                  );
                                  // Count unique shifts, not task entries
                                  final uniqueShifts =
                                      _yesterdayMissed.map((e) => e['shiftId'] ?? e['shiftName'] ?? '').toSet().length;
                                  return Text(
                                    '$count missed tasks across $uniqueShifts shifts',
                                    style: GoogleFonts.comfortaa(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: HandsColors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                                trailing: MiniSparkBars(values: _missedTrend7d, height: 60),
                                loading: _loadingYesterday,
                                onTap: _openAllMissedYesterday,
                                footer:
                                    _selectedLocationName == null
                                        ? null
                                        : Text(
                                          '📍 $_selectedLocationName',
                                          style: GoogleFonts.comfortaa(fontSize: 12, color: HandsColors.white70),
                                        ),
                              ),
                            ),
                            SizedBox(height: compact ? 3 : 4),
                            // Today's Shifts (full width) - constrain height to prevent overflow
                            Flexible(
                              flex: 3, // Give it reasonable space but not unlimited
                              child: _SummaryCard(
                                title: "Today's Shifts",
                                icon: Icons.live_tv,
                                accentColor: HandsColors.handsOrange, // Orange for live shifts
                                valueBuilder: null,
                                titleSuffix: () {
                                  if (_selectedStatusFilter == 'live') {
                                    final inProgress = _filteredLiveShifts.where(
                                      (s) => s['timeStatus'].toString().contains('remaining'),
                                    );
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: HandsColors.sageGreen.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: HandsColors.sageGreen, width: 1),
                                      ),
                                      child: Text(
                                        '${inProgress.length} LIVE',
                                        style: GoogleFonts.comfortaa(
                                          color: HandsColors.sageGreen,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: HandsColors.white12,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: HandsColors.white30, width: 1),
                                      ),
                                      child: Text(
                                        '${_filteredLiveShifts.length} DONE',
                                        style: GoogleFonts.comfortaa(
                                          color: HandsColors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                loading: _loadingLive,
                                onTap: _openTodayShifts,
                                actions: [
                                  Container(
                                    height: 28,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _StatusToggleButton(
                                          label: 'Live',
                                          selected: _selectedStatusFilter == 'live',
                                          onTap: () async {
                                            setState(() => _selectedStatusFilter = 'live');
                                            await _loadLiveShifts();
                                          },
                                        ),
                                        _StatusToggleButton(
                                          label: 'Done',
                                          selected: _selectedStatusFilter == 'finished',
                                          onTap: () async {
                                            setState(() => _selectedStatusFilter = 'finished');
                                            await _loadLiveShifts();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      setState(() => _loadingLive = true);
                                      await _loadLiveShifts();
                                    },
                                    icon: const Icon(Icons.refresh),
                                    tooltip: 'Refresh',
                                  ),
                                ],
                                child: _LiveShiftStrip(shifts: _filteredLiveShifts, onOpen: _openTodayShifts),
                              ),
                            ),
                          ],
                        )
                        : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Missed Yesterday (left)
                            SizedBox(
                              width: colW,
                              child: _SummaryCard(
                                title: 'Missed Yesterday',
                                icon: Icons.report_gmailerrorred,
                                accentColor: Colors.orange,
                                valueBuilder: () {
                                  final count = _yesterdayMissed.fold<int>(
                                    0,
                                    (sum, e) => sum + (e['count'] as int? ?? 1),
                                  );
                                  // Count unique shifts, not task entries
                                  final uniqueShifts =
                                      _yesterdayMissed.map((e) => e['shiftId'] ?? e['shiftName'] ?? '').toSet().length;
                                  return Text(
                                    '$count missed tasks across $uniqueShifts shifts',
                                    style: _kMetricTextStyle(context).copyWith(fontSize: 12, color: HandsColors.white),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                                trailing: MiniSparkBars(values: _missedTrend7d, height: 60),
                                loading: _loadingYesterday,
                                onTap: _openAllMissedYesterday,
                                footer:
                                    _selectedLocationName == null
                                        ? null
                                        : Text('📍 $_selectedLocationName', style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                            SizedBox(width: gap),
                            // Today's Shifts (right, expanding)
                            Expanded(
                              child: _SummaryCard(
                                title: "Today's Shifts",
                                icon: Icons.live_tv,
                                accentColor: Theme.of(context).primaryColor,
                                valueBuilder: null,
                                titleSuffix: () {
                                  if (_selectedStatusFilter == 'live') {
                                    final inProgress = _filteredLiveShifts.where(
                                      (s) => s['timeStatus'].toString().contains('remaining'),
                                    );
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context).primaryColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '${inProgress.length} live',
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey[300]!, width: 1),
                                      ),
                                      child: Text(
                                        '${_filteredLiveShifts.length} done',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                loading: _loadingLive,
                                onTap: _openTodayShifts,
                                actions: [
                                  Container(
                                    height: 28,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _StatusToggleButton(
                                          label: 'Live',
                                          selected: _selectedStatusFilter == 'live',
                                          onTap: () async {
                                            setState(() => _selectedStatusFilter = 'live');
                                            await _loadLiveShifts();
                                          },
                                        ),
                                        _StatusToggleButton(
                                          label: 'Done',
                                          selected: _selectedStatusFilter == 'finished',
                                          onTap: () async {
                                            setState(() => _selectedStatusFilter = 'finished');
                                            await _loadLiveShifts();
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      setState(() => _loadingLive = true);
                                      await _loadLiveShifts();
                                    },
                                    icon: const Icon(Icons.refresh),
                                    tooltip: 'Refresh',
                                  ),
                                ],
                                child: _LiveShiftStrip(shifts: _filteredLiveShifts, onOpen: _openTodayShifts),
                              ),
                            ),
                          ],
                        ),
              ),

              SizedBox(height: compact ? 3 : 4),

              // Bottom area
              Expanded(
                flex:
                    isMobile
                        ? 4 // Increased flex for mobile to give more space
                        : isCondensed
                        ? 4
                        : 4,
                child: Column(
                  children: [
                    // Main bottom content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child:
                            isMobile
                                ?
                                // Mobile: Stack vertically to prevent overlapping
                                Column(
                                  children: [
                                    // Frequent Misses (mobile)
                                    Expanded(
                                      child: _SummaryCard(
                                        title: 'Frequent Misses (30d)',
                                        icon: Icons.trending_down,
                                        accentColor: HandsColors.error,
                                        loading: _loadingFrequent,
                                        valueBuilder:
                                            () => Text(
                                              _frequentMisses30d.isEmpty
                                                  ? '0 HOT SPOTS'
                                                  : '${_frequentMisses30d.length} HOT SPOTS',
                                              style: GoogleFonts.comfortaa(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: HandsColors.error,
                                              ),
                                            ),
                                        onTap: _openAllFrequentMisses,
                                        child: _TopListPreview(
                                          items:
                                              _frequentMisses30d.take(2).map((t) {
                                                final name = (t['taskName'] ?? 'Unknown Task').toString();
                                                final count = (t['count'] ?? t['missedCount'] ?? 0).toString();
                                                final displayName =
                                                    name.length > 12 ? '${name.substring(0, 12)}...' : name;
                                                return '$displayName ×$count';
                                              }).toList(),
                                          emptyLabel: 'No frequent misses',
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: gap),
                                    // Poor Performing (mobile)
                                    Expanded(
                                      child: _SummaryCard(
                                        title: 'Poor Performing (30d)',
                                        icon: Icons.speed,
                                        accentColor: HandsColors.handsOrange,
                                        loading: _loadingPoorShifts,
                                        valueBuilder:
                                            () => Text(
                                              _poorShifts30d.isEmpty ? 'ALL OK' : '${_poorShifts30d.length} FLAGGED',
                                              style: GoogleFonts.comfortaa(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    _poorShifts30d.isEmpty
                                                        ? HandsColors.sageGreen
                                                        : HandsColors.handsOrange,
                                              ),
                                            ),
                                        onTap: _openPoorShiftDetails,
                                        child: _TopListPreview(
                                          items:
                                              _poorShifts30d.take(2).map((m) {
                                                final pct = ((m['avgCompletion'] as double?) ?? 0) * 100;
                                                final shiftName = (m['shiftName'] ?? 'Unknown').toString();
                                                final displayName =
                                                    shiftName.length > 12
                                                        ? '${shiftName.substring(0, 12)}...'
                                                        : shiftName;
                                                return '$displayName ${pct.toStringAsFixed(0)}%';
                                              }).toList(),
                                          emptyLabel: 'No issues found',
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                :
                                // Desktop: Side by side layout
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Frequent Misses
                                    Expanded(
                                      flex: 1,
                                      child: _SummaryCard(
                                        title: 'Frequent Misses (30d)',
                                        icon: Icons.trending_down,
                                        accentColor: HandsColors.error,
                                        loading: _loadingFrequent,
                                        valueBuilder:
                                            () => Text(
                                              _frequentMisses30d.isEmpty
                                                  ? '0 HOT SPOTS'
                                                  : '${_frequentMisses30d.length} HOT SPOTS',
                                              style: GoogleFonts.comfortaa(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: HandsColors.error,
                                              ),
                                            ),
                                        onTap: _openAllFrequentMisses,
                                        child: _TopListPreview(
                                          items:
                                              _frequentMisses30d.take(3).map((t) {
                                                final name = (t['taskName'] ?? 'Unknown Task').toString();
                                                final shift = (t['shiftName'] ?? '').toString();
                                                final shiftNames = (t['shiftNames'] ?? []).cast<String>();
                                                final count = (t['count'] ?? t['missedCount'] ?? 0).toString();

                                                String shiftDisplay = '';
                                                if (shiftNames.isNotEmpty) {
                                                  if (shiftNames.length == 1) {
                                                    shiftDisplay = ' • ${shiftNames.first}';
                                                  } else {
                                                    shiftDisplay = ' • +${shiftNames.length} shifts';
                                                  }
                                                } else if (shift.isNotEmpty) {
                                                  shiftDisplay = ' • $shift';
                                                }

                                                final displayName =
                                                    name.length > 15 ? '${name.substring(0, 15)}...' : name;
                                                return '$displayName$shiftDisplay ×$count';
                                              }).toList(),
                                          emptyLabel: 'No frequent misses',
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: gap),
                                    // Poor Performing Shifts
                                    Expanded(
                                      flex: 1,
                                      child: _SummaryCard(
                                        title: 'Poor Performing Shifts (30d)',
                                        icon: Icons.speed,
                                        accentColor: HandsColors.handsOrange,
                                        loading: _loadingPoorShifts,
                                        valueBuilder:
                                            () => Text(
                                              _poorShifts30d.isEmpty ? 'ALL OK' : '${_poorShifts30d.length} FLAGGED',
                                              style: GoogleFonts.comfortaa(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    _poorShifts30d.isEmpty
                                                        ? HandsColors.sageGreen
                                                        : HandsColors.handsOrange,
                                              ),
                                            ),
                                        onTap: _openPoorShiftDetails,
                                        child: _TopListPreview(
                                          items:
                                              _poorShifts30d.take(3).map((m) {
                                                final pct = ((m['avgCompletion'] as double?) ?? 0) * 100;
                                                final shiftName = (m['shiftName'] ?? 'Unknown').toString();
                                                final displayName =
                                                    shiftName.length > 18
                                                        ? '${shiftName.substring(0, 18)}...'
                                                        : shiftName;
                                                return '$displayName ${pct.toStringAsFixed(0)}%';
                                              }).toList(),
                                          emptyLabel: 'No issues found',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ),

                    SizedBox(height: compact ? 4 : 6),

                    // Task History button - separate from the cards to prevent overlap
                    SizedBox(
                      height: compact ? 36 : 44, // Smaller on mobile
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
                        child: HandsPrimaryButton(
                          text: 'Task History',
                          onPressed: _openTaskHistorySheet,
                          icon: Icons.analytics,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredLiveShifts {
    if (_selectedStatusFilter == null) return _liveShifts;

    if (_selectedStatusFilter == 'live') {
      // Show shifts that are in progress or starting soon
      return _liveShifts.where((s) {
        final timeStatus = s['timeStatus'].toString();
        return timeStatus.contains('remaining') || timeStatus.contains('Starts in');
      }).toList();
    } else if (_selectedStatusFilter == 'finished') {
      // Show finished shifts
      return _liveShifts.where((s) {
        final timeStatus = s['timeStatus'].toString();
        return timeStatus.contains('Finished');
      }).toList();
    }

    return _liveShifts;
  }

  // ====== Modals / Sheets ======

  void _openAllMissedYesterday() {
    showDialog(
      context: context,
      builder:
          (context) => _ProfessionalDialog(
            title: 'All Missed Tasks Yesterday',
            child:
                _loadingYesterday
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _yesterdayMissed.length,
                      itemBuilder: (context, i) {
                        final m = _yesterdayMissed[i];
                        final name = (m['taskName'] ?? 'Unknown Task').toString();
                        final shift = (m['shiftName'] ?? 'Unknown Shift').toString();
                        final count = (m['count'] ?? 1) as int;
                        final completedToday = m['completedToday'] == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: HandsDecorations.secondaryBoxDecoration,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.comfortaa(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: HandsColors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(shift, style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (completedToday)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: HandsColors.sageGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: HandsColors.sageGreen),
                                  ),
                                  child: Text(
                                    'Done today',
                                    style: GoogleFonts.comfortaa(
                                      color: HandsColors.sageGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (count > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: HandsColors.handsOrange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: HandsColors.handsOrange),
                                  ),
                                  child: Text(
                                    '×$count',
                                    style: GoogleFonts.comfortaa(
                                      color: HandsColors.handsOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
    );
  }

  void _openTodayShifts() {
    showDialog(
      context: context,
      builder:
          (context) => _ProfessionalDialog(
            title: "Today's Shifts (all)",
            child:
                _loadingLive
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _liveShifts.length,
                      itemBuilder: (context, i) {
                        final s = _liveShifts[i];
                        final pct = ((s['completionPct'] ?? 0.0) as double).clamp(0.0, 1.0);
                        final status = (s['timeStatus'] ?? '').toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: HandsDecorations.secondaryBoxDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s['shiftName'] ?? 'Unnamed Shift',
                                          style: GoogleFonts.comfortaa(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: HandsColors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${s['startTime']} - ${s['endTime']}',
                                          style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _TimeChip(status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 6,
                                      backgroundColor: HandsColors.white12,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        pct >= 0.8
                                            ? HandsColors.sageGreen
                                            : pct >= 0.5
                                            ? HandsColors.handsOrange
                                            : HandsColors.error,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(pct * 100).round()}%',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s['completedTasks']}/${s['totalTasks']} tasks complete',
                                style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
    );
  }

  void _openAllFrequentMisses() {
    showDialog(
      context: context,
      builder:
          (context) => _ProfessionalDialog(
            title: 'Frequently Missed Tasks (30 days)',
            child:
                _loadingFrequent
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _frequentMisses30d.length,
                      itemBuilder: (context, i) {
                        final t = _frequentMisses30d[i];
                        final name = (t['taskName'] ?? 'Unknown Task').toString();
                        final shift = (t['shiftName'] ?? '').toString();
                        final shiftNames =
                            (t['shiftNames'] ?? []).cast<String>(); // Handle multiple shift names if available
                        final count = (t['count'] ?? t['missedCount'] ?? 0).toString();

                        // Create display string for shifts - improved logic
                        String shiftDisplay = '';
                        if (shiftNames.isNotEmpty) {
                          // Use multiple shift names if available
                          if (shiftNames.length == 1) {
                            shiftDisplay = shiftNames.first;
                          } else if (shiftNames.length <= 3) {
                            shiftDisplay = shiftNames.join(', ');
                          } else {
                            shiftDisplay = '${shiftNames.take(2).join(', ')} +${shiftNames.length - 2} more';
                          }
                        } else if (shift.isNotEmpty) {
                          // Fallback to single shift name
                          shiftDisplay = shift;
                        } else {
                          // Try other possible field names
                          final alternativeShift = (t['shift'] ?? t['shiftType'] ?? t['location'] ?? '').toString();
                          if (alternativeShift.isNotEmpty) {
                            shiftDisplay = alternativeShift;
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: HandsDecorations.tertiaryBoxDecoration,
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color:
                                      i == 0
                                          ? Colors.red
                                          : i == 1
                                          ? Colors.orange
                                          : i == 2
                                          ? Colors.amber
                                          : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.comfortaa(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: HandsColors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.schedule, size: 12, color: HandsColors.white70),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            shiftDisplay.isNotEmpty ? shiftDisplay : 'Multiple shifts',
                                            style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 12),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (shiftNames.length > 1) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 10, color: HandsColors.handsOrange),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Affects ${shiftNames.length} shifts',
                                            style: TextStyle(
                                              color: Colors.blue[600],
                                              fontSize: 10,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  '×$count',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
    );
  }

  void _openPoorShiftDetails() {
    showDialog(
      context: context,
      builder:
          (context) => _ProfessionalDialog(
            title: 'Poor Performing Shifts (30 days)',
            child:
                _loadingPoorShifts
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _poorShifts30d.length,
                      itemBuilder: (context, i) {
                        final m = _poorShifts30d[i];
                        final pct = ((m['avgCompletion'] as double?) ?? 0) * 100;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: HandsDecorations.tertiaryBoxDecoration,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m['shiftName'] ?? 'Unknown Shift',
                                      style: GoogleFonts.comfortaa(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: HandsColors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Avg completion last 30 days',
                                      style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      pct < 50
                                          ? Colors.red.shade50
                                          : pct < 80
                                          ? Colors.orange.shade50
                                          : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        pct < 50
                                            ? Colors.red.shade200
                                            : pct < 80
                                            ? Colors.orange.shade200
                                            : Colors.green.shade200,
                                  ),
                                ),
                                child: Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color:
                                        pct < 50
                                            ? Colors.red.shade700
                                            : pct < 80
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
    );
  }

  Future<void> _openTaskHistorySheet() async {
    // Default date range: last 14 days
    _selectedDateRange ??= DateTimeRange(start: DateTime.now().subtract(const Duration(days: 14)), end: DateTime.now());
    showDialog(
      context: context,
      builder:
          (context) => _ProfessionalDialog(
            title: 'Previous Tasks',
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            child: _TaskHistoryDialog(
              organizationId: widget.organizationId,
              selectedLocationId: _selectedLocationId,
              shifts: _shifts,
              checklists: _checklists,
              initialDateRange: _selectedDateRange!,
            ),
          ),
    );
  }

  // ===== Helpers =====

  String _calculateTimeStatus(String startTime, String endTime) {
    if (startTime.isEmpty || endTime.isEmpty) return 'No schedule';
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final start = DateFormat('yyyy-MM-dd HH:mm').parse('$dateStr $startTime');
      final end = DateFormat('yyyy-MM-dd HH:mm').parse('$dateStr $endTime');
      if (now.isBefore(start)) {
        final d = start.difference(now);
        return 'Starts in ${_formatDuration(d)}';
      } else if (now.isAfter(end)) {
        return 'Finished';
      } else {
        final d = end.difference(now);
        return '${_formatDuration(d)} remaining';
      }
    } catch (_) {
      return 'Invalid schedule';
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '${h}h ${m}m';
    }
    return '${d.inMinutes}m';
  }
}

// ===== Reusable Widgets =====

class _SummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget Function()? valueBuilder;
  final Widget Function()? titleSuffix; // Add titleSuffix parameter
  final Widget? trailing;
  final Widget? child;
  final List<Widget>? actions;
  final bool loading;
  final VoidCallback? onTap;
  final Widget? footer;

  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    this.valueBuilder,
    this.titleSuffix,
    this.trailing,
    this.child,
    this.actions,
    this.loading = false,
    this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: HandsDecorations.primaryBoxDecoration,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title.toUpperCase(),
                            style: GoogleFonts.comfortaa(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: HandsColors.white,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (titleSuffix != null) ...[
                          const SizedBox(width: 8),
                          titleSuffix!(),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
              const SizedBox(height: 16),
              if (loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: HandsColors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (valueBuilder != null) valueBuilder!(),
                    const Spacer(),
                    if (trailing != null) trailing!,
                  ],
                ),
              if (child != null) ...[const SizedBox(height: 16), Flexible(child: child!)],
              if (footer != null) ...[
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: footer!),
              ],
            ],
          ),
        ),
      ),
    );
    return card;
  }
}

TextStyle _kMetricTextStyle(BuildContext context) =>
    GoogleFonts.comfortaa(fontSize: 24, fontWeight: FontWeight.bold, color: HandsColors.white);

class MiniSparkBars extends StatelessWidget {
  final List<int> values;
  final double height;
  const MiniSparkBars({super.key, required this.values, this.height = 60}); // Increased from 40 to 60

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height, child: const SizedBox.shrink());

    // Use LayoutBuilder so the sparkline fills available width instead of
    // forcing a fixed width that can cause overflow on small screens.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 120.0;
        return SizedBox(
          height: height,
          width: w,
          child: CustomPaint(size: Size(w, height), painter: _TrendLineChartPainter(values: values)),
        );
      },
    );
  }
}

class _TrendLineChartPainter extends CustomPainter {
  final List<int> values;

  _TrendLineChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || values.length < 2) return;

    // Calculate trend direction (comparing first and last values)
    final firstValue = values.first;
    final lastValue = values.last;
    final isUpwardTrend = lastValue > firstValue;

    // Choose color based on trend (red for upward = bad, green for downward = good)
    final color = isUpwardTrend ? HandsColors.error : HandsColors.sageGreen;

    // Find min and max for normalization
    final minVal = values.reduce(min).toDouble();
    final maxVal = values.reduce(max).toDouble();
    final range = max(1.0, maxVal - minVal);

    // Create points for the line
    final points = <Offset>[];
    final width = size.width;
    final height = size.height;
    final step = width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * step;
      final normalizedValue = (values[i] - minVal) / range;
      final y = height - (normalizedValue * height * 0.85) - (height * 0.05); // More space usage, less padding
      points.add(Offset(x, y));
    }

    // Create path for the line
    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    // Create path for the filled area
    final fillPath = Path();
    fillPath.moveTo(points[0].dx, height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath.lineTo(points.last.dx, height);
    fillPath.close();

    // Paint the filled area with higher opacity
    final fillPaint =
        Paint()
          ..color = color.withOpacity(0.4)
          ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Paint the line
    final linePaint =
        Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Paint dots at data points
    final dotPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 2.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LiveShiftStrip extends StatelessWidget {
  final List<Map<String, dynamic>> shifts;
  final VoidCallback onOpen;
  const _LiveShiftStrip({required this.shifts, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (shifts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.06),
              Theme.of(context).primaryColor.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 32, color: Colors.grey),
              SizedBox(height: 8),
              Text('No shifts scheduled for today.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final inProgress = shifts.where((s) => s['timeStatus'].toString().contains('remaining')).toList();
    final toShow = inProgress.isNotEmpty ? inProgress : shifts;

    // Check if we're on mobile for different layout
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Mobile layout: Simple horizontal scrollable list
    if (isMobile) {
      return SizedBox(
        height: 140, // Increased height to accommodate larger Harvey balls and prevent content cutoff
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: toShow.length,
          itemBuilder: (context, index) {
            return Container(
              width: 160, // Fixed width for each card
              margin: EdgeInsets.only(right: index < toShow.length - 1 ? 8 : 0),
              child: _SwipeShiftCard(shift: toShow[index], onTap: onOpen),
            );
          },
        ),
      );
    }

    // Desktop layout: PageView with GridView (original implementation)
    return ClipRect(
      child: SizedBox(
        height: 140, // Increased height to accommodate larger Harvey balls and prevent content cutoff
        child: PageView.builder(
          controller: PageController(viewportFraction: 0.85), // Show slight preview of next card
          itemCount: (toShow.length / 6).ceil(), // Pages needed for all shifts
          itemBuilder: (context, pageIndex) {
            final startIndex = pageIndex * 6;
            final endIndex = (startIndex + 6).clamp(0, toShow.length);
            final pageShifts = toShow.sublist(startIndex, endIndex);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GridView.builder(
                physics: NeverScrollableScrollPhysics(), // Disable grid scrolling since we're using PageView
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 columns
                  childAspectRatio: 1.1, // Slightly wider than tall
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: pageShifts.length,
                itemBuilder: (context, index) {
                  return _SwipeShiftCard(shift: pageShifts[index], onTap: onOpen);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// New swipeable shift card widget
class _SwipeShiftCard extends StatelessWidget {
  final Map<String, dynamic> shift;
  final VoidCallback onTap;

  const _SwipeShiftCard({required this.shift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = ((shift['completionPct'] ?? 0.0) as double).clamp(0.0, 1.0);
    final status = (shift['timeStatus'] ?? '').toString();
    final completedTasks = shift['completedTasks'] ?? 0;
    final totalTasks = shift['totalTasks'] ?? 1;
    final shiftName = shift['shiftName'] ?? 'Unnamed';

    // Determine if shift is finished
    final isFinished = status.contains('Finished') || status.contains('Complete');

    // Make Harvey ball larger on mobile for better visibility
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final harveyBallSize = isMobile ? 60.0 : 42.0; // Increased mobile size significantly

    return Material(
      color: HandsColors.cardTertiary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 6 : 8), // Reduced padding on mobile
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: Shift name and Harvey ball
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      shiftName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.comfortaa(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 10 : 11, // Slightly smaller text on mobile to fit better
                        color: HandsColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Harvey ball in top right - enhanced for mobile compatibility
                  Container(
                    width: harveyBallSize,
                    height: harveyBallSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: pct > 0 ? Colors.green[700]! : Colors.grey[500]!, width: 2.5),
                    ),
                    child: Stack(
                      children: [
                        // Custom paint Harvey ball
                        Positioned.fill(child: CustomPaint(painter: _HarveyBallPainter(pct, isFinished))),
                        // Fallback indicator for mobile if CustomPaint fails
                        if (isMobile)
                          Center(
                            child: Container(
                              width: harveyBallSize * 0.6,
                              height: harveyBallSize * 0.6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    pct > 0
                                        ? Colors.green[600]!.withOpacity(pct.clamp(0.3, 1.0))
                                        : (isFinished ? Colors.red.withOpacity(0.3) : Colors.grey[300]),
                              ),
                            ),
                          ),
                        // Debug percentage text
                        if (isMobile)
                          Center(
                            child: Text(
                              '${(pct * 100).toInt()}%',
                              style: GoogleFonts.comfortaa(
                                fontSize: 12, // Much larger text for mobile
                                fontWeight: FontWeight.bold,
                                color: Colors.black, // Black text as requested
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 4 : 8), // Reduced spacing on mobile
              // Tasks completed (center)
              Text(
                '$completedTasks/$totalTasks tasks',
                style: GoogleFonts.comfortaa(
                  fontSize: isMobile ? 9 : 10,
                  color: HandsColors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4), // Reduced spacing on mobile
              // Time remaining (center)
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.comfortaa(
                  fontSize: isMobile ? 8 : 9, // Smaller text on mobile
                  color: _getTimeStatusColor(status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTimeStatusColor(String status) {
    if (status.contains('Finished')) {
      return HandsColors.white70;
    } else if (status.contains('Starts in')) {
      return HandsColors.handsOrange;
    } else if (status.contains('remaining')) {
      return HandsColors.sageGreen;
    } else {
      return HandsColors.amber;
    }
  }
}

// Custom painter for harvey ball completion indicator
class _HarveyBallPainter extends CustomPainter {
  final double percentage;
  final bool isFinished;

  _HarveyBallPainter(this.percentage, this.isFinished);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1; // Slightly smaller to ensure border visibility

    // Determine background color for incomplete portion
    final incompleteColor = isFinished ? Colors.red : Colors.grey[300]!;

    // Draw outer circle (background - grey or red if finished)
    final backgroundPaint =
        Paint()
          ..color = incompleteColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true; // Better rendering on mobile
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw filled portion based on percentage (always green)
    if (percentage > 0) {
      final fillPaint =
          Paint()
            ..color =
                Colors.green[600]! // Slightly darker green for better visibility
            ..style = PaintingStyle.fill
            ..isAntiAlias = true; // Better rendering on mobile

      // Draw pie slice from top (90 degrees) clockwise
      final sweepAngle = 2 * 3.14159 * percentage;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -3.14159 / 2, // Start from top (-90 degrees)
        sweepAngle,
        true,
        fillPaint,
      );
    }

    // Note: Border is handled by Container decoration for better mobile compatibility
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TimeChip extends StatelessWidget {
  final String status;
  const _TimeChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    if (status.contains('Finished')) {
      color = Colors.grey;
    } else if (status.contains('Starts in')) {
      color = Colors.blue;
    } else if (status.contains('remaining')) {
      color = Colors.green;
    } else {
      color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Further reduced padding
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)), // Reduced radius
      child: Text(
        status,
        style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 9), // Even smaller font
      ),
    );
  }
}

class _TopListPreview extends StatelessWidget {
  final List<String> items;
  final String emptyLabel;
  const _TopListPreview({required this.items, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.centerLeft,
        child: Text(
          emptyLabel,
          style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 10, fontStyle: FontStyle.italic),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children:
            items
                .map(
                  (s) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $s',
                      style: GoogleFonts.comfortaa(
                        fontSize: 9,
                        color: HandsColors.white,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

// ===== Professional Dialog Widget =====

class _ProfessionalDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final double? width;
  final double? height;

  const _ProfessionalDialog({required this.title, required this.child, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: HandsColors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: width ?? MediaQuery.of(context).size.width * 0.9,
        height: height ?? MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header with title and X button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: HandsColors.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: HandsColors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: GoogleFonts.comfortaa(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: HandsColors.white,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: HandsColors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ===== Task History Dialog (filters + list) =====

class _TaskHistoryDialog extends StatefulWidget {
  final String organizationId;
  final String? selectedLocationId;
  final List<Map<String, String>> shifts;
  final List<Map<String, String>> checklists;
  final DateTimeRange initialDateRange;

  const _TaskHistoryDialog({
    required this.organizationId,
    required this.selectedLocationId,
    required this.shifts,
    required this.checklists,
    required this.initialDateRange,
  });

  @override
  State<_TaskHistoryDialog> createState() => _TaskHistoryDialogState();
}

class _TaskHistoryDialogState extends State<_TaskHistoryDialog> {
  final _searchCtrl = TextEditingController();
  String _selectedShift = 'all';
  String _selectedChecklist = 'all';
  String _selectedCompletion = 'all';
  DateTimeRange? _dateRange;
  bool _loading = false;
  List<_TaskRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialDateRange;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_dateRange!.start);
      final endStr = DateFormat('yyyy-MM-dd').format(_dateRange!.end);

      print('[TaskHistory] Loading tasks from $startStr to $endStr for location: ${widget.selectedLocationId}');

      List<QueryDocumentSnapshot> docs = [];

      // Try location-scoped daily_checklists first (new schema)
      if (widget.selectedLocationId != null) {
        try {
          Query locationQuery = FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('locations')
              .doc(widget.selectedLocationId)
              .collection('daily_checklists')
              .where('date', isGreaterThanOrEqualTo: startStr)
              .where('date', isLessThanOrEqualTo: endStr);

          if (_selectedShift != 'all') {
            locationQuery = locationQuery.where('shiftId', isEqualTo: _selectedShift);
          }

          final locationSnap = await locationQuery.get();
          print('[TaskHistory] Location-scoped query returned ${locationSnap.docs.length} docs');
          docs.addAll(locationSnap.docs);
        } catch (e) {
          print('[TaskHistory] Location-scoped query failed: $e');
        }
      }

      // If no docs found or no location selected, try org-scoped daily_checklists (fallback)
      if (docs.isEmpty) {
        try {
          Query orgQuery = FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('daily_checklists')
              .where('date', isGreaterThanOrEqualTo: startStr)
              .where('date', isLessThanOrEqualTo: endStr);

          if (widget.selectedLocationId != null) {
            orgQuery = orgQuery.where('locationId', isEqualTo: widget.selectedLocationId);
          }
          if (_selectedShift != 'all') {
            orgQuery = orgQuery.where('shiftId', isEqualTo: _selectedShift);
          }

          final orgSnap = await orgQuery.get();
          print('[TaskHistory] Org-scoped query returned ${orgSnap.docs.length} docs');
          docs.addAll(orgSnap.docs);
        } catch (e) {
          print('[TaskHistory] Org-scoped query failed: $e');
        }
      }

      print('[TaskHistory] Total documents to process: ${docs.length}');

      final List<_TaskRow> rows = [];
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final date = (data['date'] ?? '').toString();
        final shiftName = (data['shiftName'] ?? '').toString();
        final checklistName = (data['checklistName'] ?? '').toString();

        // Handle both old format (tasks in document) and new format (tasks in subcollection)
        List<Map<String, dynamic>> tasks = [];

        if (data.containsKey('tasks') && data['tasks'] != null) {
          // Old format: tasks in document
          tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? const []);
          print('[TaskHistory] Found ${tasks.length} tasks in document for ${d.id}');
        } else {
          // New format: tasks in subcollection
          try {
            final tasksSnap = await d.reference.collection('tasks').get();
            tasks = tasksSnap.docs.map((taskDoc) => taskDoc.data()).toList();
            print('[TaskHistory] Found ${tasks.length} tasks in subcollection for ${d.id}');
          } catch (e) {
            print('[TaskHistory] Failed to load tasks subcollection for ${d.id}: $e');
          }
        }

        for (final t in tasks) {
          final name = (t['taskName'] ?? t['name'] ?? 'Unnamed Task').toString();
          final completed = t['completed'] == true || t['isCompleted'] == true || t['status'] == 'completed';
          final reason = (t['reason'] ?? t['reasonNotCompleted'] ?? '').toString();
          final note = (t['note'] ?? t['notes'] ?? '').toString();
          final photos = List<String>.from(t['photoUrls'] ?? const []);

          // Checklist filter (best-effort, some data models store checklistId on parent)
          if (_selectedChecklist != 'all' && (data['templateId'] ?? data['checklistId']) != _selectedChecklist) {
            continue;
          }

          // Completion filter
          if (_selectedCompletion == 'completed' && !completed) continue;
          if (_selectedCompletion == 'incomplete' && completed) continue;
          if (_selectedCompletion == 'incomplete_with_reason' && (completed || reason.isEmpty)) continue;

          // Search filter
          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty &&
              !(name.toLowerCase().contains(q) || note.toLowerCase().contains(q) || reason.toLowerCase().contains(q))) {
            continue;
          }

          rows.add(
            _TaskRow(
              date: date,
              shiftName: shiftName,
              checklistName: checklistName,
              taskName: name,
              completed: completed,
              reason: reason,
              note: note,
              photoCount: photos.length,
              photoUrls: photos,
            ),
          );
        }
      }

      print('[TaskHistory] Final result: ${rows.length} tasks found');
      if (!mounted) return;
      setState(() => _rows = rows..sort((a, b) => b.date.compareTo(a.date)));
    } catch (e) {
      print('[TaskHistory] Error loading tasks: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 180)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _dateRange,
    );
    if (picked == null) return;
    setState(() => _dateRange = picked);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Compact filter controls
        Container(
          padding: const EdgeInsets.all(12),
          color: HandsColors.secondaryContainer,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 13, color: HandsColors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18, color: HandsColors.white70),
                          labelText: 'Search tasks',
                          labelStyle: const TextStyle(fontSize: 12, color: HandsColors.white70),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(color: HandsColors.white30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: HandsColors.white30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: HandsColors.handsOrange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: HandsColors.cardTertiary,
                        ),
                        onSubmitted: (_) => _load(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: HandsSecondaryButton(
                      text:
                          _dateRange == null
                              ? 'Date Range'
                              : '${DateFormat('M/d').format(_dateRange!.start)} - ${DateFormat('M/d').format(_dateRange!.end)}',
                      onPressed: _pickRange,
                      icon: Icons.date_range,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: DropdownButtonFormField<String>(
                        value: _selectedShift,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Shift',
                          labelStyle: TextStyle(fontSize: 11),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All shifts', style: TextStyle(fontSize: 12)),
                          ),
                          ...widget.shifts.map(
                            (s) => DropdownMenuItem(
                              value: s['id'],
                              child: Text(s['name'] ?? 'Shift', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedShift = v ?? 'all'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCompletion,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Status',
                          labelStyle: TextStyle(fontSize: 11),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'completed', child: Text('Done', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'incomplete', child: Text('Missed', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(
                            value: 'incomplete_with_reason',
                            child: Text('Missed w/ reason', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedCompletion = v ?? 'all'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 36,
                    child: HandsPrimaryButton(
                      text: 'Apply',
                      onPressed: _load,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: HandsTextButton(
                      text: 'Clear',
                      onPressed: () async {
                        setState(() {
                          _searchCtrl.clear();
                          _selectedShift = 'all';
                          _selectedChecklist = 'all';
                          _selectedCompletion = 'all';
                        });
                        await _load();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Results
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? const Center(
                    child: Text('No tasks found for selected filters.', style: TextStyle(color: Colors.grey)),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rows.length,
                    itemBuilder: (context, i) {
                      final r = _rows[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: HandsDecorations.tertiaryBoxDecoration,
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          title: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.taskName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${r.date} • ${r.shiftName}${r.checklistName.isNotEmpty ? ' • ${r.checklistName}' : ''}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Status badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: r.completed ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: r.completed ? Colors.green.shade200 : Colors.red.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      r.completed ? 'Done' : 'Missed',
                                      style: TextStyle(
                                        color: r.completed ? Colors.green.shade700 : Colors.red.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  // Indicators for additional content
                                  if (r.photoCount > 0 || r.reason.isNotEmpty || r.note.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.info_outline, size: 12, color: Theme.of(context).primaryColor),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          children: [
                            // Show additional details when expanded
                            if (r.reason.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Reason for not completing:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(r.reason, style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                                  ],
                                ),
                              ),
                            ],
                            if (r.note.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.note, size: 16, color: Colors.blue.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Note:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(r.note, style: TextStyle(fontSize: 11, color: Colors.blue.shade800)),
                                  ],
                                ),
                              ),
                            ],
                            if (r.photoUrls.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.photo_library, size: 16, color: Colors.green.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Photos (${r.photoCount}):',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          r.photoUrls.take(6).map((photoUrl) {
                                            return GestureDetector(
                                              onTap: () => _showFullScreenImage(context, photoUrl, r.taskName),
                                              child: Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.grey[300]!),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(7),
                                                  child: Image.network(
                                                    photoUrl,
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Container(
                                                        color: Colors.grey[200],
                                                        child: Center(
                                                          child: SizedBox(
                                                            width: 20,
                                                            height: 20,
                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        color: Colors.grey[200],
                                                        child: Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey[400],
                                                          size: 24,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                    if (r.photoUrls.length > 6) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '+${r.photoUrls.length - 6} more photos',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, String taskName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                // Full screen image
                Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[900],
                          child: const Center(child: CircularProgressIndicator(color: HandsColors.white)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[900],
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: HandsColors.white, size: 48),
                              SizedBox(height: 8),
                              Text('Failed to load image', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Header with task name and close button
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            taskName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black26,
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _TaskRow {
  final String date;
  final String shiftName;
  final String checklistName;
  final String taskName;
  final bool completed;
  final String reason;
  final String note;
  final int photoCount;
  final List<String> photoUrls;

  _TaskRow({
    required this.date,
    required this.shiftName,
    required this.checklistName,
    required this.taskName,
    required this.completed,
    required this.reason,
    required this.note,
    required this.photoCount,
    required this.photoUrls,
  });
}

class _StatusToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusToggleButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? HandsColors.handsOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.comfortaa(
            color: selected ? HandsColors.white : HandsColors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
