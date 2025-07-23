import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/timestamp_converter.dart';
import 'package:hands_app/data/models/task_data.dart';

part 'checklist_data.freezed.dart';
part 'checklist_data.g.dart';

@freezed
class ChecklistData with _$ChecklistData {
  factory ChecklistData({
    required String checklistId,
    required String checklistName,
    @TimestampConverter() required DateTime createdAt,
    @Default('') String checklistDescription,
    @TaskDataListConverter() @Default([]) List<TaskData> tasks,
    @TimestampConverter() @Default(null) DateTime? lastUpdated,
  }) = _ChecklistData;

  factory ChecklistData.fromJson(Map<String, Object?> json) =>
      _$ChecklistDataFromJson(json);
}

class TaskDataListConverter implements JsonConverter<List<TaskData>, List<dynamic>> {
  const TaskDataListConverter();

  @override
  List<TaskData> fromJson(List<dynamic> json) =>
      json.map((e) => TaskData.fromJson(e as Map<String, dynamic>)).toList();

  @override
  List<dynamic> toJson(List<TaskData> object) =>
      object.map((e) => e.toJson()).toList();
}
