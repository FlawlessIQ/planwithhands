// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LocationDataImpl _$$LocationDataImplFromJson(Map<String, dynamic> json) =>
    _$LocationDataImpl(
      locationId: json['locationId'] as String,
      locationName: json['locationName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      locationAddress: json['locationAddress'] as String,
      shifts:
          json['shifts'] == null
              ? const []
              : const ShiftDataListConverter().fromJson(json['shifts'] as List),
    );

Map<String, dynamic> _$$LocationDataImplToJson(_$LocationDataImpl instance) =>
    <String, dynamic>{
      'locationId': instance.locationId,
      'locationName': instance.locationName,
      'createdAt': instance.createdAt.toIso8601String(),
      'locationAddress': instance.locationAddress,
      'shifts': const ShiftDataListConverter().toJson(instance.shifts),
    };
