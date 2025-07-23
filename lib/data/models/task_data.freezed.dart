// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TaskData _$TaskDataFromJson(Map<String, dynamic> json) {
  return _TaskData.fromJson(json);
}

/// @nodoc
mixin _$TaskData {
  String get taskId => throw _privateConstructorUsedError;
  String get taskName => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get dueDate => throw _privateConstructorUsedError;
  bool get completed => throw _privateConstructorUsedError;
  bool get photoRequired => throw _privateConstructorUsedError;
  String? get completedBy => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;

  /// Serializes this TaskData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskDataCopyWith<TaskData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskDataCopyWith<$Res> {
  factory $TaskDataCopyWith(TaskData value, $Res Function(TaskData) then) =
      _$TaskDataCopyWithImpl<$Res, TaskData>;
  @useResult
  $Res call({
    String taskId,
    String taskName,
    @TimestampConverter() DateTime createdAt,
    @TimestampConverter() DateTime dueDate,
    bool completed,
    bool photoRequired,
    String? completedBy,
    String? photoUrl,
    String description,
  });
}

/// @nodoc
class _$TaskDataCopyWithImpl<$Res, $Val extends TaskData>
    implements $TaskDataCopyWith<$Res> {
  _$TaskDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskId = null,
    Object? taskName = null,
    Object? createdAt = null,
    Object? dueDate = null,
    Object? completed = null,
    Object? photoRequired = null,
    Object? completedBy = freezed,
    Object? photoUrl = freezed,
    Object? description = null,
  }) {
    return _then(
      _value.copyWith(
            taskId:
                null == taskId
                    ? _value.taskId
                    : taskId // ignore: cast_nullable_to_non_nullable
                        as String,
            taskName:
                null == taskName
                    ? _value.taskName
                    : taskName // ignore: cast_nullable_to_non_nullable
                        as String,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            dueDate:
                null == dueDate
                    ? _value.dueDate
                    : dueDate // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            completed:
                null == completed
                    ? _value.completed
                    : completed // ignore: cast_nullable_to_non_nullable
                        as bool,
            photoRequired:
                null == photoRequired
                    ? _value.photoRequired
                    : photoRequired // ignore: cast_nullable_to_non_nullable
                        as bool,
            completedBy:
                freezed == completedBy
                    ? _value.completedBy
                    : completedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            photoUrl:
                freezed == photoUrl
                    ? _value.photoUrl
                    : photoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            description:
                null == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskDataImplCopyWith<$Res>
    implements $TaskDataCopyWith<$Res> {
  factory _$$TaskDataImplCopyWith(
    _$TaskDataImpl value,
    $Res Function(_$TaskDataImpl) then,
  ) = __$$TaskDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String taskId,
    String taskName,
    @TimestampConverter() DateTime createdAt,
    @TimestampConverter() DateTime dueDate,
    bool completed,
    bool photoRequired,
    String? completedBy,
    String? photoUrl,
    String description,
  });
}

/// @nodoc
class __$$TaskDataImplCopyWithImpl<$Res>
    extends _$TaskDataCopyWithImpl<$Res, _$TaskDataImpl>
    implements _$$TaskDataImplCopyWith<$Res> {
  __$$TaskDataImplCopyWithImpl(
    _$TaskDataImpl _value,
    $Res Function(_$TaskDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskId = null,
    Object? taskName = null,
    Object? createdAt = null,
    Object? dueDate = null,
    Object? completed = null,
    Object? photoRequired = null,
    Object? completedBy = freezed,
    Object? photoUrl = freezed,
    Object? description = null,
  }) {
    return _then(
      _$TaskDataImpl(
        taskId:
            null == taskId
                ? _value.taskId
                : taskId // ignore: cast_nullable_to_non_nullable
                    as String,
        taskName:
            null == taskName
                ? _value.taskName
                : taskName // ignore: cast_nullable_to_non_nullable
                    as String,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        dueDate:
            null == dueDate
                ? _value.dueDate
                : dueDate // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        completed:
            null == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                    as bool,
        photoRequired:
            null == photoRequired
                ? _value.photoRequired
                : photoRequired // ignore: cast_nullable_to_non_nullable
                    as bool,
        completedBy:
            freezed == completedBy
                ? _value.completedBy
                : completedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        photoUrl:
            freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        description:
            null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskDataImpl implements _TaskData {
  _$TaskDataImpl({
    required this.taskId,
    required this.taskName,
    @TimestampConverter() required this.createdAt,
    @TimestampConverter() required this.dueDate,
    this.completed = false,
    this.photoRequired = false,
    this.completedBy,
    this.photoUrl,
    this.description = '',
  });

  factory _$TaskDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskDataImplFromJson(json);

  @override
  final String taskId;
  @override
  final String taskName;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @TimestampConverter()
  final DateTime dueDate;
  @override
  @JsonKey()
  final bool completed;
  @override
  @JsonKey()
  final bool photoRequired;
  @override
  final String? completedBy;
  @override
  final String? photoUrl;
  @override
  @JsonKey()
  final String description;

  @override
  String toString() {
    return 'TaskData(taskId: $taskId, taskName: $taskName, createdAt: $createdAt, dueDate: $dueDate, completed: $completed, photoRequired: $photoRequired, completedBy: $completedBy, photoUrl: $photoUrl, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskDataImpl &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.photoRequired, photoRequired) ||
                other.photoRequired == photoRequired) &&
            (identical(other.completedBy, completedBy) ||
                other.completedBy == completedBy) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    taskId,
    taskName,
    createdAt,
    dueDate,
    completed,
    photoRequired,
    completedBy,
    photoUrl,
    description,
  );

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskDataImplCopyWith<_$TaskDataImpl> get copyWith =>
      __$$TaskDataImplCopyWithImpl<_$TaskDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskDataImplToJson(this);
  }
}

abstract class _TaskData implements TaskData {
  factory _TaskData({
    required final String taskId,
    required final String taskName,
    @TimestampConverter() required final DateTime createdAt,
    @TimestampConverter() required final DateTime dueDate,
    final bool completed,
    final bool photoRequired,
    final String? completedBy,
    final String? photoUrl,
    final String description,
  }) = _$TaskDataImpl;

  factory _TaskData.fromJson(Map<String, dynamic> json) =
      _$TaskDataImpl.fromJson;

  @override
  String get taskId;
  @override
  String get taskName;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @TimestampConverter()
  DateTime get dueDate;
  @override
  bool get completed;
  @override
  bool get photoRequired;
  @override
  String? get completedBy;
  @override
  String? get photoUrl;
  @override
  String get description;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskDataImplCopyWith<_$TaskDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
