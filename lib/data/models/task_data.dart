import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/timestamp_converter.dart';

part 'task_data.freezed.dart';
part 'task_data.g.dart';

@freezed
class TaskData with _$TaskData {
  factory TaskData({
    required String taskId,
    required String taskName,
    @TimestampConverter() required DateTime createdAt,
    @TimestampConverter() required DateTime dueDate,
    @Default(false) bool completed,
    @Default(false) bool photoRequired,
    String? completedBy,
    String? photoUrl,
    @Default('') String description,
  }) = _TaskData;

  factory TaskData.fromJson(Map<String, dynamic> json) =>
      _$TaskDataFromJson(json);
}
