import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/data/models/shift_data_converter.dart';

part 'location_data.freezed.dart';
part 'location_data.g.dart';


@freezed
class LocationData with _$LocationData {
  factory LocationData({
    required String locationId,
    required String locationName,
    required DateTime createdAt,
    required String locationAddress,
    @ShiftDataListConverter() @Default([]) List<ShiftData> shifts,
  }) = _LocationData;

  factory LocationData.fromJson(Map<String, Object?> json) =>
      _$LocationDataFromJson(json);
}

