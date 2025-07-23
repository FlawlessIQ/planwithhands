import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/timestamp_converter.dart';

part 'daily_checklist.freezed.dart';
part 'daily_checklist.g.dart';

@freezed
class DailyChecklist with _$DailyChecklist {
  factory DailyChecklist({
    required String id,
    required String organizationId,
    required String locationId,
    required String shiftId,
    required String templateId,
    required String templateName,
    required String date, // YYYY-MM-DD format
    @Default([]) List<DailyTask> tasks,
    @Default(false) bool isCompleted,
    String? completedBy,
    @TimestampConverter() DateTime? completedAt,
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _DailyChecklist;

  factory DailyChecklist.fromJson(Map<String, Object?> json) =>
      _$DailyChecklistFromJson(json);
}

@freezed
class DailyTask with _$DailyTask {
  factory DailyTask({
    required String id,
    required String title,
    String? description,
    @Default(false) bool completed,
    @Default(0) int order,
    String? completedBy,
    @TimestampConverter() DateTime? completedAt,
    String? notes,
    String? proofImageUrl,
  }) = _DailyTask;

  factory DailyTask.fromJson(Map<String, Object?> json) =>
      _$DailyTaskFromJson(json);
}