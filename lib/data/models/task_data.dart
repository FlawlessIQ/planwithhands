import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/timestamp_converter.dart';

part 'task_data.freezed.dart';
part 'task_data.g.dart';

@freezed
class TaskData with _$TaskData {
  factory TaskData({
    // Identity
    required String taskId,
    required String taskName,

    // Timestamps
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() required DateTime dueDate,

    // Status
    @Default(false) bool completed,
    @Default(false) bool photoRequired,

    // Completion metadata
    String? completedBy,
    String? completedByUserId,
    String? completedByUserName,
    String? completedByUserEmail,
    @TimestampConverter() DateTime? completedAt,

    // Content
    String? notes,
    String? photoUrl, // Canonical image field
    String? proofImageUrl, // Legacy alias (kept for compatibility)
    String? description, // Legacy/aux text for migration
    String? notCompletedReason,

    // Carry-forward fields
    @Default(false) bool isCarryForward,
    @TimestampConverter() DateTime? originalDate,
    String? originalChecklistId,
    String? originalTaskId,
    @TimestampConverter() DateTime? carriedIntoDate,
    @Default(false) bool carryForwardAttempted,

    // Analytics / flags
    @Default(false) bool excludedFromMetrics,
    @Default(false) bool resolvedLate,
    @TimestampConverter() DateTime? resolvedAt,

    // Optional denormalized fields to enable collectionGroup queries
    String? organizationId,
    String? locationId,
    String? checklistId,
    String? checklistName,
    String? shiftId,
    String? templateId,
    String? dateString, // 'YYYY-MM-DD'
    // Display order
    int? order,
  }) = _TaskData;

  factory TaskData.fromJson(Map<String, dynamic> json) => _$TaskDataFromJson(json);
}
