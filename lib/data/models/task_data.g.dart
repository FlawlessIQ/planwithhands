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
      photoUrl: json['photoUrl'] as String?,
      description: json['description'] as String? ?? '',
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
      'photoUrl': instance.photoUrl,
      'description': instance.description,
    };
