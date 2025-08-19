// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskDataImpl _$$TaskDataImplFromJson(Map<String, dynamic> json) =>
    _$TaskDataImpl(
      taskId: json['taskId'] as String,
      taskName: json['taskName'] as String,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      dueDate: const TimestampConverter().fromJson(json['dueDate']),
      completed: json['completed'] as bool? ?? false,
      photoRequired: json['photoRequired'] as bool? ?? false,
      completedBy: json['completedBy'] as String?,
      completedByUserId: json['completedByUserId'] as String?,
      completedByUserName: json['completedByUserName'] as String?,
      completedByUserEmail: json['completedByUserEmail'] as String?,
      completedAt: const TimestampConverter().fromJson(json['completedAt']),
      notes: json['notes'] as String?,
      photoUrl: json['photoUrl'] as String?,
      proofImageUrl: json['proofImageUrl'] as String?,
      description: json['description'] as String?,
      notCompletedReason: json['notCompletedReason'] as String?,
      isCarryForward: json['isCarryForward'] as bool? ?? false,
      originalDate: const TimestampConverter().fromJson(json['originalDate']),
      originalChecklistId: json['originalChecklistId'] as String?,
      originalTaskId: json['originalTaskId'] as String?,
      carriedIntoDate: const TimestampConverter().fromJson(
        json['carriedIntoDate'],
      ),
      carryForwardAttempted: json['carryForwardAttempted'] as bool? ?? false,
      excludedFromMetrics: json['excludedFromMetrics'] as bool? ?? false,
      resolvedLate: json['resolvedLate'] as bool? ?? false,
      resolvedAt: const TimestampConverter().fromJson(json['resolvedAt']),
      organizationId: json['organizationId'] as String?,
      locationId: json['locationId'] as String?,
      checklistId: json['checklistId'] as String?,
      checklistName: json['checklistName'] as String?,
      shiftId: json['shiftId'] as String?,
      templateId: json['templateId'] as String?,
      dateString: json['dateString'] as String?,
    );

Map<String, dynamic> _$$TaskDataImplToJson(_$TaskDataImpl instance) =>
    <String, dynamic>{
      'taskId': instance.taskId,
      'taskName': instance.taskName,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'dueDate': const TimestampConverter().toJson(instance.dueDate),
      'completed': instance.completed,
      'photoRequired': instance.photoRequired,
      'completedBy': instance.completedBy,
      'completedByUserId': instance.completedByUserId,
      'completedByUserName': instance.completedByUserName,
      'completedByUserEmail': instance.completedByUserEmail,
      'completedAt': _$JsonConverterToJson<Object?, DateTime>(
        instance.completedAt,
        const TimestampConverter().toJson,
      ),
      'notes': instance.notes,
      'photoUrl': instance.photoUrl,
      'proofImageUrl': instance.proofImageUrl,
      'description': instance.description,
      'notCompletedReason': instance.notCompletedReason,
      'isCarryForward': instance.isCarryForward,
      'originalDate': _$JsonConverterToJson<Object?, DateTime>(
        instance.originalDate,
        const TimestampConverter().toJson,
      ),
      'originalChecklistId': instance.originalChecklistId,
      'originalTaskId': instance.originalTaskId,
      'carriedIntoDate': _$JsonConverterToJson<Object?, DateTime>(
        instance.carriedIntoDate,
        const TimestampConverter().toJson,
      ),
      'carryForwardAttempted': instance.carryForwardAttempted,
      'excludedFromMetrics': instance.excludedFromMetrics,
      'resolvedLate': instance.resolvedLate,
      'resolvedAt': _$JsonConverterToJson<Object?, DateTime>(
        instance.resolvedAt,
        const TimestampConverter().toJson,
      ),
      'organizationId': instance.organizationId,
      'locationId': instance.locationId,
      'checklistId': instance.checklistId,
      'checklistName': instance.checklistName,
      'shiftId': instance.shiftId,
      'templateId': instance.templateId,
      'dateString': instance.dateString,
    };

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
