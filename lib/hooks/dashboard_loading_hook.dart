import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hands_app/services/dashboard_data_service.dart';
import 'package:hands_app/core/logging/logger.dart';

/// Progressive loading hook for dashboard data
/// Implements staged loading with caching for optimal performance
class DashboardLoadingHook {
  final DashboardSnapshot? snapshot;
  final bool isLoading;
  final String? error;
  final double loadingProgress;
  final String loadingStage;
  final VoidCallback refresh;
  final VoidCallback clearCache;
  
  const DashboardLoadingHook({
    this.snapshot,
    this.isLoading = false,
    this.error,
    this.loadingProgress = 0.0,
    this.loadingStage = '',
    required this.refresh,
    required this.clearCache,
  });
}

/// Use dashboard data with progressive loading and caching
DashboardLoadingHook useDashboardData({
  String? selectedLocationId,
  bool autoRefresh = true,
  Duration refreshInterval = const Duration(minutes: 5),
}) {
  final snapshot = useState<DashboardSnapshot?>(null);
  final isLoading = useState(false);
  final error = useState<String?>(null);
  final loadingProgress = useState(0.0);
  final loadingStage = useState('');
  
  final dashboardService = useMemoized(() => DashboardDataService());

  Future<void> loadDashboardData() async {
    if (isLoading.value) return;
    
    isLoading.value = true;
    error.value = null;
    loadingProgress.value = 0.0;
    loadingStage.value = 'Initializing...';
    
    try {
      // Stage 1: Load user session (20%)
      loadingStage.value = 'Loading user session...';
      await dashboardService.getUserSession();
      loadingProgress.value = 0.2;
      
      // Stage 2: Load dashboard data (80%)
      loadingStage.value = 'Loading dashboard data...';
      final dashboardSnapshot = await dashboardService.loadDashboardData(
        selectedLocationId: selectedLocationId,
      );
      loadingProgress.value = 1.0;
      loadingStage.value = 'Complete';
      
      snapshot.value = dashboardSnapshot;
      
    } catch (e) {
      logger.e('[DashboardHook] Load failed: $e');
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // Auto-refresh timer
  useEffect(() {
    if (!autoRefresh) return null;
    
    final timer = Stream.periodic(refreshInterval).listen((_) async {
      if (!isLoading.value) {
        await loadDashboardData();
      }
    });
    
    return timer.cancel;
  }, [autoRefresh, refreshInterval]);

  // Initial load
  useEffect(() {
    loadDashboardData();
    return null;
  }, [selectedLocationId]);

  // Provide refresh function
  final refresh = useCallback(() => loadDashboardData(), [selectedLocationId]);

  // Clear cache function
  final clearCache = useCallback(() {
    dashboardService.clearCache();
    snapshot.value = null;
  }, []);

  return DashboardLoadingHook(
    snapshot: snapshot.value,
    isLoading: isLoading.value,
    error: error.value,
    loadingProgress: loadingProgress.value,
    loadingStage: loadingStage.value,
    refresh: refresh,
    clearCache: clearCache,
  );
}
