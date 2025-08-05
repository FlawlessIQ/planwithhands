import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/models/daily_checklist.dart';

part 'missed_tasks_section.freezed.dart';

/// Model for organizing missed tasks by their original shift context
@freezed
class MissedTasksSection with _$MissedTasksSection {
  factory MissedTasksSection({
    required String shiftId,
    required String shiftName,
    @TimeOfDayConverter() TimeOfDay? startTime,
    @TimeOfDayConverter() TimeOfDay? endTime,
    required List<DailyChecklistTask> tasks,
    @Default(false) bool isExpanded,
    String? locationId,
    String? checklistId,
  }) = _MissedTasksSection;
}

/// Custom JSON converter for TimeOfDay since it's not directly serializable
class TimeOfDayConverter implements JsonConverter<TimeOfDay?, Map<String, dynamic>?> {
  const TimeOfDayConverter();

  @override
  TimeOfDay? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return TimeOfDay(
      hour: json['hour'] as int,
      minute: json['minute'] as int,
    );
  }

  @override
  Map<String, dynamic>? toJson(TimeOfDay? object) {
    if (object == null) return null;
    return {
      'hour': object.hour,
      'minute': object.minute,
    };
  }
}
