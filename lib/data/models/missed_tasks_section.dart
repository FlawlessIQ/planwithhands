import 'package:flutter/material.dart';
import 'package:hands_app/data/models/task_data.dart';
import 'package:json_annotation/json_annotation.dart';

/// Model for organizing missed tasks by their original shift context
class MissedTasksSection {
  final String shiftId;
  final String shiftName;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<TaskData> tasks;
  final bool isExpanded;
  final String? locationId;
  final String? checklistId;
  final String? checklistName;
  final String organizationId;

  const MissedTasksSection({
    required this.shiftId,
    required this.shiftName,
    required this.organizationId,
    this.startTime,
    this.endTime,
    required this.tasks,
    this.isExpanded = false,
    this.locationId,
    this.checklistId,
    this.checklistName,
  });

  MissedTasksSection copyWith({
    String? shiftId,
    String? shiftName,
    String? organizationId,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<TaskData>? tasks,
    bool? isExpanded,
    String? locationId,
    String? checklistId,
    String? checklistName,
  }) {
    return MissedTasksSection(
      shiftId: shiftId ?? this.shiftId,
      shiftName: shiftName ?? this.shiftName,
      organizationId: organizationId ?? this.organizationId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      tasks: tasks ?? this.tasks,
      isExpanded: isExpanded ?? this.isExpanded,
      locationId: locationId ?? this.locationId,
      checklistId: checklistId ?? this.checklistId,
      checklistName: checklistName ?? this.checklistName,
    );
  }

  factory MissedTasksSection.fromJson(Map<String, dynamic> json) {
    return MissedTasksSection(
      shiftId: json['shiftId'] as String,
      shiftName: json['shiftName'] as String,
      organizationId: json['organizationId'] as String,
      startTime: const TimeOfDayConverter().fromJson(json['startTime'] as Map<String, dynamic>?),
      endTime: const TimeOfDayConverter().fromJson(json['endTime'] as Map<String, dynamic>?),
      tasks: (json['tasks'] as List<dynamic>).map((e) => TaskData.fromJson(e as Map<String, dynamic>)).toList(),
      isExpanded: json['isExpanded'] as bool? ?? false,
      locationId: json['locationId'] as String?,
      checklistId: json['checklistId'] as String?,
      checklistName: json['checklistName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shiftId': shiftId,
      'shiftName': shiftName,
      'organizationId': organizationId,
      'startTime': const TimeOfDayConverter().toJson(startTime),
      'endTime': const TimeOfDayConverter().toJson(endTime),
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'isExpanded': isExpanded,
      'locationId': locationId,
      'checklistId': checklistId,
      'checklistName': checklistName,
    };
  }
}

/// Custom JSON converter for TimeOfDay since it's not directly serializable
class TimeOfDayConverter implements JsonConverter<TimeOfDay?, Map<String, dynamic>?> {
  const TimeOfDayConverter();

  @override
  TimeOfDay? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int);
  }

  @override
  Map<String, dynamic>? toJson(TimeOfDay? object) {
    if (object == null) return null;
    return {'hour': object.hour, 'minute': object.minute};
  }
}

// bump version to force Freezed rebuild
