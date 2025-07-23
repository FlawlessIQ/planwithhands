// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_checklist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DailyChecklistImpl _$$DailyChecklistImplFromJson(Map<String, dynamic> json) =>
    _$DailyChecklistImpl(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      locationId: json['locationId'] as String,
      shiftId: json['shiftId'] as String,
      templateId: json['templateId'] as String,
      templateName: json['templateName'] as String,
      date: json['date'] as String,
      tasks:
          (json['tasks'] as List<dynamic>?)
              ?.map((e) => DailyTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedBy: json['completedBy'] as String?,
      completedAt: const TimestampConverter().fromJson(json['completedAt']),
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      updatedAt: const TimestampConverter().fromJson(json['updatedAt']),
    );

Map<String, dynamic> _$$DailyChecklistImplToJson(
  _$DailyChecklistImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'organizationId': instance.organizationId,
  'locationId': instance.locationId,
  'shiftId': instance.shiftId,
  'templateId': instance.templateId,
  'templateName': instance.templateName,
  'date': instance.date,
  'tasks': instance.tasks,
  'isCompleted': instance.isCompleted,
  'completedBy': instance.completedBy,
  'completedAt': _$JsonConverterToJson<Object?, DateTime>(
    instance.completedAt,
    const TimestampConverter().toJson,
  ),
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'updatedAt': _$JsonConverterToJson<Object?, DateTime>(
    instance.updatedAt,
    const TimestampConverter().toJson,
  ),
};

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

_$DailyTaskImpl _$$DailyTaskImplFromJson(Map<String, dynamic> json) =>
    _$DailyTaskImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      completed: json['completed'] as bool? ?? false,
      order: (json['order'] as num?)?.toInt() ?? 0,
      completedBy: json['completedBy'] as String?,
      completedAt: const TimestampConverter().fromJson(json['completedAt']),
      notes: json['notes'] as String?,
      proofImageUrl: json['proofImageUrl'] as String?,
    );

Map<String, dynamic> _$$DailyTaskImplToJson(_$DailyTaskImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'completed': instance.completed,
      'order': instance.order,
      'completedBy': instance.completedBy,
      'completedAt': _$JsonConverterToJson<Object?, DateTime>(
        instance.completedAt,
        const TimestampConverter().toJson,
      ),
      'notes': instance.notes,
      'proofImageUrl': instance.proofImageUrl,
    };
