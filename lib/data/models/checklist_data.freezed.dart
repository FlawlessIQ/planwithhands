// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checklist_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ChecklistData _$ChecklistDataFromJson(Map<String, dynamic> json) {
  return _ChecklistData.fromJson(json);
}

/// @nodoc
mixin _$ChecklistData {
  String get checklistId => throw _privateConstructorUsedError;
  String get checklistName => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get checklistDescription => throw _privateConstructorUsedError;
  @TaskDataListConverter()
  List<TaskData> get tasks => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get lastUpdated => throw _privateConstructorUsedError;

  /// Serializes this ChecklistData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChecklistDataCopyWith<ChecklistData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChecklistDataCopyWith<$Res> {
  factory $ChecklistDataCopyWith(
    ChecklistData value,
    $Res Function(ChecklistData) then,
  ) = _$ChecklistDataCopyWithImpl<$Res, ChecklistData>;
  @useResult
  $Res call({
    String checklistId,
    String checklistName,
    @TimestampConverter() DateTime createdAt,
    String checklistDescription,
    @TaskDataListConverter() List<TaskData> tasks,
    @TimestampConverter() DateTime? lastUpdated,
  });
}

/// @nodoc
class _$ChecklistDataCopyWithImpl<$Res, $Val extends ChecklistData>
    implements $ChecklistDataCopyWith<$Res> {
  _$ChecklistDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checklistId = null,
    Object? checklistName = null,
    Object? createdAt = null,
    Object? checklistDescription = null,
    Object? tasks = null,
    Object? lastUpdated = freezed,
  }) {
    return _then(
      _value.copyWith(
            checklistId:
                null == checklistId
                    ? _value.checklistId
                    : checklistId // ignore: cast_nullable_to_non_nullable
                        as String,
            checklistName:
                null == checklistName
                    ? _value.checklistName
                    : checklistName // ignore: cast_nullable_to_non_nullable
                        as String,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            checklistDescription:
                null == checklistDescription
                    ? _value.checklistDescription
                    : checklistDescription // ignore: cast_nullable_to_non_nullable
                        as String,
            tasks:
                null == tasks
                    ? _value.tasks
                    : tasks // ignore: cast_nullable_to_non_nullable
                        as List<TaskData>,
            lastUpdated:
                freezed == lastUpdated
                    ? _value.lastUpdated
                    : lastUpdated // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChecklistDataImplCopyWith<$Res>
    implements $ChecklistDataCopyWith<$Res> {
  factory _$$ChecklistDataImplCopyWith(
    _$ChecklistDataImpl value,
    $Res Function(_$ChecklistDataImpl) then,
  ) = __$$ChecklistDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String checklistId,
    String checklistName,
    @TimestampConverter() DateTime createdAt,
    String checklistDescription,
    @TaskDataListConverter() List<TaskData> tasks,
    @TimestampConverter() DateTime? lastUpdated,
  });
}

/// @nodoc
class __$$ChecklistDataImplCopyWithImpl<$Res>
    extends _$ChecklistDataCopyWithImpl<$Res, _$ChecklistDataImpl>
    implements _$$ChecklistDataImplCopyWith<$Res> {
  __$$ChecklistDataImplCopyWithImpl(
    _$ChecklistDataImpl _value,
    $Res Function(_$ChecklistDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? checklistId = null,
    Object? checklistName = null,
    Object? createdAt = null,
    Object? checklistDescription = null,
    Object? tasks = null,
    Object? lastUpdated = freezed,
  }) {
    return _then(
      _$ChecklistDataImpl(
        checklistId:
            null == checklistId
                ? _value.checklistId
                : checklistId // ignore: cast_nullable_to_non_nullable
                    as String,
        checklistName:
            null == checklistName
                ? _value.checklistName
                : checklistName // ignore: cast_nullable_to_non_nullable
                    as String,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        checklistDescription:
            null == checklistDescription
                ? _value.checklistDescription
                : checklistDescription // ignore: cast_nullable_to_non_nullable
                    as String,
        tasks:
            null == tasks
                ? _value._tasks
                : tasks // ignore: cast_nullable_to_non_nullable
                    as List<TaskData>,
        lastUpdated:
            freezed == lastUpdated
                ? _value.lastUpdated
                : lastUpdated // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChecklistDataImpl implements _ChecklistData {
  _$ChecklistDataImpl({
    required this.checklistId,
    required this.checklistName,
    @TimestampConverter() required this.createdAt,
    this.checklistDescription = '',
    @TaskDataListConverter() final List<TaskData> tasks = const [],
    @TimestampConverter() this.lastUpdated = null,
  }) : _tasks = tasks;

  factory _$ChecklistDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChecklistDataImplFromJson(json);

  @override
  final String checklistId;
  @override
  final String checklistName;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @JsonKey()
  final String checklistDescription;
  final List<TaskData> _tasks;
  @override
  @JsonKey()
  @TaskDataListConverter()
  List<TaskData> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

  @override
  @JsonKey()
  @TimestampConverter()
  final DateTime? lastUpdated;

  @override
  String toString() {
    return 'ChecklistData(checklistId: $checklistId, checklistName: $checklistName, createdAt: $createdAt, checklistDescription: $checklistDescription, tasks: $tasks, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChecklistDataImpl &&
            (identical(other.checklistId, checklistId) ||
                other.checklistId == checklistId) &&
            (identical(other.checklistName, checklistName) ||
                other.checklistName == checklistName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.checklistDescription, checklistDescription) ||
                other.checklistDescription == checklistDescription) &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    checklistId,
    checklistName,
    createdAt,
    checklistDescription,
    const DeepCollectionEquality().hash(_tasks),
    lastUpdated,
  );

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChecklistDataImplCopyWith<_$ChecklistDataImpl> get copyWith =>
      __$$ChecklistDataImplCopyWithImpl<_$ChecklistDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChecklistDataImplToJson(this);
  }
}

abstract class _ChecklistData implements ChecklistData {
  factory _ChecklistData({
    required final String checklistId,
    required final String checklistName,
    @TimestampConverter() required final DateTime createdAt,
    final String checklistDescription,
    @TaskDataListConverter() final List<TaskData> tasks,
    @TimestampConverter() final DateTime? lastUpdated,
  }) = _$ChecklistDataImpl;

  factory _ChecklistData.fromJson(Map<String, dynamic> json) =
      _$ChecklistDataImpl.fromJson;

  @override
  String get checklistId;
  @override
  String get checklistName;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  String get checklistDescription;
  @override
  @TaskDataListConverter()
  List<TaskData> get tasks;
  @override
  @TimestampConverter()
  DateTime? get lastUpdated;

  /// Create a copy of ChecklistData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChecklistDataImplCopyWith<_$ChecklistDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
