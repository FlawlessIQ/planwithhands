import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/services/daily_checklist_service.dart';

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
