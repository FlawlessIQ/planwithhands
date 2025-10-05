import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/shared/components/shared_components.dart';
import 'package:hands_app/theme/theme.dart';
import 'package:hands_app/services/activity_tracker.dart';
import 'package:hands_app/data/models/missed_tasks_section.dart';
import 'package:hands_app/data/models/task_data.dart';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/global_widgets/professional_harvey_ball.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/services/organization_setup_service.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

import 'package:hands_app/widgets/condensed_setup_widget.dart';

class ManagerDashboardPage extends StatefulWidget {
  final String organizationId;
  const ManagerDashboardPage({super.key, required this.organizationId});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage>
    with WidgetsBindingObserver, ActivityTrackingMixin {
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
  List<MissedTasksSection> _yesterdayMissedSections = []; // Add raw sections for accurate counting
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

  @override
  void initState() {
    // WEB variant initialization instrumentation
    debugPrint('[WEBManagerDashboard] initState CALLED');
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _todayKey = _dateFormat.format(DateTime.now());
    _selectedLocationId = LocationSelectionService.instance.currentLocationId ?? _selectedLocationId;
    LocationSelectionService.instance.listenable.addListener(_onGlobalLocationChanged);
    _initializeDashboard();
  }

  // Handle app lifecycle changes to refresh data when user returns
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      // User returned to app - refresh missed tasks data
      _loadYesterdayMissed().catchError((e) {
        debugPrint('[ManagerDashboard] Error refreshing data on app resume: $e');
      });
    }
  }

  void _onGlobalLocationChanged() {
    final globalId = LocationSelectionService.instance.currentLocationId;
    if (globalId != null && globalId != _selectedLocationId) {
      setState(() {
        _selectedLocationId = globalId;
        final match = _availableLocations.firstWhere(
          (l) => l['id'] == globalId,
          orElse: () => {'name': _selectedLocationName},
        );
        _selectedLocationName = match['name'] as String? ?? _selectedLocationName;
      });
      unawaited(_loadCriticalData());
    }
  }

  // Progressive loading strategy for better performance
  Future<void> _initializeDashboard() async {
    // Phase 1: Essential setup (5s timeout)
    try {
      await Future.wait([_fetchUserRole(), _checkSetupStatus(), _loadLocations()]).timeout(const Duration(seconds: 5));

      // Phase 2: Load critical data (8s timeout)
      _loadCriticalData();

      // Phase 3: Start background processes
      _startAutoRefresh();
    } catch (e) {
      // Even if setup fails, continue with critical data loading
      _loadCriticalData();
      _startAutoRefresh();
    }
  }

  // Load time-sensitive data first
  Future<void> _loadCriticalData() async {
    if (!_metricsEnabled) return;
    try {
      await Future.wait([_loadLiveShifts(), _loadYesterdayMissed()]).timeout(const Duration(seconds: 8));

      // Start background loading of less critical data
      _loadBackgroundData();
    } catch (e) {
      // Continue with background loading even if critical data fails
      _loadBackgroundData();
    }
  }

  // Load trend data and analytics in the background
  void _loadBackgroundData() {
    if (!_metricsEnabled) return;
    // Use individual timeouts for each background operation
    _loadMissedTrend7d().timeout(const Duration(seconds: 10)).catchError((_) {});
    _loadFrequentMisses30d().timeout(const Duration(seconds: 15)).catchError((_) {});
    _loadPoorShifts30d().timeout(const Duration(seconds: 15)).catchError((_) {});
  }

  @override
  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    LocationSelectionService.instance.listenable.removeListener(_onGlobalLocationChanged);
    super.dispose();
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
      userRole = userDoc.data()?['userRole'] ?? 2; // Temporarily default to admin role
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

      // Global-first selection: prefer persisted global selection if it's valid
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

      // Sync global selection
      if (_selectedLocationId != null && LocationSelectionService.instance.currentLocationId != _selectedLocationId) {
        try {
          await LocationSelectionService.instance.setLocationAsync(_selectedLocationId!);
        } catch (_) {}
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
      logger.d('[WEBManagerDashboard] _loadYesterdayMissed ENTER (today=$today, location=$_selectedLocationId)');
      logger.d(
        '[WEBManagerDashboard] Using carry-forward tasks AND direct yesterday tasks for comprehensive Missed Yesterday count',
      );

      // Load carry-forward based sections AND direct missed tasks from yesterday
      final cfSections = await service.loadMissedTasksForToday(
        organizationId: widget.organizationId,
        targetDate: today,
        locationId: _selectedLocationId,
      );
      logger.d('[WEBManagerDashboard] CF loader returned ${cfSections.length} sections');

      // Load direct missed tasks from yesterday ONLY AS A FALLBACK when CF returns nothing.
      // CF is authoritative for "Missed Yesterday" once carry-forward has happened for today.
      List<MissedTasksSection> directYesterdaySections = [];
      if (cfSections.isEmpty) {
        try {
          directYesterdaySections = await service.loadMissedTasksDirectFromYesterday(
            organizationId: widget.organizationId,
            today: today,
            locationId: _selectedLocationId,
          );
          logger.d(
            '[WEBManagerDashboard] Direct yesterday loader (fallback) returned ${directYesterdaySections.length} sections',
          );
        } catch (e) {
          logger.w('[WEBManagerDashboard] Direct yesterday loader failed: $e');
        }
      } else {
        logger.d(
          '[WEBManagerDashboard] Skipping direct-yesterday loader because CF sections present: ${cfSections.length}',
        );
      }

      // Build grouped representation (taskName+shiftId) for display while retaining raw sections for accurate counting
      final Map<String, Map<String, dynamic>> groupedCF = {};
      final Set<String> processedTaskIds = {}; // Track processed tasks to avoid duplicates

      // Process carry-forward tasks FIRST (these are authoritative)
      for (final section in cfSections) {
        for (final task in section.tasks) {
          final taskId = task.taskId;
          processedTaskIds.add(taskId);

          final key = '${task.taskName}_${section.shiftId}';
          final g = groupedCF.putIfAbsent(
            key,
            () => {
              'taskName': task.taskName,
              'shiftId': section.shiftId,
              'shiftName': section.shiftName,
              'locationId': section.locationId,
              'count': 0,
              'completedToday': false,
            },
          );
          g['count'] = (g['count'] as int) + 1;
          if (task.completed) g['completedToday'] = true;
        }
      }

      // Process direct missed tasks from yesterday ONLY if they weren't already carried forward
      for (final section in directYesterdaySections) {
        for (final task in section.tasks) {
          final taskId = task.taskId;

          // Skip if this task was already processed as a carry-forward
          if (processedTaskIds.contains(taskId)) {
            continue;
          }

          final key = '${task.taskName}_${section.shiftId}';
          final g = groupedCF.putIfAbsent(
            key,
            () => {
              'taskName': task.taskName,
              'shiftId': section.shiftId,
              'shiftName': section.shiftName,
              'locationId': section.locationId,
              'count': 0,
              'completedToday': false,
            },
          );
          // For direct yesterday tasks, count them but they can't be "completed today" since they're yesterday's
          g['count'] = (g['count'] as int) + 1;
          // Don't update completedToday for yesterday's tasks
        }
      }

      // Combine sections for accurate counting, but deduplicate by task ID
      // Use a more robust deduplication key: checklistId + taskId to handle same task from different checklists
      final combinedSections = <MissedTasksSection>[];
      final seenTaskKeys = <String>{};

      // Add carry-forward sections first (only incomplete tasks)
      for (final section in cfSections) {
        final deduplicatedTasks = <TaskData>[];

        for (final task in section.tasks) {
          // Skip completed tasks immediately
          if (task.completed) continue;

          // Create a unique key combining checklistId and taskId to properly deduplicate
          final taskKey = '${task.checklistId}_${task.taskId}';

          // Skip if we've already seen this exact task
          if (seenTaskKeys.contains(taskKey)) continue;

          seenTaskKeys.add(taskKey);
          deduplicatedTasks.add(task);
        }

        if (deduplicatedTasks.isNotEmpty) {
          combinedSections.add(
            MissedTasksSection(
              shiftId: section.shiftId,
              shiftName: section.shiftName,
              organizationId: widget.organizationId,
              locationId: section.locationId,
              tasks: deduplicatedTasks,
            ),
          );
        }
      }

      // Add direct yesterday sections, but only tasks not already seen (and only incomplete tasks)
      for (final section in directYesterdaySections) {
        final deduplicatedTasks = <TaskData>[];

        for (final task in section.tasks) {
          // Skip completed tasks immediately
          if (task.completed) continue;

          // Create a unique key combining checklistId and taskId to properly deduplicate
          final taskKey = '${task.checklistId}_${task.taskId}';

          // Skip if we've already seen this exact task
          if (seenTaskKeys.contains(taskKey)) continue;

          seenTaskKeys.add(taskKey);
          deduplicatedTasks.add(task);
        }

        if (deduplicatedTasks.isNotEmpty) {
          combinedSections.add(
            MissedTasksSection(
              shiftId: section.shiftId,
              shiftName: section.shiftName,
              organizationId: widget.organizationId,
              locationId: section.locationId,
              tasks: deduplicatedTasks,
            ),
          );
        }
      }

      _yesterdayMissedSections = combinedSections;
      _yesterdayMissed = groupedCF.values.toList();

      // Diagnostics: log counts for CF, direct, and combined to verify no double-counting
      final cfIncompleteCount = cfSections.fold<int>(0, (sum, s) => sum + s.tasks.where((t) => !t.completed).length);
      final directCount = directYesterdaySections.fold<int>(0, (sum, s) => sum + s.tasks.length);
      final combinedCount = _yesterdayMissedSections.fold<int>(0, (sum, s) => sum + s.tasks.length);
      logger.d(
        '[WEBManagerDashboard] Counts -> CF(incomplete)=$cfIncompleteCount, direct(fallback)=$directCount, combined=$combinedCount',
      );

      if (_yesterdayMissedSections.isEmpty) {
        // As a safety, if CF failed to produce anything, fall back to legacy grouped method.
        logger.w('[WEBManagerDashboard] CF baseline empty; invoking legacy fallback (no direct enumeration)');
        try {
          final fallback = await service.getYesterdayMissedFromTodayCarryForward(
            organizationId: widget.organizationId,
            today: today,
            locationId: _selectedLocationId,
          );
          if (fallback.isNotEmpty) {
            _yesterdayMissed = fallback;
            logger.w('[WEBManagerDashboard] Legacy fallback supplied ${fallback.length} grouped entries');
          }
        } catch (fe, fst) {
          logger.e('[WEBManagerDashboard] Legacy fallback failed: $fe\n$fst');
        }
      }

      final finalRaw = _yesterdayMissedSections.fold<int>(0, (s, sec) => s + sec.tasks.length);

      // Debug: Log each section's tasks and their completion status
      for (final section in _yesterdayMissedSections) {
        logger.d('[WEBManagerDashboard] Section ${section.shiftName}: ${section.tasks.length} tasks');
        for (final task in section.tasks) {
          logger.d('[WEBManagerDashboard]   - ${task.taskId}: completed=${task.completed} "${task.taskName}"');
        }
      }

      logger.d(
        '[WEBManagerDashboard] FINAL MissedYesterday (CF+Direct) groups=${_yesterdayMissed.length} rawTasks=$finalRaw cfSections=${cfSections.length} directSections=${directYesterdaySections.length}',
      );
    } catch (e, st) {
      logger.e('[ManagerDashboard] loadMissedTasksForToday error: $e\n$st');
    } finally {
      if (!mounted) return;
      setState(() => _loadingYesterday = false);
    }
  }

  // _missedSignature removed after simplifying logic to CF-only (no merging step required).

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
      // Add console print for browser debugging visibility
      print('====== MANAGER DASHBOARD: Loading live shifts ======');
      print('Current location ID: $_selectedLocationId');

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

        // Determine whether this shift should be considered "today".
        // Some shifts are configured to repeat daily, have activeDays (1=Mon..7=Sun),
        // or a days list with weekday names. We need to be strict about this -
        // only show shifts that are explicitly scheduled for today's weekday.
        final now = DateTime.now();
        final weekday = now.weekday; // 1..7 (Monday=1, Sunday=7)
        bool scheduledToday = false;

        logger.i('[ManagerDashboard][DEBUG] Checking schedule for shift $shiftName on weekday $weekday');

        // repeatsDaily flag (may be stored as bool)
        if (shiftData['repeatsDaily'] == true) {
          logger.i('[ManagerDashboard][DEBUG] Shift $shiftName has repeatsDaily=true');
          scheduledToday = true;
        }

        // activeDays can be List<int> or List<String>
        if (!scheduledToday && (shiftData['activeDays'] is List)) {
          final active = (shiftData['activeDays'] as List).map((e) => e?.toString()).whereType<String>().toList();
          logger.i('[ManagerDashboard][DEBUG] Shift $shiftName activeDays: $active, checking against weekday $weekday');
          for (final a in active) {
            final ai = int.tryParse(a);
            if (ai != null && ai == weekday) {
              logger.i('[ManagerDashboard][DEBUG] Shift $shiftName matches activeDays: $ai == $weekday');
              scheduledToday = true;
              break;
            }
          }
        }

        // days may contain names like 'Monday' etc.
        if (!scheduledToday && (shiftData['days'] is List)) {
          final todayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][weekday - 1];
          final daysList =
              (shiftData['days'] as List).map((d) => d?.toString().toLowerCase()).whereType<String>().toList();
          logger.i('[ManagerDashboard][DEBUG] Shift $shiftName days: $daysList, checking against $todayName');
          if (daysList.contains(todayName.toLowerCase())) {
            logger.i('[ManagerDashboard][DEBUG] Shift $shiftName matches days: contains ${todayName.toLowerCase()}');
            scheduledToday = true;
          }
        }

        // Some shifts may have a specific shiftDate field (Timestamp/DateTime)
        if (!scheduledToday && shiftData.containsKey('shiftDate') && shiftData['shiftDate'] != null) {
          try {
            final raw = shiftData['shiftDate'];
            DateTime? sd;
            if (raw is DateTime) {
              sd = raw;
            } else if (raw is Timestamp)
              sd = raw.toDate();
            else if (raw is String)
              sd = DateTime.tryParse(raw);
            if (sd != null) {
              if (sd.year == now.year && sd.month == now.month && sd.day == now.day) {
                logger.i('[ManagerDashboard][DEBUG] Shift $shiftName matches shiftDate: $sd');
                scheduledToday = true;
              }
            }
          } catch (_) {}
        }

        // REMOVED: Don't automatically include shifts just because they have checklists
        // The presence of daily_checklists should not override explicit scheduling rules
        // if (!scheduledToday && checklistsSnap.docs.isNotEmpty) scheduledToday = true;

        logger.i('[ManagerDashboard][DEBUG] Final scheduledToday for shift $shiftName: $scheduledToday');

        // If not scheduled today, skip showing this shift in the Today's Shifts list
        if (!scheduledToday) {
          logger.i('[ManagerDashboard][DEBUG] Skipping shift $shiftName — not scheduled today (weekday=$weekday)');
          continue;
        }

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
      debugPrint(
        '[ManagerDashboard] _loadFrequentMisses30d: calling with locationId="$_selectedLocationId" (isNull=${_selectedLocationId == null}, isEmpty=${_selectedLocationId?.isEmpty})',
      );
      final service = DailyChecklistService();
      final list = await service.getFrequentlyMissedTasks(
        organizationId: widget.organizationId,
        days: 30,
        limit: 10,
        locationId: _selectedLocationId?.isNotEmpty == true ? _selectedLocationId : null,
      );
      debugPrint('[ManagerDashboard] _loadFrequentMisses30d: received ${list.length} items');
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
      // DISABLED: Skip fallback when a location is selected to ensure proper filtering
      if (docs.isEmpty && _availableLocations.isNotEmpty && preferredLocation == null) {
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
      // DISABLED: Skip global fallback when a location is selected to ensure proper filtering
      if (docs.isEmpty && preferredLocation == null) {
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
      final Map<String, String?> shiftNameCache = {};

      for (final d in docs) {
        final dataRaw = d.data();
        final data = (dataRaw is Map<String, dynamic>) ? dataRaw : <String, dynamic>{};
        final shiftId = (data['shiftId'] ?? '').toString();

        if (shiftId.isEmpty) {
          logger.w('[ManagerDashboard][DEBUG] Skipping daily_checklist ${d.id} due to missing shiftId.');
          continue;
        }

        String? shiftName;

        // Check cache first
        if (shiftNameCache.containsKey(shiftId)) {
          shiftName = shiftNameCache[shiftId];
        } else {
          // Fetch from Firestore
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
                shiftNameCache[shiftId] = resolved; // Cache the name
              } else {
                // Shift exists but has no name, treat as invalid
                shiftNameCache[shiftId] = null;
              }
            } else {
              // Shift is deleted, cache this info so we don't look it up again
              shiftNameCache[shiftId] = null; // Null indicates deleted
            }
          } catch (e) {
            logger.w('[ManagerDashboard][DEBUG] Failed to resolve shiftName for shiftId=$shiftId: $e');
            shiftNameCache[shiftId] = null; // Also cache failure to avoid retries
          }
        }

        // If shiftName is null or empty, it means the shift was deleted or invalid. Skip it.
        if (shiftName == null || shiftName.isEmpty) {
          logger.i(
            '[ManagerDashboard][DEBUG] Skipping checklist ${d.id} because shift $shiftId is deleted or invalid.',
          );
          continue;
        }

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
                final total = math.max((e.value['total'] ?? 0).toInt(), 1);
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
      if (!mounted || _selectedLocationId == null || !_metricsEnabled) return;
      // Refresh both live shifts and missed tasks to keep data synchronized
      await Future.wait([_loadLiveShifts(), _loadYesterdayMissed()]);
    });
  }

  // Manual refresh method for when data needs immediate update
  Future<void> _refreshAllData() async {
    setState(() {
      _loadingLive = true;
    });

    try {
      await Future.wait([_loadLiveShifts(), _loadYesterdayMissed()]);
    } catch (e) {
      logger.w('[ManagerDashboard] Error during manual refresh: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingLive = false;
        });
      }
    }
  }

  void _onMetricsEnabled() async {
    setState(() => _metricsEnabled = true);
    await _ensureDailyChecklistsExist();
    await _loadAll();
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

    // Wrap the main content in error boundary for web compatibility
    return Scaffold(
      backgroundColor: HandsColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: HandsColors.cardPrimary,
        elevation: 0,
        toolbarHeight: kToolbarHeight,
        title: GenericAppBarContent(appBarTitle: 'Manager Dashboard', userRole: userRole),
        automaticallyImplyLeading: false,
        actions: [UnifiedMenuButton(userRole: userRole, organizationId: widget.organizationId)],
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 1, userRole: userRole),
      body: Builder(
        builder: (context) {
          try {
            if (!_metricsEnabled) {
              return CondensedSetupWidget(organizationId: widget.organizationId, onMetricsEnabled: _onMetricsEnabled);
            }
            return _buildDashboardGrid();
          } catch (e) {
            logger.e('[ManagerDashboard] Error building dashboard: $e');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: HandsColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Dashboard temporarily unavailable',
                    style: GoogleFonts.comfortaa(fontSize: 16, color: HandsColors.white, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please refresh the page',
                    style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Force a rebuild
                      setState(() {});
                    },
                    child: const Text('Refresh Dashboard'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildDashboardGrid() {
    // Simplified web layout to avoid unbounded height constraints
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row - two main cards side by side
          SizedBox(
            height: 350, // Reduced height to prevent overflow
            child: Row(
              children: [
                // Missed Yesterday (left half)
                Expanded(
                  flex: 1,
                  child: _SimpleDashboardCard(
                    title: 'MISSED YESTERDAY',
                    icon: Icons.report_gmailerrorred,
                    accentColor: HandsColors.error,
                    loading: _loadingYesterday,
                    onTap: _openAllMissedYesterday,
                    actions: [
                      IconButton(
                        onPressed: () async {
                          setState(() => _loadingYesterday = true);
                          await _loadYesterdayMissed();
                          setState(() => _loadingYesterday = false);
                        },
                        icon: const Icon(Icons.refresh, color: HandsColors.white70),
                        tooltip: 'Refresh Missed Tasks',
                      ),
                    ],
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Main metric - use raw sections if available, otherwise fall back to grouped count
                        Text(
                          () {
                            // Sections now only contain incomplete tasks, so count all tasks in sections
                            final rawTaskCount =
                                _yesterdayMissedSections.isNotEmpty
                                    ? _yesterdayMissedSections.fold<int>(
                                      0,
                                      (sum, section) => sum + section.tasks.length,
                                    )
                                    : _yesterdayMissed.fold<int>(0, (sum, e) => sum + (e['count'] as int? ?? 1));

                            // Debug logging to track counting method
                            final countingMethod = _yesterdayMissedSections.isNotEmpty ? 'sections' : 'grouped';
                            final shiftCount =
                                _yesterdayMissedSections.isNotEmpty
                                    ? _yesterdayMissedSections.length
                                    : _yesterdayMissed.map((e) => e['shiftId'] ?? e['shiftName'] ?? '').toSet().length;

                            logger.d(
                              '[ManagerDashboard] DISPLAY: $rawTaskCount tasks via $countingMethod method across $shiftCount shifts',
                            );
                            print(
                              'MANAGER DASHBOARD COUNT DEBUG: $rawTaskCount tasks ($countingMethod method), $shiftCount shifts',
                            );

                            return '$rawTaskCount';
                          }(),
                          style: GoogleFonts.comfortaa(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: HandsColors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          () {
                            // Use actual shift count for consistency with user dashboard
                            final actualShiftCount =
                                _yesterdayMissedSections.isNotEmpty
                                    ? _yesterdayMissedSections.length
                                    : _yesterdayMissed.map((e) => e['shiftId'] ?? e['shiftName'] ?? '').toSet().length;

                            return 'missed tasks across $actualShiftCount shifts';
                          }(),
                          style: GoogleFonts.comfortaa(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: HandsColors.white70,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // 7-day trend chart
                        Text(
                          '7-DAY TREND',
                          style: GoogleFonts.comfortaa(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: HandsColors.white70,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(height: 80, child: MiniSparkBars(values: _missedTrend7d, height: 80)),
                        const Spacer(),
                        // Location footer
                        if (_selectedLocationName != null)
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16, color: HandsColors.white70),
                              const SizedBox(width: 4),
                              Text(
                                _selectedLocationName!,
                                style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white70),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Today's Shifts (right half)
                Expanded(
                  flex: 1,
                  child: _SimpleDashboardCard(
                    title: "TODAY'S SHIFTS",
                    icon: Icons.live_tv,
                    accentColor: HandsColors.handsOrange,
                    loading: _loadingLive,
                    onTap: _openTodayShifts,
                    actions: [
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.all(color: HandsColors.white30),
                          borderRadius: BorderRadius.circular(18),
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
                              label: 'Complete',
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
                        icon: const Icon(Icons.refresh, color: HandsColors.white70),
                        tooltip: 'Refresh',
                      ),
                    ],
                    content: SizedBox(
                      height: 240, // Reduced height for better fit
                      child: _SimpleShiftList(shifts: _filteredLiveShifts, onOpen: _openTodayShifts),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bottom row - responsive layout: two metric cards side-by-side and
          // the Task History card below on narrow screens; three-column layout
          // on wide screens.
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;

              // Reusable widgets for the three cards (kept inline to preserve original content)
              final frequentCard = _SimpleDashboardCard(
                title: 'FREQUENT MISSES (30D)',
                icon: Icons.trending_down,
                accentColor: HandsColors.error,
                loading: _loadingFrequent,
                onTap: _openAllFrequentMisses,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      '${_frequentMisses30d.length}',
                      style: GoogleFonts.comfortaa(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: HandsColors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'hot spots',
                      style: GoogleFonts.comfortaa(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: HandsColors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _SimpleTopList(
                        items:
                            _frequentMisses30d.take(5).map((t) {
                              final name = (t['taskName'] ?? 'Unknown Task').toString();
                              final count = (t['count'] ?? t['missedCount'] ?? 0).toString();
                              return {'name': name, 'value': '×$count'};
                            }).toList(),
                        emptyLabel: 'No frequent misses found',
                      ),
                    ),
                  ],
                ),
              );

              final poorCard = _SimpleDashboardCard(
                title: 'POOR PERFORMING (30D)',
                icon: Icons.speed,
                accentColor: HandsColors.handsOrange,
                loading: _loadingPoorShifts,
                onTap: _openPoorShiftDetails,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      '${_poorShifts30d.length}',
                      style: GoogleFonts.comfortaa(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: HandsColors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _poorShifts30d.isEmpty ? 'all good' : 'flagged',
                      style: GoogleFonts.comfortaa(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _poorShifts30d.isEmpty ? HandsColors.sageGreen : HandsColors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _SimpleTopList(
                        items:
                            _poorShifts30d.take(5).map((m) {
                              final name = (m['shiftName'] ?? 'Unknown').toString();
                              final pct = ((m['avgCompletion'] as double?) ?? 0) * 100;
                              return {'name': name, 'value': '${pct.toStringAsFixed(0)}%'};
                            }).toList(),
                        emptyLabel: 'All shifts performing well',
                      ),
                    ),
                  ],
                ),
              );

              final taskHistoryCard = _SimpleDashboardCard(
                title: 'TASK HISTORY',
                icon: Icons.analytics,
                accentColor: HandsColors.handsOrange,
                onTap: _openTaskHistorySheet,
                content: LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive sizing based on available space
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final isMobile = width < 300;
                    final isCompact = height < 200;

                    // Calculate dynamic sizes
                    final iconSize = isMobile ? 50.0 : (isCompact ? 60.0 : 80.0);
                    final descriptionFontSize = isMobile ? 12.0 : (isCompact ? 13.0 : 16.0);
                    final buttonFontSize = isMobile ? 11.0 : (isCompact ? 12.0 : 14.0);
                    final buttonPadding =
                        isMobile
                            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                            : const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
                    final verticalSpacing = isMobile ? 12.0 : (isCompact ? 16.0 : 24.0);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics, size: iconSize, color: HandsColors.handsOrange.withOpacity(0.5)),
                        SizedBox(height: verticalSpacing),
                        Flexible(
                          child: Text(
                            'Detailed task analytics and historical performance data',
                            textAlign: TextAlign.center,
                            maxLines: isMobile ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.comfortaa(
                              fontSize: descriptionFontSize,
                              color: HandsColors.white70,
                              height: 1.3,
                            ),
                          ),
                        ),
                        SizedBox(height: verticalSpacing),
                        Container(
                          padding: buttonPadding,
                          decoration: BoxDecoration(
                            color: HandsColors.handsOrange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                            border: Border.all(color: HandsColors.handsOrange),
                          ),
                          child: Text(
                            'VIEW REPORTS',
                            style: GoogleFonts.comfortaa(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                              color: HandsColors.handsOrange,
                              letterSpacing: isMobile ? 0.5 : 1.0,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );

              if (isNarrow) {
                // Two metric cards in a row and task history below
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 260,
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: frequentCard),
                          const SizedBox(width: 24),
                          Expanded(flex: 1, child: poorCard),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Task history as full-width card
                    SizedBox(height: 180, child: taskHistoryCard),
                  ],
                );
              }

              // Wide layout: three columns side-by-side (preserve original sizing)
              return SizedBox(
                height: 350,
                child: Row(
                  children: [
                    Expanded(flex: 1, child: frequentCard),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: poorCard),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: taskHistoryCard),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredLiveShifts {
    if (_selectedStatusFilter == null) return _liveShifts;

    if (_selectedStatusFilter == 'live') {
      // Show shifts that are in progress (exclude upcoming 'Starts in')
      return _liveShifts.where((s) {
        final timeStatus = s['timeStatus'].toString();
        return timeStatus.contains('remaining');
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
    // Default date range: last 3 days
    _selectedDateRange ??= DateTimeRange(start: DateTime.now().subtract(const Duration(days: 3)), end: DateTime.now());
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

class MiniSparkBars extends StatelessWidget {
  final List<int> values;
  final double height;
  const MiniSparkBars({super.key, required this.values, this.height = 60}); // Increased from 40 to 60

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height, child: const SizedBox.shrink());

    // Simple bar chart instead of custom paint to avoid mouse tracker issues on web
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: double.infinity,
                      height: _calculateBarHeight(values[i], values, height - 20),
                      decoration: BoxDecoration(color: _getTrendColor(values), borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 4),
                    Text('${values[i]}', style: GoogleFonts.comfortaa(fontSize: 8, color: HandsColors.white70)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateBarHeight(int value, List<int> allValues, double maxHeight) {
    if (allValues.isEmpty) return 0;
    final maxValue = allValues.reduce((a, b) => a > b ? a : b);
    final minValue = allValues.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    if (range == 0) return maxHeight * 0.5;
    return ((value - minValue) / range) * maxHeight * 0.8 + maxHeight * 0.2;
  }

  Color _getTrendColor(List<int> values) {
    if (values.length < 2) return HandsColors.handsOrange;
    final firstValue = values.first;
    final lastValue = values.last;
    return lastValue > firstValue ? HandsColors.error : HandsColors.sageGreen;
  }
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
  List<_TaskRow> _allRows = [];
  List<_TaskRow> _displayedRows = [];
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  // User name cache to avoid repeated lookups
  final Map<String, String> _userNameCache = {};

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

  void _updateDisplayedRows() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _allRows.length);
    setState(() {
      _displayedRows = _allRows.sublist(startIndex, endIndex);
    });
  }

  void _loadMore() {
    if ((_currentPage + 1) * _itemsPerPage < _allRows.length) {
      setState(() {
        _currentPage++;
      });
      _updateDisplayedRows();
    }
  }

  // Function to resolve user UID to display name
  Future<String> _resolveUserName(String uid) async {
    if (uid.isEmpty || uid == 'Unknown') return 'Unknown';

    // Check cache first
    if (_userNameCache.containsKey(uid)) {
      return _userNameCache[uid]!;
    }

    try {
      final userDoc = await FirestoreEnforcer.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final firstName = userData['firstName'] ?? '';
        final lastName = userData['lastName'] ?? '';
        final displayName = '$firstName $lastName'.trim();
        final userName = displayName.isNotEmpty ? displayName : (userData['email'] ?? uid);
        _userNameCache[uid] = userName;
        return userName;
      }
    } catch (e) {
      print('[TaskHistory] Error resolving user name for $uid: $e');
    }

    _userNameCache[uid] = uid; // Cache the UID itself as fallback
    return uid;
  }

  // Function to format timestamp
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp.toString().isEmpty) return '';

    try {
      DateTime dateTime;

      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return timestamp.toString();
      }

      return DateFormat('MMM dd, HH:mm').format(dateTime);
    } catch (e) {
      print('[TaskHistory] Error formatting timestamp $timestamp: $e');
      return timestamp.toString();
    }
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
        final checklistName = (data['templateName'] ?? data['checklistName'] ?? '').toString();

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
          final reason = (t['reason'] ?? t['reasonNotCompleted'] ?? t['reasonForNotCompleting'] ?? '').toString();
          final note = (t['note'] ?? t['notes'] ?? t['taskNote'] ?? '').toString();

          // Handle photos with multiple possible field names
          List<String> photos = [];
          print('[TaskHistory] Debug: Checking photo fields for task: $name');
          print('[TaskHistory] Debug: Task data keys: ${t.keys.toList()}');

          if (t['photoUrls'] != null) {
            photos = List<String>.from(t['photoUrls']);
            print('[TaskHistory] Debug: Found photoUrls: $photos');
          } else if (t['photos'] != null) {
            photos = List<String>.from(t['photos']);
            print('[TaskHistory] Debug: Found photos: $photos');
          } else if (t['imageUrls'] != null) {
            photos = List<String>.from(t['imageUrls']);
            print('[TaskHistory] Debug: Found imageUrls: $photos');
          } else if (t['photo'] != null) {
            final photoValue = t['photo'];
            if (photoValue is String && photoValue.isNotEmpty) {
              photos = [photoValue];
            } else if (photoValue is List) {
              photos = List<String>.from(photoValue);
            }
            print('[TaskHistory] Debug: Found photo: $photos');
          } else if (t['photoUrl'] != null) {
            final photoUrl = t['photoUrl'].toString();
            if (photoUrl.isNotEmpty) {
              photos = [photoUrl];
            }
            print('[TaskHistory] Debug: Found photoUrl: $photos');
          }
          print('[TaskHistory] Debug: Final photos list: $photos');

          // Extract completedBy UID and resolve to user name
          final completedByUid =
              (t['completedBy'] ?? t['completedByUserId'] ?? t['completedByUserName'] ?? '').toString();
          String completedByName = '';
          String formattedTime = '';

          if (completed && completedByUid.isNotEmpty) {
            // Resolve user name from UID
            completedByName = await _resolveUserName(completedByUid);

            // Format timestamp
            final timeCompleted = t['timeCompleted'] ?? t['completedAt'] ?? t['updatedAt'] ?? t['timestamp'];
            formattedTime = _formatTimestamp(timeCompleted);
          }

          final photoRequired = t['photoRequired'] == true || t['requiresPhoto'] == true || t['requirePhoto'] == true;

          // If photoRequired is false but we have templateTaskId, try to get it from the template
          bool finalPhotoRequired = photoRequired;
          if (!photoRequired) {
            final templateTaskId = t['templateTaskId']?.toString();
            final templateId = data['checklistTemplateId']?.toString() ?? data['templateId']?.toString();

            if (templateTaskId != null && templateId != null && templateId.isNotEmpty) {
              try {
                // Get template task to check photoRequired
                final templateTaskDoc =
                    await FirestoreEnforcer.instance
                        .collection('organizations')
                        .doc(widget.organizationId)
                        .collection('checklist_templates')
                        .doc(templateId)
                        .collection('tasks')
                        .doc(templateTaskId)
                        .get();

                if (templateTaskDoc.exists) {
                  final templateTaskData = templateTaskDoc.data()!;
                  finalPhotoRequired = templateTaskData['photoRequired'] == true;
                }
              } catch (e) {
                // Ignore template lookup errors
              }
            }
          }

          // Checklist filter (best-effort, some data models store checklistId on parent)
          if (_selectedChecklist != 'all' && (data['templateId'] ?? data['checklistId']) != _selectedChecklist) {
            continue;
          }

          // Completion filter
          if (_selectedCompletion == 'completed' && !completed) continue;
          if (_selectedCompletion == 'incomplete' && completed) continue;
          if (_selectedCompletion == 'incomplete_with_reason' && (completed || reason.isEmpty)) continue;
          if (_selectedCompletion == 'photo_added' && photos.isEmpty) continue;
          if (_selectedCompletion == 'notes_added' && note.isEmpty) continue;
          if (_selectedCompletion == 'photo_required' && !finalPhotoRequired) continue;

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
              completedBy: completedByName,
              timeCompleted: formattedTime,
              photoRequired: finalPhotoRequired,
            ),
          );
        }
      }

      print('[TaskHistory] Final result: ${rows.length} tasks found');
      if (!mounted) return;
      setState(() {
        _allRows = rows..sort((a, b) => b.date.compareTo(a.date));
        _currentPage = 0;
      });
      _updateDisplayedRows();
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
        // Modern filter section with dark theme
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: HandsColors.cardTertiary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HandsColors.white12, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Task History Filters',
                style: GoogleFonts.comfortaa(fontSize: 16, fontWeight: FontWeight.bold, color: HandsColors.white),
              ),
              const SizedBox(height: 16),

              // Search and Date Range Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: HandsColors.white70, size: 20),
                        labelText: 'Search tasks...',
                        labelStyle: GoogleFonts.comfortaa(fontSize: 12, color: HandsColors.white70),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: HandsColors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: HandsColors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: HandsColors.primaryContainer,
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HandsSecondaryButton(
                      text:
                          _dateRange == null
                              ? 'Select Date Range'
                              : '${DateFormat('M/d').format(_dateRange!.start)} - ${DateFormat('M/d').format(_dateRange!.end)}',
                      onPressed: _pickRange,
                      icon: Icons.date_range,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Dropdown filters row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedShift,
                      style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white),
                      dropdownColor: HandsColors.primaryContainer,
                      decoration: InputDecoration(
                        labelText: 'Shift',
                        labelStyle: GoogleFonts.comfortaa(fontSize: 12, color: HandsColors.white70),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: HandsColors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: HandsColors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: HandsColors.primaryContainer,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'All shifts',
                            style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white),
                          ),
                        ),
                        ...widget.shifts.map(
                          (s) => DropdownMenuItem(
                            value: s['id'],
                            child: Text(
                              s['name'] ?? 'Shift',
                              style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedShift = v ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCompletion,
                      style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white),
                      dropdownColor: HandsColors.primaryContainer,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: GoogleFonts.comfortaa(fontSize: 12, color: HandsColors.white70),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: HandsColors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: HandsColors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: HandsColors.handsOrange, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: HandsColors.primaryContainer,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All', style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white)),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Done', style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white)),
                        ),
                        DropdownMenuItem(
                          value: 'incomplete',
                          child: Text('Missed', style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white)),
                        ),
                        DropdownMenuItem(
                          value: 'incomplete_with_reason',
                          child: Text(
                            'Missed w/ reason',
                            style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'photo_added',
                          child: Text(
                            'Photo added',
                            style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'notes_added',
                          child: Text(
                            'Notes added',
                            style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'photo_required',
                          child: Text(
                            'Photo required',
                            style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedCompletion = v ?? 'all'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: HandsPrimaryButton(
                      text: 'Apply Filters',
                      onPressed: _load,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HandsSecondaryButton(
                      text: 'Clear All',
                      onPressed: () async {
                        setState(() {
                          _searchCtrl.clear();
                          _selectedShift = 'all';
                          _selectedChecklist = 'all';
                          _selectedCompletion = 'all';
                          _currentPage = 0;
                        });
                        await _load();
                      },
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),

              // Results summary
              if (_allRows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Found ${_allRows.length} tasks • Showing ${_displayedRows.length} of ${_allRows.length}',
                    style: GoogleFonts.comfortaa(fontSize: 12, color: HandsColors.white70),
                  ),
                ),
            ],
          ),
        ),

        // Results section
        Expanded(
          child:
              _loading
                  ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(HandsColors.handsOrange),
                    ),
                  )
                  : _allRows.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: HandsColors.white30),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks found',
                          style: GoogleFonts.comfortaa(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: HandsColors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or date range',
                          style: GoogleFonts.comfortaa(fontSize: 14, color: HandsColors.white70),
                        ),
                      ],
                    ),
                  )
                  : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _displayedRows.length,
                          itemBuilder: (context, i) {
                            final r = _displayedRows[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: HandsColors.cardTertiary,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: HandsColors.white12, width: 1),
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.all(16),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.taskName,
                                            style: GoogleFonts.comfortaa(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: HandsColors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${r.date} • ${r.shiftName}${r.checklistName.isNotEmpty ? ' • ${r.checklistName}' : ''}',
                                            style: GoogleFonts.comfortaa(fontSize: 12, color: HandsColors.white70),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: r.completed ? HandsColors.sageGreen : HandsColors.error,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                r.completed ? Icons.check_circle : Icons.cancel,
                                                size: 14,
                                                color: HandsColors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                r.completed ? 'Completed' : 'Missed',
                                                style: GoogleFonts.comfortaa(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: HandsColors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Content indicators
                                        if (r.photoCount > 0 || r.reason.isNotEmpty || r.note.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: HandsColors.handsOrange.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: HandsColors.handsOrange, width: 1),
                                            ),
                                            child: const Icon(
                                              Icons.info_outline,
                                              size: 14,
                                              color: HandsColors.handsOrange,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                children: [
                                  // Expanded content with dark theme
                                  if (r.completed && r.completedBy.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: HandsColors.sageGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: HandsColors.sageGreen.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.person_outlined, size: 18, color: HandsColors.sageGreen),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Completed by:',
                                                style: GoogleFonts.comfortaa(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: HandsColors.sageGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  r.completedBy,
                                                  style: GoogleFonts.comfortaa(fontSize: 12, color: HandsColors.white),
                                                ),
                                              ),
                                              if (r.timeCompleted.isNotEmpty) ...[
                                                Icon(Icons.access_time, size: 14, color: HandsColors.sageGreen),
                                                const SizedBox(width: 4),
                                                Text(
                                                  r.timeCompleted,
                                                  style: GoogleFonts.comfortaa(
                                                    fontSize: 11,
                                                    color: HandsColors.white70,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (r.reason.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: HandsColors.amber.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: HandsColors.amber.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.warning_amber, size: 18, color: HandsColors.amber),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Reason for not completing:',
                                                style: GoogleFonts.comfortaa(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: HandsColors.amber,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            r.reason,
                                            style: GoogleFonts.comfortaa(fontSize: 12, color: HandsColors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (r.note.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: HandsColors.handsOrange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: HandsColors.handsOrange.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.note, size: 18, color: HandsColors.handsOrange),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Note:',
                                                style: GoogleFonts.comfortaa(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: HandsColors.handsOrange,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            r.note,
                                            style: GoogleFonts.comfortaa(fontSize: 12, color: HandsColors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (r.photoUrls.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: HandsColors.sageGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: HandsColors.sageGreen.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.photo_library, size: 18, color: HandsColors.sageGreen),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Photos (${r.photoCount}):',
                                                style: GoogleFonts.comfortaa(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: HandsColors.sageGreen,
                                                ),
                                              ),
                                              if (r.photoRequired) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: HandsColors.handsOrange.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: HandsColors.handsOrange),
                                                  ),
                                                  child: Text(
                                                    'REQUIRED',
                                                    style: GoogleFonts.comfortaa(
                                                      color: HandsColors.handsOrange,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children:
                                                r.photoUrls.take(6).map((photoUrl) {
                                                  print('[TaskHistory] Debug: Attempting to load image: $photoUrl');
                                                  return GestureDetector(
                                                    onTap: () => _showFullScreenImage(context, photoUrl, r.taskName),
                                                    child: Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: HandsColors.white12),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: Image.network(
                                                          photoUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            print(
                                                              '[TaskHistory] Debug: Image load error for $photoUrl: $error',
                                                            );
                                                            return Container(
                                                              color: HandsColors.cardTertiary,
                                                              child: Column(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  const Icon(
                                                                    Icons.broken_image,
                                                                    color: HandsColors.white30,
                                                                    size: 32,
                                                                  ),
                                                                  Text(
                                                                    'Failed to load',
                                                                    style: GoogleFonts.comfortaa(
                                                                      fontSize: 8,
                                                                      color: HandsColors.white30,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                          loadingBuilder: (context, child, loadingProgress) {
                                                            if (loadingProgress == null) return child;
                                                            return Container(
                                                              color: HandsColors.cardTertiary,
                                                              child: Center(
                                                                child: CircularProgressIndicator(
                                                                  value:
                                                                      loadingProgress.expectedTotalBytes != null
                                                                          ? loadingProgress.cumulativeBytesLoaded /
                                                                              loadingProgress.expectedTotalBytes!
                                                                          : null,
                                                                  strokeWidth: 2,
                                                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                                                    HandsColors.handsOrange,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                          ),
                                          if (r.photoUrls.length > 6)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Text(
                                                '+ ${r.photoUrls.length - 6} more photos',
                                                style: GoogleFonts.comfortaa(fontSize: 11, color: HandsColors.white70),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ] else if (r.photoRequired) ...[
                                    // Show when photo was required but not added
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: HandsColors.amber.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: HandsColors.amber.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.photo_camera_outlined, size: 18, color: HandsColors.amber),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Photo was required but not added',
                                            style: GoogleFonts.comfortaa(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: HandsColors.amber,
                                            ),
                                          ),
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

                      // Pagination controls
                      if (_allRows.isNotEmpty && (_currentPage + 1) * _itemsPerPage < _allRows.length)
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: HandsPrimaryButton(
                            text: 'Load 10 More Tasks',
                            onPressed: _loadMore,
                            icon: Icons.expand_more,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                    ],
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
  final String completedBy;
  final String timeCompleted;
  final bool photoRequired;

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
    required this.completedBy,
    required this.timeCompleted,
    required this.photoRequired,
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
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ===== Simple Web Widgets =====

class _SimpleDashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final bool loading;
  final VoidCallback? onTap;
  final Widget? content;
  final List<Widget>? actions;

  const _SimpleDashboardCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    this.loading = false,
    this.onTap,
    this.content,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: HandsDecorations.primaryBoxDecoration.copyWith(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.comfortaa(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HandsColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),

              // Content
              if (loading)
                SizedBox(
                  height: 240, // Reduced loading height
                  child: Center(
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentColor)),
                  ),
                )
              else if (content != null)
                Expanded(child: content!),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleShiftList extends StatefulWidget {
  final List<Map<String, dynamic>> shifts;
  final VoidCallback? onOpen;

  const _SimpleShiftList({required this.shifts, this.onOpen});

  @override
  State<_SimpleShiftList> createState() => _SimpleShiftListState();
}

class _SimpleShiftListState extends State<_SimpleShiftList> {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController(viewportFraction: 0.85);
  bool _showLeft = false;
  bool _showRight = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _pageController.addListener(_onPage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndicators());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.removeListener(_onPage);
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() => _updateIndicators();
  void _onPage() {
    final p = (_pageController.page ?? 0).round();
    if (p != _currentPage) setState(() => _currentPage = p);
    _updateIndicators();
  }

  void _updateIndicators() {
    if (!mounted) return;
    final isNarrow = MediaQuery.of(context).size.width < 420;

    if (isNarrow) {
      final maxScroll =
          _scrollController.position.hasContentDimensions ? _scrollController.position.maxScrollExtent : 0.0;
      final offset = _scrollController.offset;
      setState(() {
        _showLeft = offset > 8;
        _showRight = maxScroll - offset > 8;
      });
    } else {
      // For desktop horizontal scroll, we don't need navigation indicators
      // The user can just scroll horizontally or use scroll wheel
      setState(() {
        _showLeft = false;
        _showRight = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shifts = widget.shifts;
    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 48, color: HandsColors.white30),
            const SizedBox(height: 16),
            Text('No live shifts', style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 16)),
          ],
        ),
      );
    }

    final isNarrow = MediaQuery.of(context).size.width < 420;

    // Narrow devices: horizontal scroll similar to mobile
    if (isNarrow) {
      return SizedBox(
        height: 240,
        child: Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              itemCount: shifts.length,
              itemBuilder: (context, i) {
                final shift = shifts[i];
                return SizedBox(width: 140, child: _WebShiftCard(shift: shift, onOpen: widget.onOpen));
              },
            ),
            if (_showLeft)
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                child: Opacity(opacity: 0.35, child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 18)),
              ),
            if (_showRight)
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: Opacity(opacity: 0.35, child: Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18)),
              ),
          ],
        ),
      );
    }

    // Desktop/tablet: horizontal scrolling layout that shows all shifts
    print('SHIFT LIST DEBUG: ${shifts.length} shifts, using horizontal scroll layout');

    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: shifts.length,
        itemBuilder: (context, index) {
          final shift = shifts[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: _WebShiftCard(shift: shift, onOpen: widget.onOpen),
          );
        },
      ),
    );
  }
}

// Small card used in web shift lists
class _WebShiftCard extends StatelessWidget {
  final Map<String, dynamic> shift;
  final VoidCallback? onOpen;
  const _WebShiftCard({required this.shift, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final shiftName = shift['shiftName']?.toString() ?? 'Unknown';
    final timeStatus = shift['timeStatus']?.toString() ?? '';
    final isLive = timeStatus.contains('remaining');
    final completionPct = (shift['completionPct'] as double?) ?? 0.0;
    final completedTasks = (shift['completedTasks'] as int?) ?? 0;
    final totalTasks = (shift['totalTasks'] as int?) ?? 0;

    return Material(
      color: HandsColors.cardTertiary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive sizing based on available space
              final cardHeight = constraints.maxHeight;
              final cardWidth = constraints.maxWidth;

              // Calculate dynamic sizes
              final titleFontSize = (cardWidth * 0.08).clamp(12.0, 16.0);
              final harveyBallSize = (cardHeight * 0.35).clamp(50.0, 90.0);
              final taskFontSize = (cardWidth * 0.06).clamp(10.0, 14.0);
              final statusFontSize = (cardWidth * 0.055).clamp(9.0, 12.0);

              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Shift name with responsive typography
                  Text(
                    shiftName,
                    style: GoogleFonts.comfortaa(
                      color: HandsColors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Professional Harvey Ball with responsive sizing
                  Flexible(
                    child: ProfessionalHarveyBall(
                      percentage: completionPct,
                      size: harveyBallSize,
                      showPercentage: true,
                      animate: true,
                      strokeWidth: 3.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Task info and status with responsive typography
                  Column(
                    children: [
                      Text(
                        '$completedTasks/$totalTasks tasks',
                        style: GoogleFonts.comfortaa(
                          color: HandsColors.white70,
                          fontSize: taskFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (timeStatus.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isLive ? HandsColors.sageGreen : HandsColors.white30,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                timeStatus,
                                style: GoogleFonts.comfortaa(
                                  color: isLive ? HandsColors.sageGreen : HandsColors.white70,
                                  fontSize: statusFontSize,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SimpleTopList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyLabel;

  const _SimpleTopList({required this.items, this.emptyLabel = 'No items'});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyLabel, style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 16)));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final name = item['name']?.toString() ?? 'Unknown';
        final value = item['value']?.toString() ?? '';

        return Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.comfortaa(color: HandsColors.white, fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.comfortaa(color: HandsColors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }
}
