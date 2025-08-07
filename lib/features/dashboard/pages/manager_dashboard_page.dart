import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:intl/intl.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class ManagerDashboardPage extends StatefulWidget {
  final String organizationId;
  const ManagerDashboardPage({super.key, required this.organizationId});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage> {
  int? userRole; // Changed from hardcoded 1 to nullable int
  bool _isLoadingUserRole = true; // Add loading state for user role
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  late final String _todayKey;

  // Location selection at the top level
  String? _selectedLocationId;
  String? _selectedLocationName;
  List<Map<String, dynamic>> _availableLocations = [];
  bool _isLoadingLocations = true;

  // Missed tasks state
  List<Map<String, dynamic>> _yesterdayMissed = [];
  bool _loadingYesterday = true;
  String? _errorYesterday;

  // Live shifts state
  List<Map<String, dynamic>> _liveShifts = [];
  bool _loadingLive = true;
  String? _selectedRoleFilter = 'all';
  List<String> _availableRoles = ['all'];

  // Frequent missed tasks state
  List<Map<String, dynamic>> _frequentMisses30d = [];
  bool _loadingFrequent = true;

  // Audit filters (removed location filter)
  String _searchTerm = '';
  String _selectedShift = 'all';
  // Checklist template filter
  String _selectedChecklist = 'all';
  String _selectedCompletion = 'all'; // all, completed, incomplete
  DateTimeRange? _selectedDateRange;

  List<Map<String, String>> _shifts = [];
  List<Map<String, String>> _checklists = [];

  // Pagination for audit results
  int _auditItemsToShow = 10;
  static const int _auditItemsPerPage = 10;

  // Auto-refresh timer for live shifts
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _todayKey = _dateFormat.format(DateTime.now());
    _fetchUserRole();
    _loadLocations(); // This will call _loadAll() after location is selected
    // Auto-generate daily checklists when manager dashboard loads
    _ensureDailyChecklistsExist();
    // Start auto-refresh timer for live shifts
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Refresh live shifts every 2 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted && _selectedLocationId != null) {
        debugPrint('[ManagerDashboard] Auto-refreshing live shifts...');
        _loadLiveShifts();
      }
    });
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingUserRole = false;
      });
      return;
    }
    final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      setState(() {
        userRole = data['userRole'] ?? 1;
        _isLoadingUserRole = false;
      });
    } else {
      setState(() {
        _isLoadingUserRole = false;
      });
    }
  }

  Future<void> _ensureDailyChecklistsExist() async {
    try {
      final service = DailyChecklistService();
      await service.ensureDailyChecklistsExist(widget.organizationId);
      debugPrint('Daily checklist generation check completed for organization ${widget.organizationId}');
    } catch (e) {
      debugPrint('Error ensuring daily checklists exist: $e');
    }
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoadingLocations = true;
    });

    try {
      final locationsSnap =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('locations')
              .get();

      final locations =
          locationsSnap.docs.map((doc) {
            final data = doc.data();
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

      setState(() {
        _availableLocations = locations;

        // Auto-select primary location or first location if available
        if (locations.isNotEmpty) {
          final primaryLocation = locations.firstWhere(
            (loc) => loc['isPrimary'] == true,
            orElse: () => locations.first,
          );
          _selectedLocationId = primaryLocation['id'];
          _selectedLocationName = primaryLocation['name'];
        }
      });

      // Load filter options after location is selected
      if (_selectedLocationId != null) {
        await _loadFilterOptions();
        // Load all dashboard data after location and filters are ready
        await _loadAll();
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load locations: $e')));
      }
    } finally {
      setState(() {
        _isLoadingLocations = false;
      });
    }
  }

  Future<void> _loadFilterOptions() async {
    // Load shifts for the selected location
    final shiftsSnap =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('shifts')
            .where('locationIds', arrayContains: _selectedLocationId)
            .get();

    // Load checklist templates
    final templatesSnap =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(widget.organizationId)
            .collection('checklist_templates')
            .get();

    setState(() {
      _shifts =
          shiftsSnap.docs
              .map((d) => {'id': d.id, 'name': d.data()['shiftName']?.toString() ?? 'Unnamed Shift'})
              .toList();

      _checklists =
          templatesSnap.docs
              .map((d) => {'id': d.id, 'name': d.data()['name']?.toString() ?? 'Unnamed Checklist'})
              .toList();
    });
  }

  // Data loading methods for missed tasks insights
  Future<void> _loadAll() async {
    await Future.wait([_loadYesterdayMissed(), _loadLiveShifts(), _loadFrequentMisses30d()]);
  }

  Future<void> _loadYesterdayMissed() async {
    setState(() {
      _loadingYesterday = true;
      _errorYesterday = null;
    });

    try {
      final service = DailyChecklistService();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      // Ensure yesterday's checklists exist for accurate missed tasks calculation
      await service.generateAllDailyChecklistsForDate(
        organizationId: widget.organizationId,
        date: _dateFormat.format(yesterday),
      );
      _yesterdayMissed = await service.getMissedTasksForDate(
        organizationId: widget.organizationId,
        date: yesterday,
        locationId: _selectedLocationId,
      );
      debugPrint('[ManagerDashboard] Loaded ${_yesterdayMissed.length} missed tasks from yesterday');
    } catch (e, st) {
      debugPrint('[ManagerDashboard] getMissedTasksForDate error: $e\n$st');
      _errorYesterday = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loadingYesterday = false);
      }
    }
  }

  Future<void> _loadLiveShifts() async {
    setState(() => _loadingLive = true);

    try {
      debugPrint('[ManagerDashboard] Starting _loadLiveShifts for location: $_selectedLocationId');

      if (_selectedLocationId == null) {
        debugPrint('[ManagerDashboard] No location selected, clearing shifts');
        setState(() {
          _liveShifts = [];
          _availableRoles = ['all'];
        });
        return;
      }

      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      debugPrint('[ManagerDashboard] Loading shifts for date: $todayStr');

      // Get all shifts for the selected location
      debugPrint('[ManagerDashboard] Querying shifts with locationIds containing: $_selectedLocationId');
      var shiftsQuery =
          await FirestoreEnforcer.instance
              .collection('organizations')
              .doc(widget.organizationId)
              .collection('shifts')
              .where('locationIds', arrayContains: _selectedLocationId)
              .get();

      debugPrint('[ManagerDashboard] Found ${shiftsQuery.docs.length} shifts for location $_selectedLocationId');

      List<QueryDocumentSnapshot> shiftDocs = shiftsQuery.docs;

      // If no shifts found with locationIds, try alternative query
      if (shiftDocs.isEmpty) {
        debugPrint('[ManagerDashboard] No shifts found with locationIds, trying alternative query...');
        final alternativeQuery =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(widget.organizationId)
                .collection('shifts')
                .get();

        debugPrint('[ManagerDashboard] Alternative query found ${alternativeQuery.docs.length} total shifts');

        // Filter shifts that match the location
        shiftDocs =
            alternativeQuery.docs.where((doc) {
              final data = doc.data();
              final locationIds = data['locationIds'] as List?;
              final locationId = data['locationId'] as String?;

              return (locationIds != null && locationIds.contains(_selectedLocationId)) ||
                  (locationId != null && locationId == _selectedLocationId);
            }).toList();

        debugPrint('[ManagerDashboard] Filtered to ${shiftDocs.length} shifts for location $_selectedLocationId');
      }

      List<Map<String, dynamic>> todaysShifts = [];

      for (final shiftDoc in shiftDocs) {
        final shiftData = shiftDoc.data() as Map<String, dynamic>;
        final shiftName = shiftData['shiftName'] ?? 'Unknown Shift';
        final startTime = shiftData['startTime'] ?? '';
        final endTime = shiftData['endTime'] ?? '';
        final role = shiftData['role'] ?? '';

        debugPrint('[ManagerDashboard] Processing shift: $shiftName (${shiftDoc.id}) - $startTime to $endTime');

        // Get ALL today's checklists for this shift (don't limit to 1)
        final checklistQuery =
            await FirestoreEnforcer.instance
                .collection('organizations')
                .doc(widget.organizationId)
                .collection('locations')
                .doc(_selectedLocationId!)
                .collection('daily_checklists')
                .where('date', isEqualTo: todayStr)
                .where('shiftId', isEqualTo: shiftDoc.id)
                .get();

        debugPrint(
          '[ManagerDashboard] Found ${checklistQuery.docs.length} checklists for shift ${shiftDoc.id} on $todayStr',
        );

        double completionPct = 0.0;
        int totalTasks = 0;
        int completedTasks = 0;

        if (checklistQuery.docs.isNotEmpty) {
          // Aggregate all tasks from all checklists for this shift
          for (final checklistDoc in checklistQuery.docs) {
            final checklistData = checklistDoc.data();
            final tasks = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);
            totalTasks += tasks.length;

            completedTasks +=
                tasks
                    .where(
                      (task) =>
                          task['completed'] == true || task['isCompleted'] == true || task['status'] == 'completed',
                    )
                    .length;
          }

          if (totalTasks > 0) {
            completionPct = completedTasks / totalTasks;
          }
          debugPrint(
            '[ManagerDashboard] Shift $shiftName: $completedTasks/$totalTasks tasks from ${checklistQuery.docs.length} checklists (${(completionPct * 100).round()}%)',
          );
        } else {
          debugPrint('[ManagerDashboard] No checklist found for shift $shiftName, showing 0/0 tasks');
        }

        // Calculate time status
        String timeStatus = _calculateTimeStatus(startTime, endTime);
        debugPrint('[ManagerDashboard] Time status for $shiftName: $timeStatus');

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

      // Extract available roles
      final roles =
          todaysShifts.map((shift) => shift['role'] as String? ?? '').where((role) => role.isNotEmpty).toSet().toList();

      debugPrint('[ManagerDashboard] Available roles: $roles');
      debugPrint('[ManagerDashboard] Final shifts count: ${todaysShifts.length}');

      setState(() {
        _liveShifts = todaysShifts;
        _availableRoles = ['all', ...roles];
      });

      debugPrint('[ManagerDashboard] Successfully loaded ${_liveShifts.length} today\'s shifts');
    } catch (e, st) {
      debugPrint('[ManagerDashboard] _loadLiveShifts error: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _loadingLive = false);
      }
    }
  }

  String _calculateTimeStatus(String startTime, String endTime) {
    if (startTime.isEmpty || endTime.isEmpty) {
      return 'No schedule';
    }

    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final start = DateFormat('yyyy-MM-dd HH:mm').parse('$today $startTime');
      final end = DateFormat('yyyy-MM-dd HH:mm').parse('$today $endTime');

      if (now.isBefore(start)) {
        final timeToStart = start.difference(now);
        return 'Starts in ${_formatDuration(timeToStart)}';
      } else if (now.isAfter(end)) {
        return 'Finished';
      } else {
        final timeRemaining = end.difference(now);
        return '${_formatDuration(timeRemaining)} remaining';
      }
    } catch (e) {
      return 'Invalid schedule';
    }
  }

  Future<void> _loadFrequentMisses30d() async {
    setState(() => _loadingFrequent = true);

    try {
      debugPrint('[ManagerDashboard] Starting _loadFrequentMisses30d for location: $_selectedLocationId');
      final service = DailyChecklistService();
      _frequentMisses30d = await service.getFrequentlyMissedTasks(
        organizationId: widget.organizationId,
        days: 30,
        limit: 10,
        locationId: _selectedLocationId,
      );
      debugPrint('[ManagerDashboard] Loaded ${_frequentMisses30d.length} frequently missed tasks');
      if (_frequentMisses30d.isNotEmpty) {
        debugPrint('[ManagerDashboard] First 3 frequent misses:');
        for (int i = 0; i < _frequentMisses30d.length && i < 3; i++) {
          final task = _frequentMisses30d[i];
          debugPrint('[ManagerDashboard]   ${i + 1}. ${task['taskName']} (${task['missedCount']} times)');
        }
      } else {
        debugPrint('[ManagerDashboard] No frequently missed tasks found - this could mean:');
        debugPrint('[ManagerDashboard]   1. No daily checklists exist for the last 30 days');
        debugPrint('[ManagerDashboard]   2. All tasks have been completed');
        debugPrint('[ManagerDashboard]   3. There are only carry-forward tasks (which are excluded)');
      }
    } catch (e, st) {
      debugPrint('[ManagerDashboard] getFrequentlyMissedTasks error: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _loadingFrequent = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocations || _isLoadingUserRole) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manager Dashboard'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBar: BottomNavBar(currentIndex: 1, userRole: userRole),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(appBarTitle: 'Manager Dashboard', userRole: userRole),
        automaticallyImplyLeading: false,
        foregroundColor: Colors.white,
        actions: [
          // Compact location selector for mobile
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              enabled: _availableLocations.isNotEmpty,
              onSelected: (value) async {
                setState(() {
                  _selectedLocationId = value;
                  _selectedLocationName =
                      _availableLocations.firstWhere(
                        (loc) => loc['id'] == value,
                        orElse: () => {'name': 'Unknown Location'},
                      )['name'];
                });
                await _loadFilterOptions();
                await _loadAll(); // Reload all data when location changes
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
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                    );
                  } else {
                    // Full desktop version
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
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
      bottomNavigationBar: BottomNavBar(currentIndex: 1, userRole: userRole),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Today header
              _buildTodayHeader(),
              const SizedBox(height: 20),
              _buildLiveViewSection(),
              const SizedBox(height: 32),
              _buildHistoricInsightsSection(),
              const SizedBox(height: 30),
              _buildHistoricShiftPerformance(),
              const SizedBox(height: 30),
              _buildAuditSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayHeader() {
    final today = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(today);

    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 32, // Account for padding
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Manager Dashboard',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formattedDate,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
            ),
            if (_selectedLocationName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Location: $_selectedLocationName',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
            const SizedBox(height: 16),
            // Missed Yesterday insights instead of live organization stats
            _buildMissedYesterdayCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMissedYesterdayCard() {
    if (_loadingYesterday) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Missed Yesterday',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      );
    }

    if (_errorYesterday != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Missed Yesterday',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Could not load missed tasks.', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
          ],
        ),
      );
    }

    if (_yesterdayMissed.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Missed Yesterday',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Great! No missed tasks yesterday.', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
          ],
        ),
      );
    }

    final showScroll = _yesterdayMissed.length > 4;
    final visibleTasks = showScroll ? _yesterdayMissed : _yesterdayMissed.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Missed Yesterday',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_yesterdayMissed.length > 4)
                TextButton(
                  onPressed: _openAllMissedYesterday,
                  child: Text('View all', style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (showScroll)
            SizedBox(
              height: 220, // Adjust height as needed for 4 items
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _yesterdayMissed.length,
                itemBuilder: (context, idx) {
                  final missed = _yesterdayMissed[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                missed['taskName'] ?? 'Unknown Task',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                missed['shiftName'] ?? 'Unknown Shift',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if ((missed['count'] as int? ?? 1) > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '×${missed['count']}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            ...visibleTasks.map(
              (missed) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            missed['taskName'] ?? 'Unknown Task',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            missed['shiftName'] ?? 'Unknown Shift',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if ((missed['count'] as int? ?? 1) > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '×${missed['count']}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _buildLiveViewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.live_tv, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Live view of today\'s shifts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: Theme.of(context).primaryColor),
              tooltip: 'Refresh live progress',
              onPressed: () async {
                setState(() => _loadingLive = true);
                await _loadLiveShifts();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Role filter chips
        if (_availableRoles.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _availableRoles.map((role) {
                    final isSelected = _selectedRoleFilter == role;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          role == 'all' ? 'All' : role,
                          style: TextStyle(color: isSelected ? Colors.white : Theme.of(context).primaryColor),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedRoleFilter = role);
                            _loadLiveShifts(); // Reload with new filter
                          }
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: Theme.of(context).primaryColor,
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Live shifts container with gradient background
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 32, // Account for padding
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withValues(alpha: 0.1),
                Theme.of(context).primaryColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
          ),
          child:
              _loadingLive
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredLiveShifts.isEmpty
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.schedule, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No shifts scheduled for today.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                  : Column(
                    children: [
                      // Debug info (remove this in production)
                      if (kDebugMode)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Debug: ${_liveShifts.length} total shifts, ${_filteredLiveShifts.length} filtered',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: _filteredLiveShifts.map((shift) => _buildLiveShiftCard(shift)).toList(),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredLiveShifts {
    if (_selectedRoleFilter == 'all') return _liveShifts;
    return _liveShifts.where((shift) => shift['role'] == _selectedRoleFilter).toList();
  }

  Widget _buildLiveShiftCard(Map<String, dynamic> shift) {
    final completionPct = (shift['completionPct'] as double? ?? 0.0);
    final completedTasks = shift['completedTasks'] as int? ?? 0;
    final totalTasks = shift['totalTasks'] as int? ?? 0;
    final shiftName = shift['shiftName'] as String? ?? 'Unknown Shift';
    final role = shift['role'] as String? ?? '';
    final startTime = shift['startTime'] as String? ?? '';
    final endTime = shift['endTime'] as String? ?? '';
    final timeStatus = shift['timeStatus'] as String? ?? 'Unknown status';

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive width
        double cardWidth;
        final screenWidth = MediaQuery.of(context).size.width;
        final availableWidth = screenWidth - 64; // Account for padding and margins

        if (availableWidth < 320) {
          cardWidth = availableWidth; // Single card on very small screens
        } else if (availableWidth < 600) {
          cardWidth = availableWidth; // Single card on small screens
        } else if (availableWidth < 900) {
          cardWidth = (availableWidth - 16) / 2; // Two cards on medium screens
        } else {
          cardWidth = (availableWidth - 32) / 3; // Three cards on large screens
        }

        return Container(
          width: cardWidth,
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 400),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shift name and time status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shiftName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        if (role.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            role,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                        if (startTime.isNotEmpty && endTime.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$startTime - $endTime',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Time status chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTimeStatusColor(timeStatus),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      timeStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Task Progress',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$completedTasks/$totalTasks tasks',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  LinearProgressIndicator(
                    value: completionPct,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completionPct >= 0.8
                          ? Colors.green
                          : completionPct >= 0.5
                          ? Colors.orange
                          : Colors.red,
                    ),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 4),
                  // Percentage
                  Text(
                    '${(completionPct * 100).round()}% complete',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          completionPct >= 0.8
                              ? Colors.green
                              : completionPct >= 0.5
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getTimeStatusColor(String timeStatus) {
    if (timeStatus.contains('Finished')) {
      return Colors.grey;
    } else if (timeStatus.contains('Starts in')) {
      return Colors.blue;
    } else if (timeStatus.contains('remaining')) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }

  void _openAllMissedYesterday() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'All Missed Tasks Yesterday',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _yesterdayMissed.length,
                          itemBuilder: (context, index) {
                            final missed = _yesterdayMissed[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(missed['taskName'] ?? 'Unknown Task'),
                                subtitle: Text(missed['shiftName'] ?? 'Unknown Shift'),
                                trailing:
                                    missed['count'] > 1
                                        ? Chip(label: Text('×${missed['count']}'), backgroundColor: Colors.orange[100])
                                        : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  // ignore: unused_element
  Widget _buildShiftProgressCard(QueryDocumentSnapshot shiftDoc) {
    final shiftData = shiftDoc.data() as Map<String, dynamic>;
    final shiftName = shiftData['shiftName'] ?? 'Unnamed Shift';
    final startTime = shiftData['startTime'] ?? '';
    final endTime = shiftData['endTime'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shiftName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (startTime.isNotEmpty && endTime.isNotEmpty)
                        Text(
                          '$startTime - $endTime',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                _buildTimeRemaining(startTime, endTime),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream:
                  _selectedLocationId != null
                      ? FirestoreEnforcer.instance
                          .collection('organizations')
                          .doc(widget.organizationId)
                          .collection('locations')
                          .doc(_selectedLocationId!)
                          .collection('daily_checklists')
                          .where('date', isEqualTo: _todayKey)
                          .where('shiftId', isEqualTo: shiftDoc.id)
                          .snapshots()
                      : const Stream.empty(), // No location selected, no data
              builder: (context, checklistSnapshot) {
                if (!checklistSnapshot.hasData) {
                  return const LinearProgressIndicator(value: 0);
                }

                final checklists = checklistSnapshot.data!.docs;
                if (checklists.isEmpty) {
                  return Column(
                    children: [
                      const LinearProgressIndicator(value: 0),
                      const SizedBox(height: 8),
                      Text(
                        'No checklists for today - Staff need to select this shift',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  );
                }

                int totalCompleted = 0;
                int totalTasks = 0;

                for (final doc in checklists) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Use completedItems/totalItems if available, otherwise calculate from tasks
                  if (data.containsKey('completedItems') && data.containsKey('totalItems')) {
                    totalCompleted += (data['completedItems'] ?? 0) as int;
                    totalTasks += (data['totalItems'] ?? 0) as int;
                  } else {
                    // Fallback: calculate from tasks array
                    final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
                    totalTasks += tasks.length;
                    totalCompleted += tasks.where((task) => task['completed'] == true).length;
                  }
                }

                final progress = totalTasks > 0 ? totalCompleted / totalTasks : 0.0;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Task Progress'),
                        Text(
                          '$totalCompleted/$totalTasks tasks (${(progress * 100).round()}%)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? Colors.green : Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRemaining(String startTime, String endTime) {
    if (startTime.isEmpty || endTime.isEmpty) {
      return Chip(label: const Text('No schedule'), backgroundColor: Colors.grey[200]);
    }

    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final start = DateFormat('yyyy-MM-dd HH:mm').parse('$today $startTime');
      final end = DateFormat('yyyy-MM-dd HH:mm').parse('$today $endTime');

      if (now.isBefore(start)) {
        final timeToStart = start.difference(now);
        return Chip(label: Text('Starts in ${_formatDuration(timeToStart)}'), backgroundColor: Colors.blue[100]);
      } else if (now.isAfter(end)) {
        return Chip(label: const Text('Shift ended'), backgroundColor: Colors.grey[300]);
      } else {
        final timeRemaining = end.difference(now);
        return Chip(label: Text('${_formatDuration(timeRemaining)} left'), backgroundColor: Colors.green[100]);
      }
    } catch (e) {
      return Chip(label: const Text('Invalid time'), backgroundColor: Colors.red[100]);
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Widget _buildHistoricShiftPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'Historic Shift Performance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Swipe to explore performance insights',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          key: ValueKey(_selectedLocationId), // Force rebuild when location changes
          future: _calculateShiftPerformanceAnalytics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[100]),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No historical data available yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            final analytics = snapshot.data!;
            final topPerformers = analytics['topPerformers'] as List<Map<String, dynamic>>;
            final poorPerformers = analytics['poorPerformers'] as List<Map<String, dynamic>>;
            final dayAnalysis = analytics['dayAnalysis'] as List<Map<String, dynamic>>;

            // Create list of cards to display
            List<Widget> performanceCards = [];

            // Top Performers Card
            if (topPerformers.isNotEmpty) {
              performanceCards.add(_buildSwipeableTopPerformersCard(topPerformers));
            }

            // Poor Performers Card
            if (poorPerformers.isNotEmpty) {
              performanceCards.add(_buildSwipeablePoorPerformersCard(poorPerformers));
            }

            // Day Analysis Cards (one for each problematic shift)
            for (final analysis in dayAnalysis) {
              performanceCards.add(_buildSwipeableDayAnalysisCard(analysis));
            }

            // If no issues found, show a positive summary card
            if (performanceCards.isEmpty) {
              performanceCards.add(_buildSwipeableNoIssuesCard());
            }

            return SizedBox(
              height: 220,
              child: PageView.builder(
                itemCount: performanceCards.length,
                padEnds: false,
                controller: PageController(viewportFraction: 0.9),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: index < performanceCards.length - 1 ? 12.0 : 0),
                    child: performanceCards[index],
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Page indicator dots
        FutureBuilder<Map<String, dynamic>>(
          key: ValueKey('${_selectedLocationId}_dots'), // Force rebuild when location changes
          future: _calculateShiftPerformanceAnalytics(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final analytics = snapshot.data!;
            final topPerformers = analytics['topPerformers'] as List<Map<String, dynamic>>;
            final poorPerformers = analytics['poorPerformers'] as List<Map<String, dynamic>>;
            final dayAnalysis = analytics['dayAnalysis'] as List<Map<String, dynamic>>;

            int cardCount = 0;
            if (topPerformers.isNotEmpty) cardCount++;
            if (poorPerformers.isNotEmpty) cardCount++;
            cardCount += dayAnalysis.length;
            if (cardCount == 0) cardCount = 1; // No issues card

            if (cardCount <= 1) return const SizedBox.shrink();

            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  cardCount,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSwipeableTopPerformersCard(List<Map<String, dynamic>> topPerformers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.star, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Performers',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                      Text(
                        'Best completion rates',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topPerformers.take(3).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final shift = topPerformers[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift['shiftName'],
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${shift['totalSessions']} sessions',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(shift['avgCompletionRate'] * 100).round()}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeablePoorPerformersCard(List<Map<String, dynamic>> poorPerformers) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.shade600, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.warning, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Needs Improvement',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                      ),
                      Text(
                        'Focus areas for training',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: poorPerformers.take(3).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final shift = poorPerformers[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(child: Icon(Icons.trending_down, color: Colors.white, size: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift['shiftName'],
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${shift['totalSessions']} sessions',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(shift['avgCompletionRate'] * 100).round()}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeableDayAnalysisCard(Map<String, dynamic> analysis) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Pattern Issue',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                        ),
                        Text(
                          '${analysis['shiftName']}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${analysis['worstDay']}s are problematic',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Only ${(analysis['worstDayRate'] * 100).toStringAsFixed(0)}% completion rate on ${analysis['worstDay']}s',
                      style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on ${analysis['worstDaySessionCount']} sessions',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showDayAnalysisDetails(analysis),
                icon: const Icon(Icons.analytics, size: 16),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeableNoIssuesCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(32)),
              child: const Icon(Icons.thumb_up, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'All Systems Green!',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
            ),
            const SizedBox(height: 8),
            Text(
              'No performance issues detected. All shifts are performing consistently across all days of the week.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blue.shade700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.search, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'View Previous Checklists & Tasks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAuditFilters(),
        const SizedBox(height: 16),
        _buildAuditResults(),
      ],
    );
  }

  Widget _buildAuditFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search tasks, checklists, or users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged:
                  (value) => setState(() {
                    _searchTerm = value.toLowerCase();
                    _auditItemsToShow = _auditItemsPerPage; // Reset pagination
                  }),
            ),
            const SizedBox(height: 16),

            // Filter row 1
            Row(
              children: [
                // Shift filter or loading
                Expanded(
                  child:
                      _shifts.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<String>(
                            value: _selectedShift,
                            decoration: const InputDecoration(labelText: 'Shift', border: OutlineInputBorder()),
                            style: const TextStyle(fontSize: 14),
                            isExpanded: true, // Prevent overflow
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text(
                                  'All Shifts',
                                  style: TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ..._shifts.map(
                                (shift) => DropdownMenuItem(
                                  value: shift['id'],
                                  child: Text(
                                    shift['name']!,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                            onChanged:
                                (value) => setState(() {
                                  _selectedShift = value!;
                                  _auditItemsToShow = _auditItemsPerPage; // Reset pagination
                                }),
                          ),
                ),
                const SizedBox(width: 12),

                // Checklist filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedChecklist,
                    decoration: const InputDecoration(labelText: 'Checklists', border: OutlineInputBorder()),
                    style: const TextStyle(fontSize: 14),
                    isExpanded: true, // Prevent overflow
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Checklists', style: TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                      ),
                      ..._checklists.map(
                        (c) => DropdownMenuItem(
                          value: c['id'],
                          child: Text(
                            c['name']!,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                    onChanged:
                        (value) => setState(() {
                          _selectedChecklist = value!;
                          _auditItemsToShow = _auditItemsPerPage; // Reset pagination
                        }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter row 2
            Row(
              children: [
                // Completion filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCompletion,
                    decoration: const InputDecoration(labelText: 'Completion Status', border: OutlineInputBorder()),
                    style: const TextStyle(fontSize: 14),
                    isExpanded: true, // Prevent overflow
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Tasks', style: TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed Only', style: TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'incomplete',
                        child: Text('Incomplete Only', style: TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'incomplete_with_reason',
                        child: Text(
                          'Incomplete (with Reason)',
                          style: TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged:
                        (value) => setState(() {
                          _selectedCompletion = value!;
                          _auditItemsToShow = _auditItemsPerPage; // Reset pagination
                        }),
                  ),
                ),
                const SizedBox(width: 12),

                // Date range filter
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _selectedDateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat('M/d').format(_selectedDateRange!.start)} - ${DateFormat('M/d').format(_selectedDateRange!.end)}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Clear filters button
            if (_searchTerm.isNotEmpty ||
                _selectedShift != 'all' ||
                _selectedChecklist != 'all' ||
                _selectedCompletion != 'all' ||
                _selectedDateRange != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear All Filters'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _auditItemsToShow = _auditItemsPerPage; // Reset pagination
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchTerm = '';
      _selectedShift = 'all';
      _selectedChecklist = 'all';
      _selectedCompletion = 'all';
      _selectedDateRange = null;
      _auditItemsToShow = _auditItemsPerPage; // Reset pagination
    });
  }

  void _loadMoreAuditItems() {
    setState(() {
      _auditItemsToShow += _auditItemsPerPage;
    });
  }

  Widget _buildAuditResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildAuditQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Error in audit query: ${snapshot.error}');
          // Try a simpler query without ordering if the main query fails
          return StreamBuilder<QuerySnapshot>(
            stream: _buildSimpleAuditQuery(),
            builder: (context, fallbackSnapshot) {
              if (!fallbackSnapshot.hasData) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                        const SizedBox(height: 8),
                        const Text('Error loading audit data'),
                        const SizedBox(height: 8),
                        Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              final checklists = fallbackSnapshot.data!.docs;
              final filteredResults = _filterAuditResults(checklists);

              if (filteredResults.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        const Text('No results found with current filters'),
                        const SizedBox(height: 4),
                        Text(
                          'Found ${checklists.length} checklists but no matching tasks',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _clearFilters, child: const Text('Clear Filters')),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Text(
                    'Found ${filteredResults.length} tasks from ${checklists.length} checklists',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredResults.length > _auditItemsToShow ? _auditItemsToShow : filteredResults.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final taskData = filteredResults[index];
                      return _buildAuditResultItem(taskData);
                    },
                  ),
                  if (filteredResults.length > _auditItemsToShow) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: OutlinedButton.icon(
                        onPressed: _loadMoreAuditItems,
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                          'Load ${(filteredResults.length - _auditItemsToShow) >= _auditItemsPerPage ? _auditItemsPerPage : (filteredResults.length - _auditItemsToShow)} More Tasks',
                        ),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Showing ${_auditItemsToShow} of ${filteredResults.length} tasks',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              );
            },
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final checklists = snapshot.data!.docs;
        debugPrint('Audit query returned ${checklists.length} checklists');

        final filteredResults = _filterAuditResults(checklists);

        if (filteredResults.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  const Text('No results found with current filters'),
                  const SizedBox(height: 4),
                  Text(
                    'Found ${checklists.length} checklists but no matching tasks',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _clearFilters, child: const Text('Clear Filters')),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Text(
              'Found ${filteredResults.length} tasks from ${checklists.length} checklists',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredResults.length > _auditItemsToShow ? _auditItemsToShow : filteredResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final taskData = filteredResults[index];
                return _buildAuditResultItem(taskData);
              },
            ),
            if (filteredResults.length > _auditItemsToShow) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _loadMoreAuditItems,
                  icon: const Icon(Icons.expand_more),
                  label: Text(
                    'Load ${(filteredResults.length - _auditItemsToShow) >= _auditItemsPerPage ? _auditItemsPerPage : (filteredResults.length - _auditItemsToShow)} More Tasks',
                  ),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Showing ${_auditItemsToShow} of ${filteredResults.length} tasks',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildAuditQuery() {
    // For the new nested structure, audit queries across all locations are complex
    // For now, we'll implement a simplified approach that requires location selection
    if (_selectedLocationId == null) {
      return const Stream.empty();
    }

    final endDate = DateTime.now();
    final startDate = _selectedDateRange?.start ?? endDate.subtract(const Duration(days: 30));
    final endDateForQuery = _selectedDateRange?.end ?? endDate;

    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDateForQuery);

    var query = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('locations')
        .doc(_selectedLocationId!)
        .collection('daily_checklists')
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .where('date', isLessThanOrEqualTo: endDateStr)
        .limit(500);

    return query.snapshots();
  }

  // Enhanced simple query for fallback with in-memory filtering
  Stream<QuerySnapshot> _buildSimpleAuditQuery() {
    // For the new nested structure, require location selection
    if (_selectedLocationId == null) {
      return const Stream.empty();
    }

    // Use the simplest possible query - just get recent checklists by date
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));
    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);

    var query = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('locations')
        .doc(_selectedLocationId!)
        .collection('daily_checklists')
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .limit(200);

    return query.snapshots();
  }

  List<Map<String, dynamic>> _filterAuditResults(List<QueryDocumentSnapshot> checklists) {
    List<Map<String, dynamic>> allTasks = [];
    for (final doc in checklists) {
      final data = doc.data() as Map<String, dynamic>;
      final checklistName = data['templateName'] ?? data['checklistName'] ?? data['name'] ?? 'Unnamed Checklist';
      final startedByUserId = data['startedByUserId'] ?? data['userId'] ?? '';
      final date = data['date'] ?? '';
      final shiftId = data['shiftId'] ?? '';
      final locationId = data['locationId'] ?? '';
      final checklistTemplateId = data['checklistTemplateId'] ?? data['templateId'] ?? '';

      // Apply Firestore-level filters first (in memory)

      // Location filter
      if (_selectedLocationId != null && locationId != _selectedLocationId) {
        continue;
      }

      // Shift filter
      if (_selectedShift != 'all' && shiftId != _selectedShift) {
        debugPrint('Filtering out checklist ${doc.id} - shift $shiftId does not match selected shift $_selectedShift');
        continue;
      }

      // Checklist template filter
      if (_selectedChecklist != 'all' && checklistTemplateId != _selectedChecklist) {
        continue;
      }

      final shiftName =
          _shifts.firstWhere((s) => s['id'] == shiftId, orElse: () => {'name': 'Unknown Shift'})['name'] ??
          'Unknown Shift';

      // Get tasks from this checklist
      final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);

      debugPrint('Processing checklist ${doc.id} (shift: $shiftName): ${tasks.length} tasks found');

      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];

        // Try multiple possible field names for task description/name
        final taskName =
            task['description'] ??
            task['title'] ??
            task['name'] ??
            task['taskName'] ??
            task['taskTitle'] ??
            'Unnamed Task';

        // Check multiple possible completion fields
        final completed =
            task['isCompleted'] == true ||
            task['completed'] == true ||
            task['status'] == 'completed' ||
            task['done'] == true;
        final reason = task['reason'] ?? task['incompleteReason'] ?? '';

        // Get completed by information with fallback logic
        final completedBy =
            task['completedByUserName'] ?? task['completedBy'] ?? task['userName'] ?? task['completedByUserId'] ?? '';

        // Get completion timestamp
        final completedAt = task['completedAt'] ?? task['timestamp'];

        // Handle different timestamp formats
        DateTime? completedDateTime;
        if (completedAt != null) {
          try {
            if (completedAt is Timestamp) {
              completedDateTime = completedAt.toDate();
            } else if (completedAt is String) {
              completedDateTime = DateTime.parse(completedAt);
            }
          } catch (e) {
            debugPrint('Error parsing completion timestamp: $e');
          }
        }

        // Use createdAt/updatedAt as fallback timestamp
        final fallbackTimestamp = data['createdAt'] ?? data['updatedAt'];
        DateTime? fallbackDateTime;
        if (fallbackTimestamp != null && completedDateTime == null) {
          try {
            if (fallbackTimestamp is Timestamp) {
              fallbackDateTime = fallbackTimestamp.toDate();
            } else if (fallbackTimestamp is String) {
              fallbackDateTime = DateTime.parse(fallbackTimestamp);
            }
          } catch (e) {
            debugPrint('Error parsing fallback timestamp: $e');
          }
        }

        final finalTimestamp = completedDateTime ?? fallbackDateTime;

        // Extract photo URL from task data
        final photoUrl =
            task['photoUrl'] ?? task['proofImageUrl'] ?? task['imageUrl'] ?? task['photo'] ?? task['image'];

        // Apply completion filter
        if (_selectedCompletion == 'completed' && !completed) continue;
        if (_selectedCompletion == 'incomplete' && completed) continue;
        if (_selectedCompletion == 'incomplete_with_reason' && (completed || reason.toString().trim().isEmpty)) {
          continue;
        }

        // Apply search filter
        if (_searchTerm.isNotEmpty) {
          final searchMatch =
              taskName.toLowerCase().contains(_searchTerm) ||
              checklistName.toLowerCase().contains(_searchTerm) ||
              completedBy.toLowerCase().contains(_searchTerm) ||
              shiftName.toLowerCase().contains(_searchTerm);
          if (!searchMatch) continue;
        }

        // Create display name for user
        String displayUserName = completedBy;
        if (displayUserName.isEmpty) {
          if (startedByUserId.isNotEmpty) {
            displayUserName = 'User $startedByUserId';
          } else {
            displayUserName = 'Unknown User';
          }
        }

        allTasks.add({
          'taskName': taskName,
          'checklistName': checklistName,
          'userName': displayUserName,
          'userId': completedBy.isNotEmpty ? completedBy : startedByUserId,
          'shiftName': shiftName,
          'shiftId': shiftId,
          'completed': completed,
          'timestamp': finalTimestamp,
          'date': date,
          'taskIndex': i,
          'checklistId': doc.id,
          'locationId': locationId,
          'taskId': task['id'] ?? task['taskId'] ?? 'task_$i',
          'reason': reason,
          'photoUrl': photoUrl, // Add photo URL to task data
        });
      }
    }

    debugPrint('Total tasks after filtering: ${allTasks.length}');
    debugPrint('Selected shift: $_selectedShift');
    if (_selectedShift != 'all') {
      final shiftTasks = allTasks.where((task) => task['shiftId'] == _selectedShift).length;
      debugPrint('Tasks matching selected shift: $shiftTasks');
    }

    // Sort by timestamp (most recent first)
    allTasks.sort((a, b) {
      final aTime = a['timestamp'];
      final bTime = b['timestamp'];

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      if (aTime is DateTime && bTime is DateTime) {
        return bTime.compareTo(aTime);
      }

      return 0;
    });

    return allTasks;
  }

  Widget _buildAuditResultItem(Map<String, dynamic> data) {
    final userName = data['userName'] ?? 'Unknown User';
    final taskName = data['taskName'] ?? 'Unnamed Task';
    final checklistName = data['checklistName'] ?? 'Unnamed Checklist';
    final shiftName = data['shiftName'] ?? 'Unknown Shift';
    final completed = data['completed'] == true;
    final timestamp = data['timestamp']; // This is already a DateTime object
    final date = data['date'] ?? 'Unknown Date';
    final photoUrl = data['photoUrl'];
    final reason = data['reason'] ?? '';

    // Handle timestamp properly - it's already a DateTime object from _filterAuditResults
    String time = 'Unknown Time';
    String displayDate = date;

    if (timestamp != null && timestamp is DateTime) {
      time = DateFormat('HH:mm').format(timestamp);
      displayDate = DateFormat('MMM d').format(timestamp);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // User avatar or initials
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Task info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(taskName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Checklist: $checklistName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('Shift: $shiftName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('By: $userName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('Date: $displayDate $time', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      // Show reason if task is incomplete and has a reason
                      if (!completed && reason.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Reason: $reason',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
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
                // Action buttons row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Completion status
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: completed ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        completed ? 'Completed' : 'Incomplete',
                        style: TextStyle(
                          color: completed ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // Photo viewing button - only show if photo exists and task is completed
                    if (photoUrl != null && photoUrl.toString().isNotEmpty && completed)
                      Container(
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: IconButton(
                          icon: Icon(Icons.photo_camera, color: Colors.blue.shade700),
                          tooltip: 'View Task Photo',
                          onPressed: () => _showTaskPhotoDialog(photoUrl, taskName),
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add this new method to show photo in a dialog
  void _showTaskPhotoDialog(String photoUrl, String taskName) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_camera, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Task Photo: $taskName',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Photo content
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 3.0,
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                height: 300,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value:
                                            loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text('Loading photo...'),
                                    ],
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return SizedBox(
                                height: 300,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                                      const SizedBox(height: 16),
                                      const Text('Error loading image', style: TextStyle(fontSize: 16)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Please check your internet connection',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<Map<String, dynamic>> _calculateShiftPerformanceAnalytics() async {
    try {
      debugPrint('Starting shift performance analytics calculation for location: $_selectedLocationId');

      // Early return if no location selected
      if (_selectedLocationId == null) {
        debugPrint('No location selected, returning empty analytics');
        return {
          'topPerformers': <Map<String, dynamic>>[],
          'poorPerformers': <Map<String, dynamic>>[],
          'dayAnalysis': <Map<String, dynamic>>[],
        };
      }

      // Get data from the last 30 days using the new nested structure
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      List<QueryDocumentSnapshot> allChecklists = [];

      // Query specific location only (since we always have a location selected)
      var checklistsQuery = FirestoreEnforcer.instance
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('locations')
          .doc(_selectedLocationId!)
          .collection('daily_checklists')
          .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate))
          .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate))
          .limit(500);

      final checklistsQueryResult = await checklistsQuery.get();
      allChecklists = checklistsQueryResult.docs;

      final checklists = allChecklists;

      debugPrint('Found ${checklists.length} checklists for analytics');
      debugPrint('Available shifts: ${_shifts.length} (${_shifts.map((s) => s['name']).join(', ')})');

      if (checklists.isEmpty) {
        debugPrint('No checklists found for performance analytics');
        return {
          'topPerformers': <Map<String, dynamic>>[],
          'poorPerformers': <Map<String, dynamic>>[],
          'dayAnalysis': <Map<String, dynamic>>[],
        };
      }

      // Group data by shift
      Map<String, List<Map<String, dynamic>>> shiftData = {};
      Map<String, Map<String, List<double>>> dayOfWeekData = {}; // shiftId -> dayOfWeek -> completion rates

      for (final doc in checklists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final shiftId = data['shiftId'] as String?;
        final dateStr = data['date'] as String?;

        if (shiftId == null || dateStr == null) continue;

        // Calculate completion rate - handle multiple possible task completion fields
        final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
        final totalTasks = tasks.length;

        if (totalTasks == 0) continue; // Skip checklists with no tasks

        if (totalTasks == 0) continue; // Skip checklists with no tasks

        final completedTasks =
            tasks.where((t) => t['completed'] == true || t['isCompleted'] == true || t['status'] == 'completed').length;

        final completionRate = completedTasks / totalTasks;

        debugPrint(
          'Checklist ${doc.id}: $completedTasks/$totalTasks tasks completed (${(completionRate * 100).round()}%)',
        );

        // Group by shift
        shiftData.putIfAbsent(shiftId, () => []);
        shiftData[shiftId]!.add({'date': dateStr, 'completionRate': completionRate});

        // Group by day of week
        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          final dayOfWeek = DateFormat('EEEE').format(date);

          dayOfWeekData.putIfAbsent(shiftId, () => {});
          dayOfWeekData[shiftId]!.putIfAbsent(dayOfWeek, () => []);
          dayOfWeekData[shiftId]![dayOfWeek]!.add(completionRate);
        } catch (e) {
          debugPrint('Error parsing date $dateStr: $e');
        }
      }

      debugPrint('Grouped data by ${shiftData.length} shifts');

      // Calculate average performance for each shift
      List<Map<String, dynamic>> shiftPerformances = [];
      for (final shiftId in shiftData.keys) {
        final performances = shiftData[shiftId]!;
        if (performances.isEmpty) continue;

        final avgCompletionRate =
            performances.map((p) => p['completionRate'] as double).reduce((a, b) => a + b) / performances.length;

        final totalSessions = performances.length;
        final shiftName =
            _shifts.isNotEmpty
                ? _shifts.firstWhere(
                  (s) => s['id'] == shiftId,
                  orElse: () => {'name': 'Unknown Shift ($shiftId)'},
                )['name']
                : 'Unknown Shift ($shiftId)';

        debugPrint('Shift $shiftName: ${(avgCompletionRate * 100).round()}% avg completion ($totalSessions sessions)');

        shiftPerformances.add({
          'shiftId': shiftId,
          'shiftName': shiftName,
          'avgCompletionRate': avgCompletionRate,
          'totalSessions': totalSessions,
          'performances': performances,
        });
      }

      // Sort by performance
      shiftPerformances.sort((a, b) => (b['avgCompletionRate'] as double).compareTo(a['avgCompletionRate'] as double));

      // Get top and poor performers
      final topPerformers = shiftPerformances.take(3).toList();
      final poorPerformers = shiftPerformances.reversed.take(3).toList().reversed.toList();

      debugPrint('Top performers: ${topPerformers.length}, Poor performers: ${poorPerformers.length}');

      // Calculate day-of-week analysis
      List<Map<String, dynamic>> dayAnalysis = [];
      for (final shiftId in dayOfWeekData.keys) {
        final shiftName =
            _shifts.isNotEmpty
                ? _shifts.firstWhere(
                  (s) => s['id'] == shiftId,
                  orElse: () => {'name': 'Unknown Shift ($shiftId)'},
                )['name']
                : 'Unknown Shift ($shiftId)';

        final dayData = dayOfWeekData[shiftId]!;
        List<Map<String, dynamic>> dayPerformances = [];

        for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']) {
          if (dayData.containsKey(day) && dayData[day]!.isNotEmpty) {
            final rates = dayData[day]!;
            final avgRate = rates.reduce((a, b) => a + b) / rates.length;
            dayPerformances.add({'day': day, 'avgCompletionRate': avgRate, 'sessionCount': rates.length});
          }
        }

        // Find the worst performing day for this shift
        if (dayPerformances.isNotEmpty) {
          dayPerformances.sort(
            (a, b) => (a['avgCompletionRate'] as double).compareTo(b['avgCompletionRate'] as double),
          );

          final worstDay = dayPerformances.first;
          if ((worstDay['avgCompletionRate'] as double) < 0.8) {
            // Less than 80%
            dayAnalysis.add({
              'shiftId': shiftId,
              'shiftName': shiftName,
              'worstDay': worstDay['day'],
              'worstDayRate': worstDay['avgCompletionRate'],
              'worstDaySessionCount': worstDay['sessionCount'],
              'allDayPerformances': dayPerformances,
            });
          }
        }
      }

      debugPrint(
        'Analytics complete: ${topPerformers.length} top, ${poorPerformers.length} poor, ${dayAnalysis.length} day issues',
      );

      return {'topPerformers': topPerformers, 'poorPerformers': poorPerformers, 'dayAnalysis': dayAnalysis};
    } catch (e, stackTrace) {
      debugPrint('Error in _calculateShiftPerformanceAnalytics: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'topPerformers': <Map<String, dynamic>>[],
        'poorPerformers': <Map<String, dynamic>>[],
        'dayAnalysis': <Map<String, dynamic>>[],
      };
    }
  }

  void _showDayAnalysisDetails(Map<String, dynamic> analysis) {
    final allDayPerformances = analysis['allDayPerformances'] as List<Map<String, dynamic>>;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${analysis['shiftName']} - Weekly Performance'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Performance by Day of Week',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...allDayPerformances.map(
                    (dayPerf) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(flex: 2, child: Text(dayPerf['day'])),
                          Expanded(
                            flex: 3,
                            child: LinearProgressIndicator(
                              value: dayPerf['avgCompletionRate'],
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                dayPerf['avgCompletionRate'] < 0.8
                                    ? Colors.red
                                    : dayPerf['avgCompletionRate'] < 0.9
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(dayPerf['avgCompletionRate'] * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
          ),
    );
  }

  Widget _buildHistoricInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'Historic missed task insights (30 days)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 32, // Account for padding
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.withValues(alpha: 0.1), Colors.purple.withValues(alpha: 0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Top 3 Frequently Missed Tasks',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.purple[700]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loadingFrequent)
                const Center(child: CircularProgressIndicator())
              else if (_frequentMisses30d.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: Colors.green[300]),
                        const SizedBox(height: 8),
                        Text('Excellent! No frequently missed tasks.', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                )
              else
                ...(_frequentMisses30d.take(3).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final task = entry.value;
                  final position = index + 1;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: _getPositionColor(position), shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              '$position',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task['taskName'] ?? 'Unknown Task',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (task['shiftName'] != null)
                                Text(
                                  task['shiftName'],
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                '${task['count']} times',
                                style: TextStyle(color: Colors.red[700], fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_calculateMissRate(task)}% miss rate',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                })),
              if (_frequentMisses30d.length > 3) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _openAllFrequentMisses,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('View detailed analytics'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _getPositionColor(int position) {
    switch (position) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  int _calculateMissRate(Map<String, dynamic> task) {
    final missCount = task['count'] as int? ?? 0;
    final totalOccurrences = task['totalOccurrences'] as int? ?? missCount;
    if (totalOccurrences == 0) return 0;
    return ((missCount / totalOccurrences) * 100).round();
  }

  void _openAllFrequentMisses() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            minChildSize: 0.6,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Frequently Missed Tasks (30 days)',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _frequentMisses30d.length,
                          itemBuilder: (context, index) {
                            final task = _frequentMisses30d[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getPositionColor(index + 1),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(task['taskName'] ?? 'Unknown Task'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (task['shiftName'] != null) Text(task['shiftName']),
                                    Text('${_calculateMissRate(task)}% miss rate'),
                                  ],
                                ),
                                trailing: Chip(label: Text('${task['count']} times'), backgroundColor: Colors.red[100]),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}
