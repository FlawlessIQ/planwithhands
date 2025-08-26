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

  factory ShiftData.fromJson(Map<String, dynamic> json) => _$ShiftDataFromJson(_normalizeShiftJson(json));
}

// Normalize legacy/incorrect Firestore documents so generated deserializer
// always receives the expected types (lists/maps). This prevents runtime
// TypeError when a field like `jobType` or `locationIds` is stored as a
// single string in older documents.
Map<String, dynamic> _normalizeShiftJson(Map<String, dynamic> json) {
  final Map<String, dynamic> copy = Map<String, dynamic>.from(json);

  List<String> ensureStringList(dynamic v) {
    if (v == null) return <String>[];
    if (v is List) return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    if (v is String) return v.isEmpty ? <String>[] : <String>[v];
    return <String>[];
  }

  List<int> ensureIntList(dynamic v) {
    if (v == null) return <int>[];
    if (v is List) {
      return v.map((e) {
        if (e is int) return e;
        if (e is String) return int.tryParse(e) ?? 0;
        return 0;
      }).where((i) => i != 0).toList();
    }
    if (v is int) return <int>[v];
    if (v is String) {
      // comma-separated days or single number
      final parts = v.split(',').map((p) => p.trim());
      return parts.map((p) => int.tryParse(p) ?? 0).where((i) => i != 0).toList();
    }
    return <int>[];
  }

  Map<String, int> ensureMapStringInt(dynamic v) {
    if (v == null) return <String, int>{};
    if (v is Map) {
      final out = <String, int>{};
      v.forEach((key, value) {
        if (key == null) return;
        final k = key.toString();
        if (value is int) {
          out[k] = value;
        } else if (value is String) {
          out[k] = int.tryParse(value) ?? 0;
        } else {
          // ignore unexpected types
        }
      });
      return out;
    }
    return <String, int>{};
  }

  // Fields that should be List<String>
  copy['locationIds'] = ensureStringList(copy['locationIds']);
  copy['checklistTemplateIds'] = ensureStringList(copy['checklistTemplateIds']);
  copy['jobType'] = ensureStringList(copy['jobType']);
  copy['days'] = ensureStringList(copy['days']);
  copy['assignedUserIds'] = ensureStringList(copy['assignedUserIds']);
  copy['volunteers'] = ensureStringList(copy['volunteers']);

  // activeDays should be List<int>
  copy['activeDays'] = ensureIntList(copy['activeDays']);

  // staffingLevels should be Map<String,int>
  copy['staffingLevels'] = ensureMapStringInt(copy['staffingLevels']);

  return copy;
}

