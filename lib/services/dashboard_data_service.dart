import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/models/daily_checklist.dart';

/// High-performance dashboard data service with caching and parallel loading
class DashboardDataService {
  static final DashboardDataService _instance = DashboardDataService._internal();
  factory DashboardDataService() => _instance;
  DashboardDataService._internal();

  // Cache with TTL (Time To Live)
  final Map<String, CachedData> _cache = {};
  static const Duration _cacheTTL = Duration(minutes: 5);

  /// Cached user session data
  UserSessionData? _currentSession;

  /// Get or create user session with caching
  Future<UserSessionData> getUserSession({bool forceRefresh = false}) async {
    if (_currentSession != null && !forceRefresh) {
      return _currentSession!;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Validate session before proceeding with data fetch
    try {
      await user.getIdToken(true); // Force token refresh to ensure validity
    } catch (e) {
      logger.w('[DashboardData] Session validation failed: $e');
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        // Network issue - proceed but log warning
        logger.w('[DashboardData] Network issue during session validation, proceeding');
      } else {
        // Token genuinely invalid - throw exception
        throw Exception('Session expired - please sign in again');
      }
    }

    logger.d('[DashboardData] Loading user session for ${user.uid}');
    final stopwatch = Stopwatch()..start();

    try {
      // Parallel fetch user data and organization data
      final futures = await Future.wait([_fetchUserDocument(user.uid), _fetchUserLocations(user.uid)]);

      final userData = futures[0] as Map<String, dynamic>;
      final locations = futures[1] as List<Map<String, dynamic>>;

      _currentSession = UserSessionData(
        userId: user.uid,
        organizationId: userData['organizationId'],
        userRole: userData['userRole'] ?? 1,
        jobTypes: _coerceToJobTypes(userData['jobTypes'] ?? userData['jobType']),
        locationIds: _coerceToLocationIds(userData['locationIds'] ?? userData['locationId']),
        availableLocations: locations,
        loadedAt: DateTime.now(),
        schedulingEnabled: true, // Default to true
      );

      stopwatch.stop();
      logger.d('[DashboardData] User session loaded in ${stopwatch.elapsedMilliseconds}ms');

      return _currentSession!;
    } catch (e) {
      stopwatch.stop();
      logger.e('[DashboardData] Failed to load user session: $e');
      
      // Clear cached session on error
      _currentSession = null;
      
      // Re-throw with more context
      if (e.toString().contains('UNAUTHENTICATED') || e.toString().contains('permission-denied')) {
        throw Exception('Session expired - please sign in again');
      }
      rethrow;
    }
  }

  /// Load dashboard data with parallel processing and caching
  Future<DashboardSnapshot> loadDashboardData({String? selectedLocationId, bool forceRefresh = false}) async {
    logger.d('[DashboardData] Loading dashboard data');
    final stopwatch = Stopwatch()..start();

    // Get user session
    final session = await getUserSession(forceRefresh: forceRefresh);
    final todayString = DateTime.now().toIso8601String().split('T')[0];
    final todayDayName = _getTodayDayName();

    // Create cache key
    final cacheKey = 'dashboard_${session.userId}_${selectedLocationId ?? 'all'}_$todayString';

    // Check cache
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheTTL) {
        logger.d('[DashboardData] Returning cached dashboard data');
        return cached.data as DashboardSnapshot;
      }
    }

    // Parallel loading of independent data
    final futures = <Future>[];

    // 1. Load shifts for today
    futures.add(_loadShiftsOptimized(session, todayDayName, todayString, selectedLocationId));

    // 2. Load missed tasks (if needed)
    futures.add(_loadMissedTasksOptimized(session.organizationId!, selectedLocationId));

    // 3. Ensure daily checklists exist (background)
    futures.add(_ensureDailyChecklistsBackground(session.organizationId!));

    final results = await Future.wait(futures);
    final shifts = results[0] as List<ShiftData>;
    final missedTasks = results[1] as List<dynamic>; // MissedTasksSection
    // results[2] is background operation

    // Load checklists for shifts in parallel
    final checklistFutures =
        shifts
            .map(
              (shift) => _loadChecklistsOptimized(
                session.organizationId!,
                selectedLocationId ?? shift.locationIds.first,
                shift,
                todayString,
              ),
            )
            .toList();

    final allChecklists = await Future.wait(checklistFutures);

    final snapshot = DashboardSnapshot(
      session: session,
      shifts: shifts,
      checklists: allChecklists,
      missedTasks: missedTasks,
      loadedAt: DateTime.now(),
      selectedLocationId: selectedLocationId,
    );

    // Cache the result
    _cache[cacheKey] = CachedData(snapshot, DateTime.now());

    stopwatch.stop();
    logger.d('[DashboardData] Dashboard loaded in ${stopwatch.elapsedMilliseconds}ms');

    return snapshot;
  }

  /// Optimized shift loading with minimal queries
  Future<List<ShiftData>> _loadShiftsOptimized(
    UserSessionData session,
    String todayDayName,
    String todayString,
    String? selectedLocationId,
  ) async {
    if (!session.schedulingEnabled) return [];

    // Build location filter
    List<String> targetLocationIds;
    if (selectedLocationId != null) {
      targetLocationIds = [selectedLocationId];
    } else if (session.userRole == 2) {
      // Admin - use all available locations
      targetLocationIds = session.availableLocations.map((l) => l['id'] as String).toList();
    } else {
      targetLocationIds = session.locationIds;
    }

    if (targetLocationIds.isEmpty) return [];

    // Single optimized query for all shifts
    final shiftsQuery = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(session.organizationId)
        .collection('shifts')
        .where('isActive', isEqualTo: true)
        .where('dayOfWeek', isEqualTo: todayDayName);

    // Add location filter if not admin viewing all
    Query finalQuery = shiftsQuery;
    if (session.userRole != 2 || selectedLocationId != null) {
      finalQuery = shiftsQuery.where('locationIds', arrayContainsAny: targetLocationIds);
    }

    final snapshot = await finalQuery.get();
    final shifts =
        snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final shiftData = Map<String, dynamic>.from(data);
              shiftData['shiftId'] = doc.id;
              if (shiftData['createdAt'] == null) {
                shiftData['createdAt'] = DateTime.now().toIso8601String();
              }
              return ShiftData.fromJson(shiftData);
            })
            .where((shift) => _isShiftRelevantForUser(shift, session))
            .toList();

    shifts.sort((a, b) => a.startTime.compareTo(b.startTime));

    logger.d('[DashboardData] Loaded ${shifts.length} shifts optimized');
    return shifts;
  }

  /// Optimized checklist loading with batch operations
  Future<List<DailyChecklist>> _loadChecklistsOptimized(
    String organizationId,
    String locationId,
    ShiftData shift,
    String dateString,
  ) async {
    // Try to load existing checklists first
    final existing =
        await FirestoreEnforcer.instance
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .where('shiftId', isEqualTo: shift.shiftId)
            .where('date', isEqualTo: dateString)
            .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.map((doc) => DailyChecklist.fromMap(doc.data(), doc.id)).toList();
    }

    // Generate if needed (fallback)
    logger.d('[DashboardData] Generating checklists for shift ${shift.shiftName}');
    // This would call the existing generation logic
    return []; // Placeholder - integrate with existing DailyChecklistService
  }

  /// Optimized missed tasks loading
  Future<List<dynamic>> _loadMissedTasksOptimized(String organizationId, String? locationId) async {
    // Implement optimized missed tasks loading
    // This can be done with batch queries and caching
    return []; // Placeholder
  }

  /// Background operation for ensuring daily checklists
  Future<void> _ensureDailyChecklistsBackground(String organizationId) async {
    // Run this in background without blocking UI
    try {
      // Call existing service but don't await in main loading flow
      // DailyChecklistService().ensureDailyChecklistsExist(organizationId);
    } catch (e) {
      logger.e('[DashboardData] Background checklist ensure failed: $e');
    }
  }

  /// Clear cache for fresh data
  void clearCache() {
    _cache.clear();
    _currentSession = null;
  }

  /// Utility methods
  Future<Map<String, dynamic>> _fetchUserDocument(String userId) async {
    final doc = await FirestoreEnforcer.instance.collection('users').doc(userId).get();
    if (!doc.exists) throw Exception('User document not found');
    return doc.data()!;
  }

  Future<List<Map<String, dynamic>>> _fetchUserLocations(String userId) async {
    // This would integrate with existing location loading logic
    return []; // Placeholder
  }

  bool _isShiftRelevantForUser(ShiftData shift, UserSessionData session) {
    // Check job type compatibility
    if (session.jobTypes.isNotEmpty) {
      final shiftJobTypes = _coerceToJobTypes(shift.jobType);
      if (shiftJobTypes.isNotEmpty && !shiftJobTypes.any((jt) => session.jobTypes.contains(jt))) {
        return false;
      }
    }
    return true;
  }

  List<String> _coerceToJobTypes(dynamic input) {
    if (input == null) return [];
    if (input is String) return [input];
    if (input is List) return input.cast<String>();
    return [];
  }

  List<String> _coerceToLocationIds(dynamic input) {
    if (input == null) return [];
    if (input is String) return [input];
    if (input is List) return input.cast<String>();
    return [];
  }

  String _getTodayDayName() {
    return ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][DateTime.now().weekday % 7];
  }
}

/// User session data with caching
class UserSessionData {
  final String userId;
  final String? organizationId;
  final int userRole;
  final List<String> jobTypes;
  final List<String> locationIds;
  final List<Map<String, dynamic>> availableLocations;
  final DateTime loadedAt;
  final bool schedulingEnabled;

  UserSessionData({
    required this.userId,
    required this.organizationId,
    required this.userRole,
    required this.jobTypes,
    required this.locationIds,
    required this.availableLocations,
    required this.loadedAt,
    this.schedulingEnabled = true,
  });
}

/// Complete dashboard snapshot
class DashboardSnapshot {
  final UserSessionData session;
  final List<ShiftData> shifts;
  final List<List<DailyChecklist>> checklists;
  final List<dynamic> missedTasks;
  final DateTime loadedAt;
  final String? selectedLocationId;

  DashboardSnapshot({
    required this.session,
    required this.shifts,
    required this.checklists,
    required this.missedTasks,
    required this.loadedAt,
    this.selectedLocationId,
  });
}

/// Cached data with timestamp
class CachedData {
  final dynamic data;
  final DateTime timestamp;

  CachedData(this.data, this.timestamp);
}
