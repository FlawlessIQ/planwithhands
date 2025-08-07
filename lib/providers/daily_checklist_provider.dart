import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/services/daily_checklist_service.dart';
import 'package:hands_app/data/models/missed_tasks_section.dart';

final dailyChecklistServiceProvider = Provider<DailyChecklistService>((ref) {
  return DailyChecklistService();
});

// Simplified provider for completion stats - used by admin dashboards
final completionStatsProvider =
    FutureProvider.family<Map<String, dynamic>, CompletionStatsParams>((
      ref,
      params,
    ) {
      final service = ref.watch(dailyChecklistServiceProvider);
      return service.getCompletionStats(
        organizationId: params.organizationId,
        startDate: params.startDate,
        endDate: params.endDate,
        locationId: params.locationId,
      );
    });

// Provider for missed tasks sections
final missedTasksProvider =
    FutureProvider.family<List<MissedTasksSection>, MissedTasksParams>((
      ref,
      params,
    ) async {
      final service = ref.watch(dailyChecklistServiceProvider);
      
      // First ensure carry-forward has been attempted for today
      try {
        await service.carryForwardMissedTasks(
          organizationId: params.organizationId,
          targetDate: params.targetDate,
        );
      } catch (e) {
        // Log but don't fail if carry-forward fails
        debugPrint('Error during carry-forward: $e');
      }
      
      return service.loadMissedTasksForToday(
        organizationId: params.organizationId,
        targetDate: params.targetDate,
        locationId: params.locationId,
      );
    });

// Provider for frequently missed tasks insights
final frequentlyMissedTasksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, FrequentlyMissedTasksParams>((
      ref,
      params,
    ) {
      final service = ref.watch(dailyChecklistServiceProvider);
      return service.getFrequentlyMissedTasks(
        organizationId: params.organizationId,
        locationId: params.locationId,
        days: params.rollingDays,
      );
    });

class CompletionStatsParams {
  final String organizationId;
  final DateTime startDate;
  final DateTime endDate;
  final String? locationId;

  const CompletionStatsParams({
    required this.organizationId,
    required this.startDate,
    required this.endDate,
    this.locationId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompletionStatsParams &&
        other.organizationId == organizationId &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.locationId == locationId;
  }

  @override
  int get hashCode {
    return organizationId.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        locationId.hashCode;
  }
}

class MissedTasksParams {
  final String organizationId;
  final DateTime targetDate;
  final String? locationId;

  const MissedTasksParams({
    required this.organizationId,
    required this.targetDate,
    this.locationId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MissedTasksParams &&
        other.organizationId == organizationId &&
        other.targetDate == targetDate &&
        other.locationId == locationId;
  }

  @override
  int get hashCode {
    return organizationId.hashCode ^
        targetDate.hashCode ^
        locationId.hashCode;
  }
}

class FrequentlyMissedTasksParams {
  final String organizationId;
  final String? locationId;
  final int rollingDays;

  const FrequentlyMissedTasksParams({
    required this.organizationId,
    this.locationId,
    this.rollingDays = 30,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FrequentlyMissedTasksParams &&
        other.organizationId == organizationId &&
        other.locationId == locationId &&
        other.rollingDays == rollingDays;
  }

  @override
  int get hashCode {
    return organizationId.hashCode ^
        locationId.hashCode ^
        rollingDays.hashCode;
  }
}
