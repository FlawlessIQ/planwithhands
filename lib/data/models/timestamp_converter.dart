import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.parse(value);
    } else {
      throw Exception(
        'NullableTimestampConverter: Unexpected type: ${value.runtimeType}',
      );
    }
  }

  @override
  Object? toJson(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
}

class TimestampConverter implements JsonConverter<DateTime, Object?> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object? value) {
    if (value == null) {
      throw Exception(
        'TimestampConverter: value is null for a required DateTime field',
      );
    }
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.parse(value);
    } else {
      throw Exception(
        'TimestampConverter: Unexpected type: ${value.runtimeType}',
      );
    }
  }

  @override
  Object toJson(DateTime date) => Timestamp.fromDate(date);
}
