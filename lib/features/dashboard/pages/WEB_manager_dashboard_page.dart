import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/services/organization_setup_service.dart';
import 'package:hands_app/services/location_selection_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

import 'package:hands_app/widgets/condensed_setup_widget.dart';
import 'package:hands_app/features/dashboard/widgets/manager_dashboard_redesign.dart';
import 'package:hands_app/features/help/models/guided_tour_step.dart';
import 'package:hands_app/features/help/models/help_topic.dart';
import 'package:hands_app/features/help/widgets/guided_tour_host.dart';
import 'package:hands_app/features/help/widgets/inline_start_here_card.dart';
import 'package:hands_app/features/crm/widgets/crm_scoped_bottom_nav.dart';
import 'package:hands_app/l10n/l10n.dart';
import 'package:hands_app/utils/localized_content.dart';

class ManagerDashboardPage extends StatefulWidget {
  final String organizationId;
  final bool allowPlatformAccess;

  const ManagerDashboardPage({
    super.key,
    required this.organizationId,
    this.allowPlatformAccess = false,
  });

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
  double _setupCompletionProgress = 0;

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
  List<MissedTasksSection> _yesterdayMissedSections =
      []; // Add raw sections for accurate counting
  bool _loadingYesterday = true;

  // Live shifts
  List<Map<String, dynamic>> _liveShifts = [];
  bool _loadingLive = true;
  Timer? _refreshTimer;

  // Historic insights
  List<Map<String, dynamic>> _frequentMisses30d = [];
  List<Map<String, dynamic>> _poorShifts30d = [];

  // History filters
  DateTimeRange? _selectedDateRange;

  List<Map<String, String>> _shifts = [];
  List<Map<String, String>> _checklists = [];

  final GlobalKey _tourHeroKey = GlobalKey();
  final GlobalKey _tourIssuesKey = GlobalKey();
  final GlobalKey _tourShiftReadinessKey = GlobalKey();

  @override
  void initState() {
    // WEB variant initialization instrumentation
    debugPrint('[WEBManagerDashboard] initState CALLED');
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _todayKey = _dateFormat.format(DateTime.now());
    _selectedLocationId =
        LocationSelectionService.instance.currentLocationId ??
        _selectedLocationId;
    LocationSelectionService.instance.listenable.addListener(
      _onGlobalLocationChanged,
    );
    _initializeDashboard();
  }

  // Handle app lifecycle changes to refresh data when user returns
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      // User returned to app - refresh missed tasks data
      _loadYesterdayMissed().catchError((e) {
        debugPrint(
          '[ManagerDashboard] Error refreshing data on app resume: $e',
        );
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
        _selectedLocationName =
            match['name'] as String? ?? _selectedLocationName;
      });
      unawaited(_loadCriticalData());
    }
  }

  // Progressive loading strategy for better performance
  Future<void> _initializeDashboard() async {
    // Phase 1: Essential setup (5s timeout)
    try {
      await Future.wait([
        _fetchUserRole(),
        _checkSetupStatus(),
        _loadLocations(),
      ]).timeout(const Duration(seconds: 5));

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
    try {
      await Future.wait([
        _loadLiveShifts(),
        _loadYesterdayMissed(),
      ]).timeout(const Duration(seconds: 8));

      // Start background loading of less critical data
      _loadBackgroundData();
    } catch (e) {
      // Continue with background loading even if critical data fails
      _loadBackgroundData();
    }
  }

  // Load trend data and analytics in the background
  void _loadBackgroundData() {
    // Use individual timeouts for each background operation
    _loadFrequentMisses30d()
        .timeout(const Duration(seconds: 15))
        .catchError((_) {});
    _loadPoorShifts30d()
        .timeout(const Duration(seconds: 15))
        .catchError((_) {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    LocationSelectionService.instance.listenable.removeListener(
      _onGlobalLocationChanged,
    );
    super.dispose();
  }

  // ===== Data Loading =====

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingUserRole = false);
      return;
    }
    final userDoc =
        await FirestoreEnforcer.instance
            .collection('users')
            .doc(user.uid)
            .get();
    if (!mounted) return;
    setState(() {
      userRole =
          userDoc.data()?['userRole'] ?? 2; // Temporarily default to admin role
      _isLoadingUserRole = false;
    });
  }

  Future<void> _checkSetupStatus() async {
    setState(() => _isLoadingSetupStatus = true);
    try {
      final setupStatus = await _setupService.getSetupStatus(
        widget.organizationId,
      );
      final isEnabled = setupStatus['metricsEnabled'] as bool? ?? false;
      if (!mounted) return;
      setState(() {
        _metricsEnabled = isEnabled;
        _isLoadingSetupStatus = false;
        _setupCompletionProgress =
            (setupStatus['setupCompletionPercentage'] as num?)?.toDouble() ?? 0;
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
        _setupCompletionProgress = 0;
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

      final hasGlobalValid =
          globalId != null && locations.any((l) => l['id'] == globalId);
      final currentIsValid =
          _selectedLocationId != null &&
          locations.any((l) => l['id'] == _selectedLocationId);

      if (hasGlobalValid) {
        locationToSelect = globalId;
        locationToSelectName =
            locations.firstWhere((l) => l['id'] == globalId)['name'] as String?;
      } else if (currentIsValid) {
        locationToSelect = _selectedLocationId;
        locationToSelectName =
            locations.firstWhere((l) => l['id'] == _selectedLocationId)['name']
                as String?;
      } else if (locations.isNotEmpty) {
        final primary = locations.firstWhere(
          (l) => l['isPrimary'] == true,
          orElse: () => locations.first,
        );
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
      if (_selectedLocationId != null &&
          LocationSelectionService.instance.currentLocationId !=
              _selectedLocationId) {
        try {
          await LocationSelectionService.instance.setLocationAsync(
            _selectedLocationId!,
            locationName: _selectedLocationName,
          );
        } catch (_) {}
      }

      if (_selectedLocationId != null) {
        await _loadFilterOptions();
        await _loadAll();
      }
    } catch (e) {
      logger.e('Error loading locations: $e', e);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load locations: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocations = false);
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    // Shifts (for filters)
    final shiftsColl = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('shifts');

    final Map<String, QueryDocumentSnapshot> shiftDocsById = {};
    if (_selectedLocationId == null || _selectedLocationId!.isEmpty) {
      final snap = await shiftsColl.get();
      for (final d in snap.docs) {
        shiftDocsById[d.id] = d;
      }
    } else {
      final snapArray =
          await shiftsColl
              .where('locationIds', arrayContains: _selectedLocationId)
              .get();
      for (final d in snapArray.docs) {
        shiftDocsById[d.id] = d;
      }
      try {
        final snapSingle =
            await shiftsColl
                .where('locationId', isEqualTo: _selectedLocationId)
                .get();
        for (final d in snapSingle.docs) {
          shiftDocsById[d.id] = d;
        }
      } catch (_) {}
    }
    final shiftDocs = shiftDocsById.values.toList();

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
          shiftDocs.map((d) {
            final data =
                (d.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
            return {
              'id': d.id,
              'name': (data['shiftName'] ?? 'Unnamed Shift').toString(),
            };
          }).toList();
      _checklists =
          templatesSnap.docs
              .map(
                (d) => {
                  'id': d.id,
                  'name': (d.data()['name'] ?? 'Unnamed Checklist').toString(),
                },
              )
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
      // IMPORTANT: compute "missed yesterday" directly from yesterday's tasks,
      // not from today's carry-forward lineage (which can be historically incorrect).
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      logger.d(
        '[WEBManagerDashboard] _loadYesterdayMissed direct: yesterday=${_dateFormat.format(yesterday)} location=$_selectedLocationId',
      );

      final sections = await _loadMissedSectionsForDateDirect(yesterday);
      final groupedTasks = <String, Map<String, dynamic>>{};
      for (final section in sections) {
        for (final task in section.tasks) {
          final key = '${task.taskName}_${section.shiftId}';
          final group = groupedTasks.putIfAbsent(
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
          group['count'] = (group['count'] as int) + 1;
        }
      }

      _yesterdayMissedSections = sections;
      _yesterdayMissed = groupedTasks.values.toList();
      logger.d(
        '[WEBManagerDashboard] _loadYesterdayMissed: sections=${sections.length} tasks=${sections.fold<int>(0, (s, sec) => s + sec.tasks.length)} grouped=${_yesterdayMissed.length}',
      );
    } catch (e, st) {
      logger.e('[ManagerDashboard] loadMissedTasksForToday error: $e\n$st');
    } finally {
      if (!mounted) return;
      setState(() => _loadingYesterday = false);
    }
  }

  // _missedSignature removed after simplifying logic to CF-only (no merging step required).

  bool _taskIsCompleted(Map<String, dynamic> m) {
    return (m['completed'] == true) ||
        (m['isCompleted'] == true) ||
        (m['status'] == 'completed');
  }

  DateTime _parseDateTime(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  TaskData _taskDataFromDoc({
    required String docId,
    required Map<String, dynamic> m,
  }) {
    final createdAt = _parseDateTime(m['createdAt']);
    final dueDateRaw = m['dueDate'] ?? m['dueAt'] ?? m['deadline'];
    final dueDate = dueDateRaw != null ? _parseDateTime(dueDateRaw) : createdAt;

    final taskId = (m['taskId'] ?? m['id'] ?? docId).toString();
    final taskName =
        localizedContent(
          m,
          fieldKeys: const ['taskName', 'name', 'title', 'description'],
        ).trim();
    final checklistName =
        localizedContent(
          m,
          fieldKeys: const ['checklistName', 'templateName', 'name'],
        ).trim();

    return TaskData(
      taskId: taskId,
      taskName: taskName.isNotEmpty ? taskName : 'Unknown Task',
      createdAt: createdAt,
      dueDate: dueDate,
      completed: _taskIsCompleted(m),
      isCarryForward: (m['isCarryForward'] == true),
      excludedFromMetrics: (m['excludedFromMetrics'] == true),
      organizationId: (m['organizationId'] ?? widget.organizationId).toString(),
      locationId: (m['locationId'] ?? _selectedLocationId)?.toString(),
      checklistId: (m['checklistId'] ?? m['dailyChecklistId'])?.toString(),
      checklistName: checklistName.isNotEmpty ? checklistName : null,
      shiftId: (m['shiftId'])?.toString(),
      dateString: (m['dateString'])?.toString(),
      order: (m['order'] is num) ? (m['order'] as num).toInt() : null,
    );
  }

  Future<List<MissedTasksSection>> _loadMissedSectionsForDateDirect(
    DateTime date,
  ) async {
    final dateStr = _dateFormat.format(date);

    final shiftsSnap =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('shifts')
            .get();
    final shiftMetaById = <String, Map<String, dynamic>>{
      for (final s in shiftsSnap.docs) s.id: s.data(),
    };

    final tasksByShiftId = <String, List<TaskData>>{};

    Query q = FirestoreEnforcer.instance
        .collectionGroup('tasks')
        .where('organizationId', isEqualTo: widget.organizationId)
        .where('isCarryForward', isEqualTo: false)
        .where('dateString', isEqualTo: dateStr);
    if (_selectedLocationId != null && _selectedLocationId!.isNotEmpty) {
      q = q.where('locationId', isEqualTo: _selectedLocationId);
    }

    final snap = await q.get();
    for (final d in snap.docs) {
      final raw = d.data();
      final m = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
      if (m['excludedFromMetrics'] == true) continue;
      if (m['isCarryForward'] == true) continue;
      if (_taskIsCompleted(m)) continue;
      final shiftId = (m['shiftId'] ?? '').toString();
      if (shiftId.isEmpty) continue;
      final task = _taskDataFromDoc(docId: d.id, m: m);
      if (task.taskName.trim().isEmpty) continue;
      tasksByShiftId.putIfAbsent(shiftId, () => <TaskData>[]).add(task);
    }

    final sections = <MissedTasksSection>[];
    for (final entry in tasksByShiftId.entries) {
      final shiftId = entry.key;
      final shiftMeta = shiftMetaById[shiftId] ?? const <String, dynamic>{};
      final shiftName =
          (shiftMeta['shiftName'] ?? shiftMeta['name'] ?? '').toString();
      if (shiftName.isEmpty) continue;
      sections.add(
        MissedTasksSection(
          shiftId: shiftId,
          shiftName: shiftName,
          organizationId: widget.organizationId,
          locationId: _selectedLocationId,
          tasks: entry.value,
        ),
      );
    }

    sections.sort((a, b) => a.shiftName.compareTo(b.shiftName));
    return sections;
  }

  Future<void> _loadLiveShifts() async {
    setState(() => _loadingLive = true);
    try {
      logger.i('[ManagerDashboard][DEBUG] Entering _loadLiveShifts');
      // Add console print for browser debugging visibility
      print('====== MANAGER DASHBOARD: Loading live shifts ======');
      print('Current location ID: $_selectedLocationId');

      if (_selectedLocationId == null || _selectedLocationId!.isEmpty) {
        logger.w(
          '[ManagerDashboard][DEBUG] _loadLiveShifts aborted: no location selected',
        );
        if (!mounted) return;
        setState(() {
          _liveShifts = [];
        });
        return;
      }

      final todayStr = _todayKey;
      logger.i(
        '[ManagerDashboard][DEBUG] Today string: $todayStr, Selected Location: $_selectedLocationId',
      );
      final shiftsColl = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('shifts');
      final Map<String, QueryDocumentSnapshot> docsById = {};
      final snapArray =
          await shiftsColl
              .where('locationIds', arrayContains: _selectedLocationId)
              .get();
      for (final d in snapArray.docs) {
        docsById[d.id] = d;
      }
      int legacyCount = 0;
      try {
        // Some older shift docs store a single locationId instead of locationIds[]. Merge + dedupe.
        final snapSingle =
            await shiftsColl
                .where('locationId', isEqualTo: _selectedLocationId)
                .get();
        legacyCount = snapSingle.docs.length;
        for (final d in snapSingle.docs) {
          docsById[d.id] = d;
        }
      } catch (e) {
        logger.w(
          '[ManagerDashboard][DEBUG] Legacy shift query (locationId) failed: $e',
        );
      }

      final shiftDocs = docsById.values.toList();
      logger.i(
        '[ManagerDashboard][DEBUG] Found ${shiftDocs.length} shifts for location (locationIds=${snapArray.docs.length}, locationId=$legacyCount)',
      );

      final List<Map<String, dynamic>> todaysShifts = [];

      for (final shiftDoc in shiftDocs) {
        final shiftData =
            (shiftDoc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
        final shiftName =
            (shiftData['shiftName'] ?? 'Unnamed Shift').toString();
        final startTime = (shiftData['startTime'] ?? '').toString();
        final endTime = (shiftData['endTime'] ?? '').toString();
        final role =
            (shiftData['jobType'] ?? shiftData['role'] ?? '').toString();
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
              checklistsSnap =
                  legacySnap; // replace local variable with fallback
            }
          } catch (e) {
            logger.w(
              '[ManagerDashboard][DEBUG] Org-scoped fallback failed for shift $shiftName: $e',
            );
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
              logger.e(
                '[ManagerDashboard][DEBUG] Failed to load tasks subcollection for doc ${cl.id}: $e',
              );
            }
          }

          // Filter out carry-forward tasks to avoid contaminating today's shift completion rates
          final todayOnlyTasks =
              tasks.where((t) => t['isCarryForward'] != true).toList();
          totalTasks += todayOnlyTasks.length;
          for (final t in todayOnlyTasks) {
            final completed =
                t['completed'] == true ||
                t['isCompleted'] == true ||
                t['status'] == 'completed';
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

        logger.i(
          '[ManagerDashboard][DEBUG] Checking schedule for shift $shiftName on weekday $weekday',
        );

        // repeatsDaily flag (may be stored as bool)
        if (shiftData['repeatsDaily'] == true) {
          logger.i(
            '[ManagerDashboard][DEBUG] Shift $shiftName has repeatsDaily=true',
          );
          scheduledToday = true;
        }

        // activeDays can be List<int> or List<String>
        if (!scheduledToday && (shiftData['activeDays'] is List)) {
          final active =
              (shiftData['activeDays'] as List)
                  .map((e) => e?.toString())
                  .whereType<String>()
                  .toList();
          logger.i(
            '[ManagerDashboard][DEBUG] Shift $shiftName activeDays: $active, checking against weekday $weekday',
          );
          for (final a in active) {
            final ai = int.tryParse(a);
            if (ai != null && ai == weekday) {
              logger.i(
                '[ManagerDashboard][DEBUG] Shift $shiftName matches activeDays: $ai == $weekday',
              );
              scheduledToday = true;
              break;
            }
          }
        }

        // days may contain names like 'Monday' etc.
        if (!scheduledToday && (shiftData['days'] is List)) {
          final todayName =
              [
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday',
                'Saturday',
                'Sunday',
              ][weekday - 1];
          final daysList =
              (shiftData['days'] as List)
                  .map((d) => d?.toString().toLowerCase())
                  .whereType<String>()
                  .toList();
          logger.i(
            '[ManagerDashboard][DEBUG] Shift $shiftName days: $daysList, checking against $todayName',
          );
          if (daysList.contains(todayName.toLowerCase())) {
            logger.i(
              '[ManagerDashboard][DEBUG] Shift $shiftName matches days: contains ${todayName.toLowerCase()}',
            );
            scheduledToday = true;
          }
        }

        // Some shifts may have a specific shiftDate field (Timestamp/DateTime)
        if (!scheduledToday &&
            shiftData.containsKey('shiftDate') &&
            shiftData['shiftDate'] != null) {
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
              if (sd.year == now.year &&
                  sd.month == now.month &&
                  sd.day == now.day) {
                logger.i(
                  '[ManagerDashboard][DEBUG] Shift $shiftName matches shiftDate: $sd',
                );
                scheduledToday = true;
              }
            }
          } catch (_) {}
        }

        final hasAnyScheduleMetadata =
            shiftData['repeatsDaily'] == true ||
            (shiftData['activeDays'] is List &&
                (shiftData['activeDays'] as List).isNotEmpty) ||
            (shiftData['days'] is List &&
                (shiftData['days'] as List).isNotEmpty) ||
            (shiftData.containsKey('shiftDate') &&
                shiftData['shiftDate'] != null);

        // If scheduling metadata is missing (common in older orgs), default to showing the shift
        // rather than hiding it, to avoid false negatives.
        if (!scheduledToday && !hasAnyScheduleMetadata) {
          logger.i(
            '[ManagerDashboard][DEBUG] Shift $shiftName has no schedule metadata; defaulting scheduledToday=true',
          );
          scheduledToday = true;
        }

        logger.i(
          '[ManagerDashboard][DEBUG] Final scheduledToday for shift $shiftName: $scheduledToday',
        );

        // If not scheduled today, skip showing this shift in the Today's Shifts list
        if (!scheduledToday) {
          logger.i(
            '[ManagerDashboard][DEBUG] Skipping shift $shiftName — not scheduled today (weekday=$weekday)',
          );
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

      logger.i(
        '[ManagerDashboard][DEBUG] Final live shifts list: $todaysShifts',
      );
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
    try {
      debugPrint(
        '[ManagerDashboard] _loadFrequentMisses30d: calling with locationId="$_selectedLocationId" (isNull=${_selectedLocationId == null}, isEmpty=${_selectedLocationId?.isEmpty})',
      );
      final service = DailyChecklistService();
      final list = await service.getFrequentlyMissedTasks(
        organizationId: widget.organizationId,
        days: 30,
        limit: 10,
        locationId:
            _selectedLocationId?.isNotEmpty == true
                ? _selectedLocationId
                : null,
      );
      debugPrint(
        '[ManagerDashboard] _loadFrequentMisses30d: received ${list.length} items',
      );
      if (!mounted) return;
      setState(() => _frequentMisses30d = list);
    } catch (e, st) {
      logger.e('[ManagerDashboard] getFrequentlyMissedTasks error: $e', e, st);
    }
  }

  Future<void> _loadPoorShifts30d() async {
    logger.i(
      '[ManagerDashboard][DEBUG] ALWAYSLOG: Entering _loadPoorShifts30d',
    );
    try {
      logger.i(
        '[ManagerDashboard][DEBUG] ===== POOR SHIFTS ANALYSIS STARTING =====',
      );
      logger.i(
        '[ManagerDashboard][DEBUG] _selectedLocationId: $_selectedLocationId',
      );
      logger.i(
        '[ManagerDashboard][DEBUG] organizationId: ${widget.organizationId}',
      );
      logger.i(
        '[ManagerDashboard][DEBUG] Loading poor performing shifts data...',
      );
      final now = DateTime.now();
      final start = _dateFormat.format(now.subtract(const Duration(days: 30)));
      final end = _dateFormat.format(now);

      logger.i(
        '[ManagerDashboard][DEBUG] Querying poor shifts from $start to $end for location: $_selectedLocationId',
      );

      // Fast path: aggregate directly from tasks subcollections (collectionGroup), excluding carry-forward tasks.
      // This avoids N subcollection reads and dramatically reduces load time.
      final Map<String, Map<String, int>> aggByShiftId =
          {}; // shiftId -> {'done':x,'total':y}
      bool usedFastPath = false;
      try {
        Query q = FirestoreEnforcer.instance
            .collectionGroup('tasks')
            .where('organizationId', isEqualTo: widget.organizationId)
            .where('isCarryForward', isEqualTo: false)
            .where('dateString', isGreaterThanOrEqualTo: start)
            .where('dateString', isLessThanOrEqualTo: end);
        if (_selectedLocationId != null && _selectedLocationId!.isNotEmpty) {
          q = q.where('locationId', isEqualTo: _selectedLocationId);
        }
        final snap = await q.get();
        usedFastPath = true;
        logger.i(
          '[ManagerDashboard][DEBUG] Poor shifts fast-path task docs=${snap.docs.length}',
        );
        for (final d in snap.docs) {
          final raw = d.data();
          final m = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
          if (m['excludedFromMetrics'] == true) continue;
          final shiftId = (m['shiftId'] ?? '').toString();
          if (shiftId.isEmpty) continue;
          final completed =
              (m['completed'] == true) ||
              (m['isCompleted'] == true) ||
              (m['status'] == 'completed');
          final entry = aggByShiftId.putIfAbsent(
            shiftId,
            () => {'done': 0, 'total': 0},
          );
          entry['total'] = (entry['total'] ?? 0) + 1;
          if (completed) entry['done'] = (entry['done'] ?? 0) + 1;
        }
      } catch (e) {
        // Common failure: missing composite index for the range query.
        logger.w(
          '[ManagerDashboard][DEBUG] Poor shifts fast-path failed; falling back. error=$e',
        );
      }

      if (!usedFastPath) {
        // Fallback: read daily_checklists and, per checklist, count regular tasks only.
        // Still excludes carry-forward tasks and runs in controlled parallel batches.
        final preferredLocation = _selectedLocationId;

        Future<List<QueryDocumentSnapshot>> queryForLocation(
          String locId,
        ) async {
          try {
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
            return s.docs;
          } catch (_) {
            final s =
                await FirestoreEnforcer.instance
                    .collection('organizations')
                    .doc(widget.organizationId)
                    .collection('daily_checklists')
                    .where('date', isGreaterThanOrEqualTo: start)
                    .where('date', isLessThanOrEqualTo: end)
                    .where('locationId', isEqualTo: locId)
                    .get();
            return s.docs;
          }
        }

        final List<QueryDocumentSnapshot> docs = [];
        if (preferredLocation != null && preferredLocation.isNotEmpty) {
          docs.addAll(await queryForLocation(preferredLocation));
        } else {
          // No selected location: allow org-wide fallback.
          final s =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(widget.organizationId)
                  .collection('daily_checklists')
                  .where('date', isGreaterThanOrEqualTo: start)
                  .where('date', isLessThanOrEqualTo: end)
                  .get();
          docs.addAll(s.docs);
        }

        logger.i(
          '[ManagerDashboard][DEBUG] Poor shifts fallback daily_checklists=${docs.length}',
        );

        Future<void> processChecklist(QueryDocumentSnapshot d) async {
          final dataRaw = d.data();
          final data =
              (dataRaw is Map<String, dynamic>) ? dataRaw : <String, dynamic>{};
          final shiftId = (data['shiftId'] ?? '').toString();
          if (shiftId.isEmpty) return;

          // If parent counters exist, prefer them (fast).
          final completedItems = data['completedItems'];
          final totalItems = data['totalItems'];
          if (completedItems is num && totalItems is num) {
            final entry = aggByShiftId.putIfAbsent(
              shiftId,
              () => {'done': 0, 'total': 0},
            );
            entry['done'] = (entry['done'] ?? 0) + completedItems.toInt();
            entry['total'] = (entry['total'] ?? 0) + totalItems.toInt();
            return;
          }

          // Otherwise, count from tasks but exclude carry-forward tasks.
          try {
            int total = 0;
            int done = 0;

            if (data.containsKey('tasks') && data['tasks'] != null) {
              // Old schema: tasks embedded in daily_checklist doc.
              final tasks = List<Map<String, dynamic>>.from(
                data['tasks'] ?? const [],
              );
              for (final t in tasks) {
                if (t['isCarryForward'] == true) continue;
                if (t['excludedFromMetrics'] == true) continue;
                total += 1;
                if (t['completed'] == true ||
                    t['isCompleted'] == true ||
                    t['status'] == 'completed') {
                  done += 1;
                }
              }
            } else {
              // New schema: tasks subcollection.
              final tasksSnap =
                  await d.reference
                      .collection('tasks')
                      .where('isCarryForward', isEqualTo: false)
                      .get();
              for (final td in tasksSnap.docs) {
                final t = td.data();
                if (t['excludedFromMetrics'] == true) continue;
                total += 1;
                if (t['completed'] == true ||
                    t['isCompleted'] == true ||
                    t['status'] == 'completed') {
                  done += 1;
                }
              }
            }

            final entry = aggByShiftId.putIfAbsent(
              shiftId,
              () => {'done': 0, 'total': 0},
            );
            entry['done'] = (entry['done'] ?? 0) + done;
            entry['total'] = (entry['total'] ?? 0) + total;
          } catch (e) {
            logger.w(
              '[ManagerDashboard][DEBUG] Poor shifts fallback task enumeration failed for ${d.id}: $e',
            );
          }
        }

        const batchSize = 15;
        for (int i = 0; i < docs.length; i += batchSize) {
          final chunk = docs.sublist(i, math.min(i + batchSize, docs.length));
          await Future.wait(chunk.map(processChecklist));
        }
      }

      // Resolve shift names in one read.
      final shiftsSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('shifts')
              .get();
      final Map<String, String> shiftNameById = {
        for (final s in shiftsSnap.docs)
          s.id: ((s.data()['shiftName'] ?? s.data()['name'] ?? '').toString()),
      };

      final list =
          aggByShiftId.entries
              .map((e) {
                final done = (e.value['done'] ?? 0).toInt();
                final total = math.max((e.value['total'] ?? 0).toInt(), 1);
                final pct = done / total;
                final shiftName = shiftNameById[e.key] ?? '';
                return {
                  'shiftId': e.key,
                  'shiftName': shiftName,
                  'avgCompletion': pct,
                  'done': done,
                  'total': total,
                };
              })
              .where(
                (m) =>
                    (m['total'] as int) > 0 &&
                    (m['shiftName'] as String).isNotEmpty,
              )
              .toList()
            ..sort(
              (a, b) => (a['avgCompletion'] as double).compareTo(
                b['avgCompletion'] as double,
              ),
            );

      logger.i(
        '[ManagerDashboard][DEBUG] Poor performing shifts analysis complete: ${list.length} shifts found',
      );
      for (final shift in list) {
        final pct = ((shift['avgCompletion'] as double) * 100).toStringAsFixed(
          1,
        );
        logger.i(
          '[ManagerDashboard][DEBUG] - ${shift['shiftName']}: $pct% completion (${shift['done']}/${shift['total']})',
        );
      }

      // Show shifts with completion rate below 85% as "poor performing"
      final poorShifts =
          list
              .where((shift) => (shift['avgCompletion'] as double) < 0.85)
              .toList();
      logger.i(
        '[ManagerDashboard][DEBUG] Found ${poorShifts.length} shifts with completion < 85%',
      );

      logger.i('[ManagerDashboard][DEBUG] Final poorShifts30d: $poorShifts');
      if (!mounted) return;
      setState(() => _poorShifts30d = poorShifts.take(5).toList());
    } catch (e, st) {
      logger.e(
        '[ManagerDashboard][DEBUG] _loadPoorShifts30d failed: $e',
        e,
        st,
      );
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!mounted || _selectedLocationId == null) return;
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

  Future<void> _openSetupPanel() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CondensedSetupWidget(
              organizationId: widget.organizationId,
              onMetricsEnabled: () {
                Navigator.of(context).pop();
                _onMetricsEnabled();
              },
            ),
      ),
    );
  }

  int get _yesterdayMissedCount =>
      _yesterdayMissedSections.isNotEmpty
          ? _yesterdayMissedSections.fold<int>(
            0,
            (sum, section) => sum + section.tasks.length,
          )
          : _yesterdayMissed.fold<int>(
            0,
            (sum, item) => sum + ((item['count'] as int?) ?? 1),
          );

  int get _yesterdayAffectedShiftCount =>
      _yesterdayMissedSections.isNotEmpty
          ? _yesterdayMissedSections.length
          : _yesterdayMissed
              .map((item) => item['shiftId'] ?? item['shiftName'] ?? '')
              .toSet()
              .length;

  bool _isShiftLiveNow(Map<String, dynamic> shift) =>
      shift['timeStatus'].toString().contains('remaining');

  bool _isShiftFinished(Map<String, dynamic> shift) =>
      shift['timeStatus'].toString().contains('Finished');

  bool _isShiftUpcoming(Map<String, dynamic> shift) =>
      shift['timeStatus'].toString().contains('Starts in');

  int _openTasksForShift(Map<String, dynamic> shift) {
    final total = (shift['totalTasks'] as int?) ?? 0;
    final completed = (shift['completedTasks'] as int?) ?? 0;
    return math.max(0, total - completed);
  }

  bool _isShiftAtRisk(Map<String, dynamic> shift) {
    final readiness = ((shift['completionPct'] as num?)?.toDouble() ?? 0).clamp(
      0.0,
      1.0,
    );
    final openTasks = _openTasksForShift(shift);
    if (_isShiftFinished(shift)) {
      return openTasks > 0;
    }
    if (_isShiftLiveNow(shift)) {
      return openTasks > 0 && readiness < 0.8;
    }
    return false;
  }

  DashboardTone _toneForShift(Map<String, dynamic> shift) {
    if (_isShiftAtRisk(shift)) return DashboardTone.danger;
    if (_isShiftFinished(shift) && _openTasksForShift(shift) == 0) {
      return DashboardTone.success;
    }
    if (_isShiftUpcoming(shift) &&
        ((shift['completedTasks'] as int?) ?? 0) == 0) {
      return DashboardTone.neutral;
    }
    if (((shift['completionPct'] as num?)?.toDouble() ?? 0) >= 0.85) {
      return DashboardTone.success;
    }
    return DashboardTone.warning;
  }

  String _statusForShift(Map<String, dynamic> shift) {
    final openTasks = _openTasksForShift(shift);
    final completed = (shift['completedTasks'] as int?) ?? 0;
    if (_isShiftFinished(shift)) {
      return openTasks == 0 ? 'Complete' : 'At Risk';
    }
    if (_isShiftLiveNow(shift)) {
      return _isShiftAtRisk(shift)
          ? 'At Risk'
          : (completed == 0 ? 'Not Started' : 'In Progress');
    }
    if (_isShiftUpcoming(shift)) {
      return completed == 0 ? 'Not Started' : 'In Progress';
    }
    return completed == 0 ? 'Not Started' : 'In Progress';
  }

  String _detailForShift(Map<String, dynamic> shift) {
    final openTasks = _openTasksForShift(shift);
    if (openTasks == 0 && _isShiftFinished(shift)) {
      return 'All tasks completed';
    }
    if (_isShiftAtRisk(shift)) {
      return '$openTasks tasks still need attention';
    }
    if (_isShiftUpcoming(shift)) {
      return 'Ready for today\'s run';
    }
    return '$openTasks tasks still open';
  }

  int get _activeOpenTaskCount => _liveShifts
      .where(_isShiftLiveNow)
      .fold<int>(0, (sum, shift) => sum + _openTasksForShift(shift));

  int get _riskShiftCount => _liveShifts.where(_isShiftAtRisk).length;

  List<ManagerActionIssue> get _attentionIssues {
    if (_loadingLive || _loadingYesterday) {
      return [
        ManagerActionIssue(
          title: 'Loading live operational status',
          detail:
              'Pulling today\'s shifts and yesterday\'s unfinished work now.',
          ctaLabel: 'Refresh now',
          tone: DashboardTone.neutral,
          onTap: _refreshAllData,
        ),
      ];
    }

    final issues = <ManagerActionIssue>[];

    if (_yesterdayMissedCount > 0) {
      issues.add(
        ManagerActionIssue(
          title: 'Yesterday left unfinished work',
          detail:
              '$_yesterdayMissedCount tasks were missed across $_yesterdayAffectedShiftCount shifts.',
          ctaLabel: 'Review missed work',
          tone: DashboardTone.warning,
          onTap: _openAllMissedYesterday,
        ),
      );
    }

    for (final shift in _liveShifts.where(_isShiftAtRisk).take(4)) {
      final shiftName = (shift['shiftName'] ?? 'Unnamed Shift').toString();
      final openTasks = _openTasksForShift(shift);
      issues.add(
        ManagerActionIssue(
          title: '$shiftName is at risk',
          detail:
              '$openTasks tasks are still open. ${shift['timeStatus'] ?? 'Check progress now.'}',
          ctaLabel: 'Open shift',
          tone: DashboardTone.danger,
          onTap: _openTodayShifts,
        ),
      );
    }

    if (issues.isEmpty) {
      issues.add(
        ManagerActionIssue(
          title: 'Today is on track',
          detail:
              'No active shifts are currently off track at ${_selectedLocationName ?? 'this location'}.',
          ctaLabel: 'View active shifts',
          tone: DashboardTone.success,
          onTap: _openTodayShifts,
        ),
      );
    }

    return issues;
  }

  List<ShiftReadinessSummary> get _shiftReadinessSummaries {
    final sorted = [..._liveShifts];
    sorted.sort((a, b) {
      final toneRank = {
        DashboardTone.danger: 0,
        DashboardTone.warning: 1,
        DashboardTone.neutral: 2,
        DashboardTone.success: 3,
      };
      final compareTone = toneRank[_toneForShift(a)]!.compareTo(
        toneRank[_toneForShift(b)]!,
      );
      if (compareTone != 0) return compareTone;
      return ((a['completionPct'] as num?)?.toDouble() ?? 0).compareTo(
        (b['completionPct'] as num?)?.toDouble() ?? 0,
      );
    });

    return sorted
        .map(
          (shift) => ShiftReadinessSummary(
            name: (shift['shiftName'] ?? 'Unnamed Shift').toString(),
            statusLabel: _statusForShift(shift),
            detail: _detailForShift(shift),
            timeLabel: (shift['timeStatus'] ?? 'No schedule').toString(),
            tone: _toneForShift(shift),
            readiness: ((shift['completionPct'] as num?)?.toDouble() ?? 0)
                .clamp(0.0, 1.0),
            completed: (shift['completedTasks'] as int?) ?? 0,
            total: (shift['totalTasks'] as int?) ?? 0,
            attentionCount: _openTasksForShift(shift),
            onTap: _openTodayShifts,
          ),
        )
        .toList();
  }

  List<RecurringIssueSummary> get _recurringFailureItems =>
      _frequentMisses30d.take(5).map((item) {
        final failureRate = ((item['failureRate'] as num?)?.toDouble() ?? 0)
            .clamp(0.0, 1.0);
        final taskName = (item['taskName'] ?? 'Unknown Task').toString();
        final checklistName = (item['checklistName'] ?? 'Checklist').toString();
        final total = (item['totalOccurrences'] as int?) ?? 0;
        final misses = (item['count'] as int?) ?? 0;
        return RecurringIssueSummary(
          title: taskName,
          subtitle: '$checklistName • $misses of $total opportunities missed',
          metric: '${(failureRate * 100).round()}%',
          tone:
              failureRate >= 0.4 ? DashboardTone.danger : DashboardTone.warning,
          progress: failureRate,
        );
      }).toList();

  List<RecurringIssueSummary> get _atRiskShiftItems =>
      _poorShifts30d.take(5).map((item) {
        final pct =
            (((item['avgCompletion'] as num?)?.toDouble() ?? 0).clamp(
              0.0,
              1.0,
            )) *
            100;
        final done = (item['done'] as int?) ?? 0;
        final total = (item['total'] as int?) ?? 0;
        return RecurringIssueSummary(
          title: (item['shiftName'] ?? 'Unknown Shift').toString(),
          subtitle:
              '$done of $total tracked tasks completed in the last 30 days',
          metric: '${pct.round()}%',
          tone: pct < 70 ? DashboardTone.danger : DashboardTone.warning,
          progress: (pct / 100).clamp(0.0, 1.0),
        );
      }).toList();

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocations || _isLoadingUserRole || _isLoadingSetupStatus) {
      return Scaffold(
        backgroundColor: HandsColors.scaffoldBackground,
        appBar: AppBar(
          title: Text(
            'MANAGER DASHBOARD',
            style: GoogleFonts.comfortaa(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          backgroundColor: HandsColors.primaryContainer,
          foregroundColor: HandsColors.white,
        ),
        bottomNavigationBar:
            widget.allowPlatformAccess
                ? CrmScopedBottomNav(
                  orgId: widget.organizationId,
                  currentIndex: 1,
                )
                : BottomNavBar(currentIndex: 1, userRole: userRole),
        body: const Center(
          child: CircularProgressIndicator(color: HandsColors.handsOrange),
        ),
      );
    }

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
                  'CRM account dashboard',
                  style: GoogleFonts.comfortaa(fontWeight: FontWeight.w800),
                )
                : GenericAppBarContent(
                  appBarTitle: 'Manager Dashboard',
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
                  UnifiedMenuButton(
                    userRole: userRole,
                    organizationId: widget.organizationId,
                  ),
                ],
      ),
      bottomNavigationBar:
          widget.allowPlatformAccess
              ? CrmScopedBottomNav(
                orgId: widget.organizationId,
                currentIndex: 1,
              )
              : BottomNavBar(currentIndex: 1, userRole: userRole),
      body: _buildDashboardGrid(),
    );
  }

  Widget _buildDashboardGrid() {
    final l10n = context.l10n;
    final issues = _attentionIssues;
    final shiftSummaries = _shiftReadinessSummaries;
    final recurringFailures = _recurringFailureItems;
    final atRiskShifts = _atRiskShiftItems;
    final isPrimaryLoading = _loadingLive || _loadingYesterday;
    final hasActionableIssues = issues.any(
      (issue) => issue.tone != DashboardTone.success,
    );
    final activeShiftCount = _liveShifts.where(_isShiftLiveNow).length;
    final totalTrackedTasks = _liveShifts.fold<int>(
      0,
      (runningTotal, shift) =>
          runningTotal + ((shift['totalTasks'] as int?) ?? 0),
    );
    final completedTrackedTasks = _liveShifts.fold<int>(
      0,
      (runningTotal, shift) =>
          runningTotal + ((shift['completedTasks'] as int?) ?? 0),
    );
    final dashboardMetrics = <DashboardMetricSummary>[
      DashboardMetricSummary(
        icon: Icons.wifi_tethering_rounded,
        label: l10n.managerDashboardActiveShifts,
        value: '$activeShiftCount',
        detail:
            activeShiftCount == 1
                ? l10n.managerDashboardActiveShiftLiveNowOne
                : l10n.managerDashboardActiveShiftLiveNowOther(
                  activeShiftCount,
                ),
        tone:
            activeShiftCount > 0
                ? DashboardTone.neutral
                : DashboardTone.success,
        progress:
            _liveShifts.isEmpty
                ? 0
                : (activeShiftCount / _liveShifts.length).clamp(0.0, 1.0),
      ),
      DashboardMetricSummary(
        icon: Icons.warning_amber_rounded,
        label: l10n.managerDashboardAtRisk,
        value: '$_riskShiftCount',
        detail:
            _riskShiftCount == 0
                ? l10n.managerDashboardNoShiftsSlipping
                : l10n.managerDashboardNeedInterventionNow,
        tone:
            _riskShiftCount > 0 ? DashboardTone.danger : DashboardTone.success,
        progress:
            activeShiftCount == 0
                ? 0
                : (_riskShiftCount / activeShiftCount).clamp(0.0, 1.0),
      ),
      DashboardMetricSummary(
        icon: Icons.checklist_rtl_rounded,
        label: l10n.managerDashboardOpenTasks,
        value: '$_activeOpenTaskCount',
        detail:
            totalTrackedTasks == 0
                ? l10n.managerDashboardNoTrackedTasksYet
                : l10n.managerDashboardCompletedTracked(
                  completedTrackedTasks,
                  totalTrackedTasks,
                ),
        tone:
            _activeOpenTaskCount > 0
                ? DashboardTone.warning
                : DashboardTone.success,
        progress:
            totalTrackedTasks == 0
                ? 0
                : (completedTrackedTasks / totalTrackedTasks).clamp(0.0, 1.0),
      ),
      DashboardMetricSummary(
        icon: Icons.history_toggle_off_rounded,
        label: l10n.managerDashboardCarryover,
        value: '$_yesterdayMissedCount',
        detail:
            _yesterdayMissedCount == 0
                ? l10n.managerDashboardYesterdayFinishedCleanly
                : l10n.managerDashboardShiftsAffected(
                  _yesterdayAffectedShiftCount,
                ),
        tone:
            _yesterdayMissedCount > 0
                ? DashboardTone.warning
                : DashboardTone.success,
        progress: (_yesterdayMissedCount / 12).clamp(0.0, 1.0),
      ),
    ];

    final managerTourSteps = <GuidedTourStep>[
      GuidedTourStep(
        targetKey: _tourHeroKey,
        title: l10n.managerDashboardTourSummaryTitle,
        description: l10n.managerDashboardTourSummaryDescription,
        topicId: 'manager-dashboard',
      ),
      GuidedTourStep(
        targetKey: _tourIssuesKey,
        title: l10n.managerDashboardTourIssuesTitle,
        description: l10n.managerDashboardTourIssuesDescription,
        topicId: 'manager-at-risk',
        scrollAlignment: 0.08,
      ),
      GuidedTourStep(
        targetKey: _tourShiftReadinessKey,
        title: l10n.managerDashboardTourReadinessTitle,
        description: l10n.managerDashboardTourReadinessDescription,
        topicId: 'manager-shift-readiness',
        scrollAlignment: 0.08,
      ),
    ];

    return GuidedTourHost(
      storageKey: 'manager-dashboard-tour-v1',
      enabled:
          !widget.allowPlatformAccess &&
          !_isLoadingUserRole &&
          !_isLoadingLocations &&
          !isPrimaryLoading,
      steps: managerTourSteps,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.allowPlatformAccess) ...[
              _buildCrmDashboardBanner(),
              const SizedBox(height: 14),
            ],
            if (!_metricsEnabled) ...[
              DashboardSetupBanner(
                completion: _setupCompletionProgress,
                onTap: _openSetupPanel,
              ),
              const SizedBox(height: 14),
            ],
            const InlineStartHereCard(
              role: HelpRole.manager,
              storageKey: 'manager-dashboard',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1180;
                final issueColumns = constraints.maxWidth > 1440 ? 2 : 1;

                final issueBoard = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashboardSectionLabel(
                      title: l10n.managerDashboardTodayAtRisk,
                      subtitle: l10n.managerDashboardTodayAtRiskSubtitle,
                      helpTopicIds: ['manager-at-risk', 'manager-dashboard'],
                    ),
                    const SizedBox(height: 8),
                    if (issueColumns == 1)
                      Column(
                        children:
                            issues
                                .map(
                                  (issue) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: DashboardIssueTile(issue: issue),
                                  ),
                                )
                                .toList(),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            issues
                                .map(
                                  (issue) => SizedBox(
                                    width: ((constraints.maxWidth * 0.32) - 5)
                                        .clamp(220.0, 360.0),
                                    child: DashboardIssueTile(issue: issue),
                                  ),
                                )
                                .toList(),
                      ),
                  ],
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardHeroCard(
                        key: _tourHeroKey,
                        eyebrow:
                            _selectedLocationName ??
                            l10n.managerDashboardCurrentLocation,
                        headline:
                            isPrimaryLoading
                                ? l10n.managerDashboardLoading
                                : (hasActionableIssues
                                    ? l10n.managerDashboardIssuesNeedAttention(
                                      issues.length,
                                    )
                                    : l10n.managerDashboardTodayOnTrack),
                        summary:
                            isPrimaryLoading
                                ? l10n.managerDashboardLoadingSummary(
                                  _selectedLocationName ??
                                      l10n.managerDashboardThisLocation,
                                )
                                : hasActionableIssues
                                ? l10n.managerDashboardIssuesSummary(
                                  _riskShiftCount,
                                  _activeOpenTaskCount,
                                )
                                : l10n.managerDashboardNoLiveShiftsSummary,
                        metrics: dashboardMetrics,
                        primaryLabel:
                            isPrimaryLoading
                                ? l10n.managerDashboardRefreshNow
                                : (hasActionableIssues
                                    ? l10n.managerDashboardReviewIssues
                                    : l10n.managerDashboardViewShiftReadiness),
                        onPrimaryTap:
                            isPrimaryLoading
                                ? _refreshAllData
                                : (hasActionableIssues
                                    ? issues.first.onTap
                                    : _openTodayShifts),
                        secondaryLabel: l10n.managerDashboardHistoryReports,
                        onSecondaryTap: _openTaskHistorySheet,
                      ),
                      const SizedBox(height: 14),
                      Container(key: _tourIssuesKey, child: issueBoard),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: DashboardHeroCard(
                        key: _tourHeroKey,
                        eyebrow:
                            _selectedLocationName ??
                            l10n.managerDashboardCurrentLocation,
                        headline:
                            isPrimaryLoading
                                ? l10n.managerDashboardLoading
                                : (hasActionableIssues
                                    ? l10n.managerDashboardIssuesNeedAttention(
                                      issues.length,
                                    )
                                    : l10n.managerDashboardTodayOnTrack),
                        summary:
                            isPrimaryLoading
                                ? l10n.managerDashboardLoadingSummary(
                                  _selectedLocationName ??
                                      l10n.managerDashboardThisLocation,
                                )
                                : hasActionableIssues
                                ? l10n.managerDashboardIssuesSummary(
                                  _riskShiftCount,
                                  _activeOpenTaskCount,
                                )
                                : l10n.managerDashboardNoLiveShiftsSummary,
                        metrics: dashboardMetrics,
                        primaryLabel:
                            isPrimaryLoading
                                ? l10n.managerDashboardRefreshNow
                                : (hasActionableIssues
                                    ? l10n.managerDashboardReviewIssues
                                    : l10n.managerDashboardViewShiftReadiness),
                        onPrimaryTap:
                            isPrimaryLoading
                                ? _refreshAllData
                                : (hasActionableIssues
                                    ? issues.first.onTap
                                    : _openTodayShifts),
                        secondaryLabel: l10n.managerDashboardHistoryReports,
                        onSecondaryTap: _openTaskHistorySheet,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: Container(key: _tourIssuesKey, child: issueBoard),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1160;
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        key: _tourShiftReadinessKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DashboardSectionLabel(
                              title: l10n.managerDashboardShiftReadiness,
                              subtitle:
                                  l10n.managerDashboardShiftReadinessSubtitle,
                              helpTopicIds: [
                                'manager-shift-readiness',
                                'manager-dashboard',
                              ],
                            ),
                            const SizedBox(height: 8),
                            ShiftReadinessPanel(
                              shifts: shiftSummaries,
                              emptyTitle:
                                  l10n.managerDashboardNoScheduledShiftsYet,
                              emptySubtitle:
                                  l10n.managerDashboardNoScheduledShiftsBody,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      DashboardSectionLabel(
                        title: l10n.managerDashboardRecurringIssues,
                        subtitle: l10n.managerDashboardRecurringIssuesSubtitle,
                        helpTopicIds: [
                          'manager-recurring-issues',
                          'manager-history-reports',
                        ],
                      ),
                      const SizedBox(height: 8),
                      RecurringInsightsPanel(
                        title: l10n.managerDashboardRecurringFailures,
                        subtitle:
                            l10n.managerDashboardRecurringFailuresSubtitle,
                        items: recurringFailures,
                        emptyLabel: l10n.managerDashboardNoRecurringFailuresYet,
                      ),
                      const SizedBox(height: 10),
                      RecurringInsightsPanel(
                        title: l10n.managerDashboardAtRiskShifts,
                        subtitle: l10n.managerDashboardAtRiskShiftsSubtitle,
                        items: atRiskShifts,
                        emptyLabel: l10n.managerDashboardNoAtRiskShifts,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Container(
                        key: _tourShiftReadinessKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DashboardSectionLabel(
                              title: l10n.managerDashboardShiftReadiness,
                              subtitle:
                                  l10n.managerDashboardShiftReadinessSubtitle,
                              helpTopicIds: [
                                'manager-shift-readiness',
                                'manager-dashboard',
                              ],
                            ),
                            const SizedBox(height: 8),
                            ShiftReadinessPanel(
                              shifts: shiftSummaries,
                              emptyTitle:
                                  l10n.managerDashboardNoScheduledShiftsYet,
                              emptySubtitle:
                                  l10n.managerDashboardNoScheduledShiftsBody,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DashboardSectionLabel(
                            title: l10n.managerDashboardRecurringIssues,
                            subtitle:
                                l10n.managerDashboardRecurringIssuesSubtitle,
                            helpTopicIds: [
                              'manager-recurring-issues',
                              'manager-history-reports',
                            ],
                          ),
                          const SizedBox(height: 8),
                          RecurringInsightsPanel(
                            title: l10n.managerDashboardRecurringFailures,
                            subtitle:
                                l10n.managerDashboardRecurringFailuresSubtitle,
                            items: recurringFailures,
                            emptyLabel:
                                l10n.managerDashboardNoRecurringFailuresYet,
                          ),
                          const SizedBox(height: 10),
                          RecurringInsightsPanel(
                            title: l10n.managerDashboardAtRiskShifts,
                            subtitle: l10n.managerDashboardAtRiskShiftsSubtitle,
                            items: atRiskShifts,
                            emptyLabel: l10n.managerDashboardNoAtRiskShifts,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            HistoryReportsButton(onTap: _openTaskHistorySheet),
          ],
        ),
      ),
    );
  }

  Widget _buildCrmDashboardBanner() {
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
              'Viewing this customer dashboard from CRM. Navigation below stays scoped to this customer org.',
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

  // ====== Modals / Sheets ======

  void _openAllMissedYesterday() {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder:
          (context) => _ProfessionalDialog(
            title: l10n.managerDashboardAllMissedTasksYesterday,
            child:
                _loadingYesterday
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _yesterdayMissed.length,
                      itemBuilder: (context, i) {
                        final m = _yesterdayMissed[i];
                        final name =
                            (m['taskName'] ?? l10n.managerDashboardUnknownTask)
                                .toString();
                        final shift =
                            (m['shiftName'] ??
                                    l10n.managerDashboardUnknownShift)
                                .toString();
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
                                    Text(
                                      shift,
                                      style: GoogleFonts.comfortaa(
                                        color: HandsColors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (completedToday)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: HandsColors.sageGreen.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: HandsColors.sageGreen,
                                    ),
                                  ),
                                  child: Text(
                                    l10n.managerDashboardDoneToday,
                                    style: GoogleFonts.comfortaa(
                                      color: HandsColors.sageGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (count > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HandsColors.handsOrange.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: HandsColors.handsOrange,
                                    ),
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
                        final pct = ((s['completionPct'] ?? 0.0) as double)
                            .clamp(0.0, 1.0);
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          style: GoogleFonts.comfortaa(
                                            color: HandsColors.white70,
                                            fontSize: 12,
                                          ),
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
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s['completedTasks']}/${s['totalTasks']} tasks complete',
                                style: GoogleFonts.comfortaa(
                                  color: HandsColors.white70,
                                  fontSize: 11,
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
    _selectedDateRange ??= DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 3)),
      end: DateTime.now(),
    );
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
      var end = DateFormat('yyyy-MM-dd HH:mm').parse('$dateStr $endTime');

      // Handle overnight shifts (e.g., 18:00-02:00) by rolling the end time to the next day.
      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }
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
  const MiniSparkBars({
    super.key,
    required this.values,
    this.height = 60,
  }); // Increased from 40 to 60

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(height: height, child: const SizedBox.shrink());
    }

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
                      height: _calculateBarHeight(
                        values[i],
                        values,
                        height - 20,
                      ),
                      decoration: BoxDecoration(
                        color: _getTrendColor(values),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${values[i]}',
                      style: GoogleFonts.comfortaa(
                        fontSize: 8,
                        color: HandsColors.white70,
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 1,
      ), // Further reduced padding
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ), // Reduced radius
      child: Text(
        status,
        style: GoogleFonts.comfortaa(
          color: HandsColors.white,
          fontSize: 9,
        ), // Even smaller font
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

  const _ProfessionalDialog({
    required this.title,
    required this.child,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return HandsModalSurface(
      width: width ?? MediaQuery.of(context).size.width * 0.9,
      height: height ?? MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: HandsModalTokens.titleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: HandsModalTokens.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: HandsModalTokens.border),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: HandsModalTokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: HandsModalTokens.border, height: 1),
          Expanded(child: child),
        ],
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
      final userDoc =
          await FirestoreEnforcer.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final firstName = userData['firstName'] ?? '';
        final lastName = userData['lastName'] ?? '';
        final displayName = '$firstName $lastName'.trim();
        final userName =
            displayName.isNotEmpty ? displayName : (userData['email'] ?? uid);
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

      print(
        '[TaskHistory] Loading tasks from $startStr to $endStr for location: ${widget.selectedLocationId}',
      );

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
            locationQuery = locationQuery.where(
              'shiftId',
              isEqualTo: _selectedShift,
            );
          }

          final locationSnap = await locationQuery.get();
          print(
            '[TaskHistory] Location-scoped query returned ${locationSnap.docs.length} docs',
          );
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
            orgQuery = orgQuery.where(
              'locationId',
              isEqualTo: widget.selectedLocationId,
            );
          }
          if (_selectedShift != 'all') {
            orgQuery = orgQuery.where('shiftId', isEqualTo: _selectedShift);
          }

          final orgSnap = await orgQuery.get();
          print(
            '[TaskHistory] Org-scoped query returned ${orgSnap.docs.length} docs',
          );
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
        final checklistName =
            (data['templateName'] ?? data['checklistName'] ?? '').toString();

        // Handle both old format (tasks in document) and new format (tasks in subcollection)
        List<Map<String, dynamic>> tasks = [];

        if (data.containsKey('tasks') && data['tasks'] != null) {
          // Old format: tasks in document
          tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? const []);
          print(
            '[TaskHistory] Found ${tasks.length} tasks in document for ${d.id}',
          );
        } else {
          // New format: tasks in subcollection
          try {
            final tasksSnap = await d.reference.collection('tasks').get();
            tasks = tasksSnap.docs.map((taskDoc) => taskDoc.data()).toList();
            print(
              '[TaskHistory] Found ${tasks.length} tasks in subcollection for ${d.id}',
            );
          } catch (e) {
            print(
              '[TaskHistory] Failed to load tasks subcollection for ${d.id}: $e',
            );
          }
        }

        for (final t in tasks) {
          final name =
              (t['taskName'] ?? t['name'] ?? 'Unnamed Task').toString();
          final completed =
              t['completed'] == true ||
              t['isCompleted'] == true ||
              t['status'] == 'completed';
          final reason =
              (t['reason'] ??
                      t['reasonNotCompleted'] ??
                      t['reasonForNotCompleting'] ??
                      '')
                  .toString();
          final note =
              (t['note'] ?? t['notes'] ?? t['taskNote'] ?? '').toString();

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
              (t['completedBy'] ??
                      t['completedByUserId'] ??
                      t['completedByUserName'] ??
                      '')
                  .toString();
          String completedByName = '';
          String formattedTime = '';

          if (completed && completedByUid.isNotEmpty) {
            // Resolve user name from UID
            completedByName = await _resolveUserName(completedByUid);

            // Format timestamp
            final timeCompleted =
                t['timeCompleted'] ??
                t['completedAt'] ??
                t['updatedAt'] ??
                t['timestamp'];
            formattedTime = _formatTimestamp(timeCompleted);
          }

          final photoRequired =
              t['photoRequired'] == true ||
              t['requiresPhoto'] == true ||
              t['requirePhoto'] == true;

          // If photoRequired is false but we have templateTaskId, try to get it from the template
          bool finalPhotoRequired = photoRequired;
          if (!photoRequired) {
            final templateTaskId = t['templateTaskId']?.toString();
            final templateId =
                data['checklistTemplateId']?.toString() ??
                data['templateId']?.toString();

            if (templateTaskId != null &&
                templateId != null &&
                templateId.isNotEmpty) {
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
                  finalPhotoRequired =
                      templateTaskData['photoRequired'] == true;
                }
              } catch (e) {
                // Ignore template lookup errors
              }
            }
          }

          // Checklist filter (best-effort, some data models store checklistId on parent)
          if (_selectedChecklist != 'all' &&
              (data['templateId'] ?? data['checklistId']) !=
                  _selectedChecklist) {
            continue;
          }

          // Completion filter
          if (_selectedCompletion == 'completed' && !completed) continue;
          if (_selectedCompletion == 'incomplete' && completed) continue;
          if (_selectedCompletion == 'incomplete_with_reason' &&
              (completed || reason.isEmpty)) {
            continue;
          }
          if (_selectedCompletion == 'photo_added' && photos.isEmpty) continue;
          if (_selectedCompletion == 'notes_added' && note.isEmpty) continue;
          if (_selectedCompletion == 'photo_required' && !finalPhotoRequired) {
            continue;
          }

          // Search filter
          final q = _searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty &&
              !(name.toLowerCase().contains(q) ||
                  note.toLowerCase().contains(q) ||
                  reason.toLowerCase().contains(q))) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
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
                style: GoogleFonts.comfortaa(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: HandsColors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Search and Date Range Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.comfortaa(
                        fontSize: 14,
                        color: HandsColors.white,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search,
                          color: HandsColors.white70,
                          size: 20,
                        ),
                        labelText: 'Search tasks...',
                        labelStyle: GoogleFonts.comfortaa(
                          fontSize: 12,
                          color: HandsColors.white70,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: HandsColors.white12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: HandsColors.white12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: HandsColors.handsOrange,
                            width: 2,
                          ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
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
                      initialValue: _selectedShift,
                      style: GoogleFonts.comfortaa(
                        fontSize: 14,
                        color: HandsColors.white,
                      ),
                      dropdownColor: HandsColors.primaryContainer,
                      decoration: InputDecoration(
                        labelText: 'Shift',
                        labelStyle: GoogleFonts.comfortaa(
                          fontSize: 12,
                          color: HandsColors.white70,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: HandsColors.white12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: HandsColors.white12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: HandsColors.handsOrange,
                            width: 2,
                          ),
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
                            style: GoogleFonts.comfortaa(
                              fontSize: 14,
                              color: HandsColors.white,
                            ),
                          ),
                        ),
                        ...widget.shifts.map(
                          (s) => DropdownMenuItem(
                            value: s['id'],
                            child: Text(
                              s['name'] ?? 'Shift',
                              style: GoogleFonts.comfortaa(
                                fontSize: 14,
                                color: HandsColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                      onChanged:
                          (v) => setState(() => _selectedShift = v ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCompletion,
                      style: GoogleFonts.comfortaa(
                        fontSize: 14,
                        color: HandsColors.white,
                      ),
                      dropdownColor: HandsColors.primaryContainer,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: GoogleFonts.comfortaa(
                          fontSize: 12,
                          color: HandsColors.white70,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: HandsColors.white12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: HandsColors.white12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: HandsColors.handsOrange,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: HandsColors.primaryContainer,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'All',
                            style: GoogleFonts.comfortaa(
                              fontSize: 14,
                              color: HandsColors.white,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text(
                            'Done',
                            style: GoogleFonts.comfortaa(
                              fontSize: 14,
                              color: HandsColors.white,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'incomplete',
                          child: Text(
                            'Missed',
                            style: GoogleFonts.comfortaa(
                              fontSize: 14,
                              color: HandsColors.white,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'incomplete_with_reason',
                          child: Text(
                            'Missed w/ reason',
                            style: GoogleFonts.comfortaa(
                              fontSize: 14,
                              color: HandsColors.white,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'photo_added',
                          child: Text(
                            'Photo added',
                            style: GoogleFonts.comfortaa(
                              fontSize: 14,
                              color: HandsColors.white,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'notes_added',
                          child: Text(
                            'Notes added',
                            style: GoogleFonts.comfortaa(
                              fontSize: 14,
                              color: HandsColors.white,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'photo_required',
                          child: Text(
                            'Photo required',
                            style: GoogleFonts.comfortaa(
                              fontSize: 14,
                              color: HandsColors.white,
                            ),
                          ),
                        ),
                      ],
                      onChanged:
                          (v) =>
                              setState(() => _selectedCompletion = v ?? 'all'),
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
                    style: GoogleFonts.comfortaa(
                      fontSize: 12,
                      color: HandsColors.white70,
                    ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        HandsColors.handsOrange,
                      ),
                    ),
                  )
                  : _allRows.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: HandsColors.white30,
                        ),
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
                          style: GoogleFonts.comfortaa(
                            fontSize: 14,
                            color: HandsColors.white70,
                          ),
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
                                border: Border.all(
                                  color: HandsColors.white12,
                                  width: 1,
                                ),
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.all(16),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                expandedCrossAxisAlignment:
                                    CrossAxisAlignment.start,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            style: GoogleFonts.comfortaa(
                                              fontSize: 12,
                                              color: HandsColors.white70,
                                            ),
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                r.completed
                                                    ? HandsColors.sageGreen
                                                    : HandsColors.error,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                r.completed
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                size: 14,
                                                color: HandsColors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                r.completed
                                                    ? 'Completed'
                                                    : 'Missed',
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
                                        if (r.photoCount > 0 ||
                                            r.reason.isNotEmpty ||
                                            r.note.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: HandsColors.handsOrange
                                                  .withOpacity(0.2),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: HandsColors.handsOrange,
                                                width: 1,
                                              ),
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
                                  if (r.completed &&
                                      r.completedBy.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: HandsColors.sageGreen
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: HandsColors.sageGreen
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person_outlined,
                                                size: 18,
                                                color: HandsColors.sageGreen,
                                              ),
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
                                                  style: GoogleFonts.comfortaa(
                                                    fontSize: 12,
                                                    color: HandsColors.white,
                                                  ),
                                                ),
                                              ),
                                              if (r
                                                  .timeCompleted
                                                  .isNotEmpty) ...[
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: HandsColors.sageGreen,
                                                ),
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
                                        color: HandsColors.amber.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: HandsColors.amber.withOpacity(
                                            0.3,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.warning_amber,
                                                size: 18,
                                                color: HandsColors.amber,
                                              ),
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
                                            style: GoogleFonts.comfortaa(
                                              fontSize: 12,
                                              color: HandsColors.white,
                                            ),
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
                                        color: HandsColors.handsOrange
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: HandsColors.handsOrange
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.note,
                                                size: 18,
                                                color: HandsColors.handsOrange,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Note:',
                                                style: GoogleFonts.comfortaa(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color:
                                                      HandsColors.handsOrange,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            r.note,
                                            style: GoogleFonts.comfortaa(
                                              fontSize: 12,
                                              color: HandsColors.white,
                                            ),
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
                                        color: HandsColors.sageGreen
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: HandsColors.sageGreen
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.photo_library,
                                                size: 18,
                                                color: HandsColors.sageGreen,
                                              ),
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
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: HandsColors
                                                        .handsOrange
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          HandsColors
                                                              .handsOrange,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'REQUIRED',
                                                    style:
                                                        GoogleFonts.comfortaa(
                                                          color:
                                                              HandsColors
                                                                  .handsOrange,
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w600,
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
                                                r.photoUrls.take(6).map((
                                                  photoUrl,
                                                ) {
                                                  print(
                                                    '[TaskHistory] Debug: Attempting to load image: $photoUrl',
                                                  );
                                                  return GestureDetector(
                                                    onTap:
                                                        () =>
                                                            _showFullScreenImage(
                                                              context,
                                                              photoUrl,
                                                              r.taskName,
                                                            ),
                                                    child: Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              HandsColors
                                                                  .white12,
                                                        ),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        child: Image.network(
                                                          photoUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            print(
                                                              '[TaskHistory] Debug: Image load error for $photoUrl: $error',
                                                            );
                                                            return Container(
                                                              color:
                                                                  HandsColors
                                                                      .cardTertiary,
                                                              child: Column(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                    color:
                                                                        HandsColors
                                                                            .white30,
                                                                    size: 32,
                                                                  ),
                                                                  Text(
                                                                    'Failed to load',
                                                                    style: GoogleFonts.comfortaa(
                                                                      fontSize:
                                                                          8,
                                                                      color:
                                                                          HandsColors
                                                                              .white30,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                          loadingBuilder: (
                                                            context,
                                                            child,
                                                            loadingProgress,
                                                          ) {
                                                            if (loadingProgress ==
                                                                null) {
                                                              return child;
                                                            }
                                                            return Container(
                                                              color:
                                                                  HandsColors
                                                                      .cardTertiary,
                                                              child: Center(
                                                                child: CircularProgressIndicator(
                                                                  value:
                                                                      loadingProgress.expectedTotalBytes !=
                                                                              null
                                                                          ? loadingProgress.cumulativeBytesLoaded /
                                                                              loadingProgress.expectedTotalBytes!
                                                                          : null,
                                                                  strokeWidth:
                                                                      2,
                                                                  valueColor:
                                                                      const AlwaysStoppedAnimation<
                                                                        Color
                                                                      >(
                                                                        HandsColors
                                                                            .handsOrange,
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
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                '+ ${r.photoUrls.length - 6} more photos',
                                                style: GoogleFonts.comfortaa(
                                                  fontSize: 11,
                                                  color: HandsColors.white70,
                                                ),
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
                                        color: HandsColors.amber.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: HandsColors.amber.withOpacity(
                                            0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.photo_camera_outlined,
                                            size: 18,
                                            color: HandsColors.amber,
                                          ),
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
                      if (_allRows.isNotEmpty &&
                          (_currentPage + 1) * _itemsPerPage < _allRows.length)
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: HandsPrimaryButton(
                            text: 'Load 10 More Tasks',
                            onPressed: _loadMore,
                            icon: Icons.expand_more,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
        ),
      ],
    );
  }

  void _showFullScreenImage(
    BuildContext context,
    String imageUrl,
    String taskName,
  ) {
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
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: HandsColors.white,
                            ),
                          ),
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
                              Icon(
                                Icons.broken_image,
                                color: HandsColors.white,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.white),
                              ),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
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
