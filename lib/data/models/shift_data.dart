import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/timestamp_converter.dart';

part 'shift_data.freezed.dart';
part 'shift_data.g.dart';

@freezed
class ShiftData with _$ShiftData {
  factory ShiftData({
    @Default('') String shiftId,
    @Default('Unnamed Shift') String shiftName,
    @TimestampConverter() required DateTime createdAt,
    @Default('N/A') String startTime,
    @Default('N/A') String endTime,
    @Default('') String organizationId,

    // These four fields are present per your generated g.dart:
    @Default(<String>[]) List<String> locationIds,
    @Default(<String>[]) List<String> checklistTemplateIds,
    @Default(<String>[]) List<String> jobType,
    @Default(<String, int>{}) Map<String, int> staffingLevels,

    @Default(<String>[]) List<String> days,
    @Default(false) bool repeatsDaily,
    @Default(<int>[]) List<int> activeDays,
    @Default(<String>[]) List<String> assignedUserIds,
    @Default(<String>[]) List<String> volunteers,
    @Default(false) bool published,

    @NullableTimestampConverter() DateTime? shiftDate,
    @NullableTimestampConverter() DateTime? updatedAt,
  }) = _ShiftData;

  factory ShiftData.fromJson(Map<String, dynamic> json) => _$ShiftDataFromJson(json);
}
