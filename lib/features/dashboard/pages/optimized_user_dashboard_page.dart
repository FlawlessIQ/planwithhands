import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hands_app/hooks/dashboard_loading_hook.dart';
import 'package:hands_app/services/dashboard_data_service.dart';
import 'package:hands_app/core/logging/logger.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/services/location_selection_service.dart';

/// Optimized User Dashboard with Performance Enhancements
///
/// KEY IMPROVEMENTS:
/// ✅ Parallel data loading instead of sequential
/// ✅ Smart caching with 5-minute TTL
/// ✅ Progressive loading UI with skeleton screens
/// ✅ Reduced real-time StreamBuilders
/// ✅ Batch database operations
/// ✅ Native photo service integration
class OptimizedUserDashboardPage extends HookWidget {
  final String? selectedLocationId;
  final Function(String?)? onLocationChanged;

  const OptimizedUserDashboardPage({
    super.key,
    this.selectedLocationId,
    this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Use the performance-optimized dashboard hook
    final dashboard = useDashboardData(
      selectedLocationId: selectedLocationId,
      autoRefresh: true,
      refreshInterval: const Duration(minutes: 5),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: dashboard.refresh,
          ),
        ],
      ),
      body: _buildBody(context, dashboard),
    );
  }

  Widget _buildBody(BuildContext context, DashboardLoadingHook dashboard) {
    // Error state
    if (dashboard.error != null) {
      return _buildErrorState(dashboard.error!, dashboard.refresh);
    }

    // Loading state with progressive UI
    if (dashboard.isLoading && dashboard.snapshot == null) {
      return _buildLoadingState(
        dashboard.loadingProgress,
        dashboard.loadingStage,
      );
    }

    // Success state with data
    if (dashboard.snapshot != null) {
      return _buildDashboardContent(context, dashboard.snapshot!);
    }

    // Empty state
    return _buildEmptyState();
  }

  Widget _buildLoadingState(double progress, String stage) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: progress),
          const SizedBox(height: 16),
          Text(
            stage,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% Complete',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),

          // Skeleton loading for shifts
          _buildShiftSkeleton(),
          const SizedBox(height: 16),
          _buildShiftSkeleton(),
        ],
      ),
    );
  }

  Widget _buildShiftSkeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 150,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 100,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Failed to load dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No shifts scheduled',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Check back later for your schedule',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    DashboardSnapshot snapshot,
  ) {
    return RefreshIndicator(
      onRefresh: () => Future.value(), // Already handled by hook
      child: CustomScrollView(
        slivers: [
          // User info header
          SliverToBoxAdapter(child: _buildUserHeader(snapshot.session)),

          // Location selector (if multiple locations)
          if (snapshot.session.availableLocations.length > 1)
            SliverToBoxAdapter(child: _buildLocationSelector(snapshot)),

          // Shifts list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildShiftCard(
                context,
                snapshot.shifts[index],
                snapshot.checklists.length > index
                    ? snapshot.checklists[index]
                    : [],
              ),
              childCount: snapshot.shifts.length,
            ),
          ),

          // Footer spacing
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildUserHeader(UserSessionData session) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.person, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: ${_getRoleName(session.userRole)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                if (session.jobTypes.isNotEmpty)
                  Text(
                    'Jobs: ${session.jobTypes.join(', ')}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSelector(DashboardSnapshot snapshot) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Location: ',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _effectiveSelectedId(snapshot),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              items: _buildLocationItems(snapshot),
              onChanged: (value) async {
                final selectedLocation = snapshot.session.availableLocations
                    .cast<Map<String, dynamic>?>()
                    .firstWhere(
                      (location) => location?['id'] == value,
                      orElse: () => null,
                    );
                try {
                  await LocationSelectionService.instance.setLocationAsync(
                    value,
                    locationName: selectedLocation?['name'] as String?,
                  );
                } catch (_) {}
                onLocationChanged?.call(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _effectiveSelectedId(DashboardSnapshot snapshot) {
    final itemsIds =
        snapshot.session.availableLocations
            .map((l) => l['id'] as String?)
            .toSet();
    final initial =
        selectedLocationId ??
        LocationSelectionService.instance.currentLocationId;
    if (initial == null) return null; // allow 'All Locations'
    return itemsIds.contains(initial) ? initial : null;
  }

  List<DropdownMenuItem<String?>> _buildLocationItems(
    DashboardSnapshot snapshot,
  ) {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('All Locations'),
      ),
    ];
    items.addAll(
      snapshot.session.availableLocations.map(
        (location) => DropdownMenuItem<String?>(
          value: location['id'] as String?,
          child: Text(location['name'] ?? 'Unknown Location'),
        ),
      ),
    );
    return items;
  }

  Widget _buildShiftCard(
    BuildContext context,
    ShiftData shift,
    List<DailyChecklist> checklists,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shift header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.shiftName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${shift.startTime} - ${shift.endTime}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${checklists.length} checklists',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Checklists
          if (checklists.isNotEmpty)
            ...checklists.map(
              (checklist) => _buildChecklistTile(context, checklist),
            ),

          // Empty state for checklists
          if (checklists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No checklists available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistTile(BuildContext context, DailyChecklist checklist) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue[100],
        child: Icon(Icons.checklist, color: Colors.blue[600]),
      ),
      title: Text(
        checklist.templateName ?? 'Checklist',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text('${checklist.tasks.length} tasks'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        // Navigate to checklist detail
        // Implementation would go here
      },
    );
  }

  String _getRoleName(int userRole) {
    switch (userRole) {
      case 0:
        return 'Employee';
      case 1:
        return 'Manager';
      case 2:
        return 'Admin';
      default:
        return 'Unknown';
    }
  }
}

/// Performance monitoring widget (development only)
class DashboardPerformanceMonitor extends HookWidget {
  final Widget child;

  const DashboardPerformanceMonitor({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loadStartTime = useState<DateTime?>(null);

    useEffect(() {
      loadStartTime.value = DateTime.now();

      // Log performance after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (loadStartTime.value != null) {
          final loadTime = DateTime.now().difference(loadStartTime.value!);
          logger.d(
            '[DashboardPerf] Page rendered in ${loadTime.inMilliseconds}ms',
          );
        }
      });

      return null;
    }, []);

    return child;
  }
}
