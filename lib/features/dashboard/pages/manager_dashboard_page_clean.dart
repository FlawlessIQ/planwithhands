import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:hands_app/global_widgets/bottom_nav_bar.dart';
import 'package:hands_app/global_widgets/generic_app_bar_content.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:intl/intl.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

// Service provider for DailyChecklistService
final dailyChecklistServiceProvider = Provider<DailyChecklistService>((ref) {
  return DailyChecklistService();
});

// Analytics models for manager dashboard
class ShiftPerformance {
  final String shiftId;
  final String shiftName;
  final String role;
  final String startTime;
  final String endTime;
  final int completedTasks;
  final int totalTasks;
  final int carryForwardCompleted;
  final int carryForwardTotal;
  final String timeStatus;

  double get completionPct => totalTasks > 0 ? completedTasks / totalTasks : 0.0;

  ShiftPerformance({
    required this.shiftId,
    required this.shiftName,
    required this.role,
    required this.startTime,
    required this.endTime,
    required this.completedTasks,
    required this.totalTasks,
    required this.carryForwardCompleted,
    required this.carryForwardTotal,
    required this.timeStatus,
  });
}

class DailyAnalytics {
  final String date;
  final int totalTasks;
  final int completedTasks;
  final double completionRate;

  DailyAnalytics({required this.date, required this.totalTasks, required this.completedTasks})
    : completionRate = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
}

/// Generate deterministic checklist ID for subcollection operations
String _generateChecklistId({
  required String organizationId,
  required String locationId,
  required String shiftId,
  required String templateId,
  required String dateString,
}) {
  return "${organizationId}_${locationId}_${shiftId}_${templateId}_$dateString";
}

class ManagerDashboardPage extends HookConsumerWidget {
  final String organizationId;
  const ManagerDashboardPage({super.key, required this.organizationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // State management using hooks
    final userRole = useState<int?>(null);
    final isLoadingUserRole = useState(true);
    final selectedLocationId = useState<String?>(null);
    final selectedLocationName = useState<String?>(null);
    final availableLocations = useState<List<Map<String, dynamic>>>([]);
    final isLoadingLocations = useState(true);

    // Filter states
    final selectedRoleFilter = useState<String>('all');
    final availableRoles = useState<List<String>>(['all']);

    // Audit filter states
    final searchTerm = useState<String>('');
    final selectedShift = useState<String>('all');
    final selectedChecklist = useState<String>('all');
    final selectedCompletion = useState<String>('all');
    final selectedDateRange = useState<DateTimeRange?>(null);
    final shifts = useState<List<Map<String, String>>>([]);
    final checklists = useState<List<Map<String, String>>>([]);
    final auditItemsToShow = useState<int>(10);

    // Get service
    final service = ref.read(dailyChecklistServiceProvider);
    final dateFormat = DateFormat('yyyy-MM-dd');
    final todayKey = dateFormat.format(DateTime.now());

    // Fetch user role effect
    useEffect(() {
      Future<void> fetchUserRole() async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          isLoadingUserRole.value = false;
          return;
        }

        try {
          final userDoc = await FirestoreEnforcer.instance.collection('users').doc(user.uid).get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final roles = userData['roles'] as Map<String, dynamic>?;

            if (roles != null && roles[organizationId] != null) {
              final role = roles[organizationId] as String;
              userRole.value = role == 'admin' ? 2 : (role == 'manager' ? 1 : 0);
            } else {
              userRole.value = userData['userRole'] as int? ?? 0;
            }
          }
        } catch (e) {
          debugPrint('[ManagerDashboard] Error fetching user role: $e');
          userRole.value = 0;
        }

        isLoadingUserRole.value = false;
      }

      fetchUserRole();
      return null;
    }, []);

    // Load locations effect
    useEffect(() {
      Future<void> loadLocations() async {
        try {
          final snapshot =
              await FirestoreEnforcer.instance
                  .collection('organizations')
                  .doc(organizationId)
                  .collection('locations')
                  .get();

          final locations =
              snapshot.docs
                  .map((doc) => {'id': doc.id, 'name': doc.data()['locationName'] as String? ?? 'Unknown Location'})
                  .toList();

          availableLocations.value = locations;

          if (locations.isNotEmpty) {
            selectedLocationId.value = locations.first['id'];
            selectedLocationName.value = locations.first['name'];
          }
        } catch (e) {
          debugPrint('[ManagerDashboard] Error loading locations: $e');
        }

        isLoadingLocations.value = false;
      }

      loadLocations();
      return null;
    }, []);

    // Auto-generate daily checklists effect
    useEffect(() {
      if (selectedLocationId.value != null) {
        Future<void> ensureDailyChecklistsExist() async {
          try {
            await service.ensureDailyChecklistsExist(organizationId);
          } catch (e) {
            debugPrint('[ManagerDashboard] Error ensuring daily checklists: $e');
          }
        }

        ensureDailyChecklistsExist();
      }
      return null;
    }, [selectedLocationId.value]);

    if (isLoadingLocations.value || isLoadingUserRole.value) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manager Dashboard'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBar: BottomNavBar(currentIndex: 1, userRole: userRole.value),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: GenericAppBarContent(appBarTitle: 'Manager Dashboard', userRole: userRole.value),
        automaticallyImplyLeading: false,
        foregroundColor: Colors.white,
        actions: [
          // Compact location selector for mobile
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              enabled: availableLocations.value.isNotEmpty,
              onSelected: (value) {
                selectedLocationId.value = value;
                selectedLocationName.value = availableLocations.value.firstWhere((loc) => loc['id'] == value)['name'];
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      selectedLocationName.value ?? 'Select Location',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                  ],
                ),
              ),
              itemBuilder:
                  (context) =>
                      availableLocations.value
                          .map(
                            (location) => PopupMenuItem<String>(value: location['id'], child: Text(location['name'])),
                          )
                          .toList(),
            ),
          ),
          UnifiedMenuButton(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 1, userRole: userRole.value),
      body:
          selectedLocationId.value == null
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No location selected', style: TextStyle(fontSize: 18)),
                  ],
                ),
              )
              : _ManagerDashboardContent(
                organizationId: organizationId,
                locationId: selectedLocationId.value!,
                locationName: selectedLocationName.value!,
                selectedRoleFilter: selectedRoleFilter,
                availableRoles: availableRoles,
                searchTerm: searchTerm,
                selectedShift: selectedShift,
                selectedChecklist: selectedChecklist,
                selectedCompletion: selectedCompletion,
                selectedDateRange: selectedDateRange,
                shifts: shifts,
                checklists: checklists,
                auditItemsToShow: auditItemsToShow,
              ),
    );
  }
}

class _ManagerDashboardContent extends HookConsumerWidget {
  final String organizationId;
  final String locationId;
  final String locationName;
  final ValueNotifier<String> selectedRoleFilter;
  final ValueNotifier<List<String>> availableRoles;
  final ValueNotifier<String> searchTerm;
  final ValueNotifier<String> selectedShift;
  final ValueNotifier<String> selectedChecklist;
  final ValueNotifier<String> selectedCompletion;
  final ValueNotifier<DateTimeRange?> selectedDateRange;
  final ValueNotifier<List<Map<String, String>>> shifts;
  final ValueNotifier<List<Map<String, String>>> checklists;
  final ValueNotifier<int> auditItemsToShow;

  const _ManagerDashboardContent({
    required this.organizationId,
    required this.locationId,
    required this.locationName,
    required this.selectedRoleFilter,
    required this.availableRoles,
    required this.searchTerm,
    required this.selectedShift,
    required this.selectedChecklist,
    required this.selectedCompletion,
    required this.selectedDateRange,
    required this.shifts,
    required this.checklists,
    required this.auditItemsToShow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(dailyChecklistServiceProvider);
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh will be handled by stream rebuilds
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(locationName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Live Performance • ${DateFormat('EEEE, MMM d').format(DateTime.now())}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Live Shifts Performance Section
            _LiveShiftsSection(
              organizationId: organizationId,
              locationId: locationId,
              selectedRoleFilter: selectedRoleFilter,
              availableRoles: availableRoles,
            ),

            const SizedBox(height: 32),

            // Missed Yesterday Section
            _MissedYesterdaySection(organizationId: organizationId, locationId: locationId),

            const SizedBox(height: 32),

            // Historic Trends Section (7-14 days)
            _HistoricTrendsSection(organizationId: organizationId, locationId: locationId),

            const SizedBox(height: 32),

            // Audit Section (existing functionality with updated filters)
            _AuditSection(
              organizationId: organizationId,
              locationId: locationId,
              searchTerm: searchTerm,
              selectedShift: selectedShift,
              selectedChecklist: selectedChecklist,
              selectedCompletion: selectedCompletion,
              selectedDateRange: selectedDateRange,
              shifts: shifts,
              checklists: checklists,
              auditItemsToShow: auditItemsToShow,
            ),
          ],
        ),
      ),
    );
  }
}

// Now I need to implement the missing section widgets
class _LiveShiftsSection extends HookConsumerWidget {
  final String organizationId;
  final String locationId;
  final ValueNotifier<String> selectedRoleFilter;
  final ValueNotifier<List<String>> availableRoles;

  const _LiveShiftsSection({
    required this.organizationId,
    required this.locationId,
    required this.selectedRoleFilter,
    required this.availableRoles,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Shifts Performance',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Real-time subcollection streaming implementation coming...'),
          ],
        ),
      ),
    );
  }
}

class _MissedYesterdaySection extends HookConsumerWidget {
  final String organizationId;
  final String locationId;

  const _MissedYesterdaySection({required this.organizationId, required this.locationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Missed Yesterday',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            const Text('Yesterday\'s missed tasks implementation coming...'),
          ],
        ),
      ),
    );
  }
}

class _HistoricTrendsSection extends HookConsumerWidget {
  final String organizationId;
  final String locationId;

  const _HistoricTrendsSection({required this.organizationId, required this.locationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Trends (7-14 days)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Historic analytics with collectionGroup queries coming...'),
          ],
        ),
      ),
    );
  }
}

class _AuditSection extends HookConsumerWidget {
  final String organizationId;
  final String locationId;
  final ValueNotifier<String> searchTerm;
  final ValueNotifier<String> selectedShift;
  final ValueNotifier<String> selectedChecklist;
  final ValueNotifier<String> selectedCompletion;
  final ValueNotifier<DateTimeRange?> selectedDateRange;
  final ValueNotifier<List<Map<String, String>>> shifts;
  final ValueNotifier<List<Map<String, String>>> checklists;
  final ValueNotifier<int> auditItemsToShow;

  const _AuditSection({
    required this.organizationId,
    required this.locationId,
    required this.searchTerm,
    required this.selectedShift,
    required this.selectedChecklist,
    required this.selectedCompletion,
    required this.selectedDateRange,
    required this.shifts,
    required this.checklists,
    required this.auditItemsToShow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audit & Detailed Reports',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Enhanced audit section with subcollection filtering coming...'),
          ],
        ),
      ),
    );
  }
}
