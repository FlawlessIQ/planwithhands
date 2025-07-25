import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/timestamp_converter.dart';

part 'shift_data.freezed.dart';
part 'shift_data.g.dart';

@freezed
class ShiftData with _$ShiftData {
  /// Main ShiftData constructor. activeDays is always required and must be a List of int (`List<int>`).
  factory ShiftData({
    @Default('') String shiftId,
    @Default('Unnamed Shift') String shiftName,
    @TimestampConverter() required DateTime createdAt,
    @Default('N/A') String startTime,
    @Default('N/A') String endTime,
    @Default('') String organizationId,
    @Default([]) List<String> locationIds,
    @Default([]) List<String> checklistTemplateIds,
    @Default([]) List<String> jobType,
    @Default({}) Map<String, int> staffingLevels,
    @Default([]) List<String> days,
    @Default(false) bool repeatsDaily,
    required List<int> activeDays,
    @Default([]) List<String> assignedUserIds,
    @Default([]) List<String> volunteers,
    @Default(false) bool published,
    @NullableTimestampConverter() DateTime? shiftDate,
    @NullableTimestampConverter() DateTime? updatedAt,
  }) = _ShiftData;

  /// Custom fromJson to ensure activeDays is always a List of int (`List<int>`).
  factory ShiftData.fromJson(Map<String, dynamic> json) =>
      _$ShiftDataFromJson(json);
}
