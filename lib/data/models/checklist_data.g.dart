// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChecklistDataImpl _$$ChecklistDataImplFromJson(Map<String, dynamic> json) =>
    _$ChecklistDataImpl(
      checklistId: json['checklistId'] as String,
      checklistName: json['checklistName'] as String,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      checklistDescription: json['checklistDescription'] as String? ?? '',
      tasks:
          json['tasks'] == null
              ? const []
              : const TaskDataListConverter().fromJson(json['tasks'] as List),
      lastUpdated:
          json['lastUpdated'] == null
              ? null
              : const TimestampConverter().fromJson(json['lastUpdated']),
    );

Map<String, dynamic> _$$ChecklistDataImplToJson(_$ChecklistDataImpl instance) =>
    <String, dynamic>{
      'checklistId': instance.checklistId,
      'checklistName': instance.checklistName,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'checklistDescription': instance.checklistDescription,
      'tasks': const TaskDataListConverter().toJson(instance.tasks),
      'lastUpdated': _$JsonConverterToJson<Object?, DateTime>(
        instance.lastUpdated,
        const TimestampConverter().toJson,
      ),
    };

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
