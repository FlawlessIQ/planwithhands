import 'package:json_annotation/json_annotation.dart';
import 'shift_data.dart';

class ShiftDataConverter implements JsonConverter<ShiftData, Map<String, dynamic>> {
  const ShiftDataConverter();

  @override
  ShiftData fromJson(Map<String, dynamic> json) => ShiftData.fromJson(json);

  @override
  Map<String, dynamic> toJson(ShiftData data) => data.toJson();
}

class ShiftDataListConverter implements JsonConverter<List<ShiftData>, List<dynamic>> {
  const ShiftDataListConverter();

  @override
  List<ShiftData> fromJson(List<dynamic> json) =>
      json.map((e) => ShiftData.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  @override
  List<Map<String, dynamic>> toJson(List<ShiftData> data) =>
      data.map((e) => e.toJson()).toList();
}
