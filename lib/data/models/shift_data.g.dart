// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShiftDataImpl _$$ShiftDataImplFromJson(Map<String, dynamic> json) =>
    _$ShiftDataImpl(
      shiftId: json['shiftId'] as String? ?? '',
      shiftName: json['shiftName'] as String? ?? 'Unnamed Shift',
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      startTime: json['startTime'] as String? ?? 'N/A',
      endTime: json['endTime'] as String? ?? 'N/A',
      organizationId: json['organizationId'] as String? ?? '',
      locationIds:
          (json['locationIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      checklistTemplateIds:
          (json['checklistTemplateIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      jobType:
          (json['jobType'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      staffingLevels:
          (json['staffingLevels'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      days:
          (json['days'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      repeatsDaily: json['repeatsDaily'] as bool? ?? false,
      activeDays:
          (json['activeDays'] as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toList(),
      assignedUserIds:
          (json['assignedUserIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      volunteers:
          (json['volunteers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      published: json['published'] as bool? ?? false,
      shiftDate: const NullableTimestampConverter().fromJson(json['shiftDate']),
      updatedAt: const NullableTimestampConverter().fromJson(json['updatedAt']),
    );

Map<String, dynamic> _$$ShiftDataImplToJson(
  _$ShiftDataImpl instance,
) => <String, dynamic>{
  'shiftId': instance.shiftId,
  'shiftName': instance.shiftName,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'startTime': instance.startTime,
  'endTime': instance.endTime,
  'organizationId': instance.organizationId,
  'locationIds': instance.locationIds,
  'checklistTemplateIds': instance.checklistTemplateIds,
  'jobType': instance.jobType,
  'staffingLevels': instance.staffingLevels,
  'days': instance.days,
  'repeatsDaily': instance.repeatsDaily,
  'activeDays': instance.activeDays,
  'assignedUserIds': instance.assignedUserIds,
  'volunteers': instance.volunteers,
  'published': instance.published,
  'shiftDate': const NullableTimestampConverter().toJson(instance.shiftDate),
  'updatedAt': const NullableTimestampConverter().toJson(instance.updatedAt),
};
