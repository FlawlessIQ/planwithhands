// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'missed_tasks_section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MissedTasksSection _$MissedTasksSectionFromJson(Map<String, dynamic> json) {
  return _MissedTasksSection.fromJson(json);
}

/// @nodoc
mixin _$MissedTasksSection {
  String get shiftId => throw _privateConstructorUsedError;
  String get shiftName => throw _privateConstructorUsedError;
  @TimeOfDayConverter()
  TimeOfDay? get startTime => throw _privateConstructorUsedError;
  @TimeOfDayConverter()
  TimeOfDay? get endTime => throw _privateConstructorUsedError;
  List<DailyChecklistTask> get tasks => throw _privateConstructorUsedError;
  bool get isExpanded => throw _privateConstructorUsedError;
  String? get locationId => throw _privateConstructorUsedError;
  String? get checklistId => throw _privateConstructorUsedError;

  /// Serializes this MissedTasksSection to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MissedTasksSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MissedTasksSectionCopyWith<MissedTasksSection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MissedTasksSectionCopyWith<$Res> {
  factory $MissedTasksSectionCopyWith(
    MissedTasksSection value,
    $Res Function(MissedTasksSection) then,
  ) = _$MissedTasksSectionCopyWithImpl<$Res, MissedTasksSection>;
  @useResult
  $Res call({
    String shiftId,
    String shiftName,
    @TimeOfDayConverter() TimeOfDay? startTime,
    @TimeOfDayConverter() TimeOfDay? endTime,
    List<DailyChecklistTask> tasks,
    bool isExpanded,
    String? locationId,
    String? checklistId,
  });
}

/// @nodoc
class _$MissedTasksSectionCopyWithImpl<$Res, $Val extends MissedTasksSection>
    implements $MissedTasksSectionCopyWith<$Res> {
  _$MissedTasksSectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MissedTasksSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shiftId = null,
    Object? shiftName = null,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? tasks = null,
    Object? isExpanded = null,
    Object? locationId = freezed,
    Object? checklistId = freezed,
  }) {
    return _then(
      _value.copyWith(
            shiftId:
                null == shiftId
                    ? _value.shiftId
                    : shiftId // ignore: cast_nullable_to_non_nullable
                        as String,
            shiftName:
                null == shiftName
                    ? _value.shiftName
                    : shiftName // ignore: cast_nullable_to_non_nullable
                        as String,
            startTime:
                freezed == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as TimeOfDay?,
            endTime:
                freezed == endTime
                    ? _value.endTime
                    : endTime // ignore: cast_nullable_to_non_nullable
                        as TimeOfDay?,
            tasks:
                null == tasks
                    ? _value.tasks
                    : tasks // ignore: cast_nullable_to_non_nullable
                        as List<DailyChecklistTask>,
            isExpanded:
                null == isExpanded
                    ? _value.isExpanded
                    : isExpanded // ignore: cast_nullable_to_non_nullable
                        as bool,
            locationId:
                freezed == locationId
                    ? _value.locationId
                    : locationId // ignore: cast_nullable_to_non_nullable
                        as String?,
            checklistId:
                freezed == checklistId
                    ? _value.checklistId
                    : checklistId // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MissedTasksSectionImplCopyWith<$Res>
    implements $MissedTasksSectionCopyWith<$Res> {
  factory _$$MissedTasksSectionImplCopyWith(
    _$MissedTasksSectionImpl value,
    $Res Function(_$MissedTasksSectionImpl) then,
  ) = __$$MissedTasksSectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String shiftId,
    String shiftName,
    @TimeOfDayConverter() TimeOfDay? startTime,
    @TimeOfDayConverter() TimeOfDay? endTime,
    List<DailyChecklistTask> tasks,
    bool isExpanded,
    String? locationId,
    String? checklistId,
  });
}

/// @nodoc
class __$$MissedTasksSectionImplCopyWithImpl<$Res>
    extends _$MissedTasksSectionCopyWithImpl<$Res, _$MissedTasksSectionImpl>
    implements _$$MissedTasksSectionImplCopyWith<$Res> {
  __$$MissedTasksSectionImplCopyWithImpl(
    _$MissedTasksSectionImpl _value,
    $Res Function(_$MissedTasksSectionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MissedTasksSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shiftId = null,
    Object? shiftName = null,
    Object? startTime = freezed,
    Object? endTime = freezed,
    Object? tasks = null,
    Object? isExpanded = null,
    Object? locationId = freezed,
    Object? checklistId = freezed,
  }) {
    return _then(
      _$MissedTasksSectionImpl(
        shiftId:
            null == shiftId
                ? _value.shiftId
                : shiftId // ignore: cast_nullable_to_non_nullable
                    as String,
        shiftName:
            null == shiftName
                ? _value.shiftName
                : shiftName // ignore: cast_nullable_to_non_nullable
                    as String,
        startTime:
            freezed == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as TimeOfDay?,
        endTime:
            freezed == endTime
                ? _value.endTime
                : endTime // ignore: cast_nullable_to_non_nullable
                    as TimeOfDay?,
        tasks:
            null == tasks
                ? _value._tasks
                : tasks // ignore: cast_nullable_to_non_nullable
                    as List<DailyChecklistTask>,
        isExpanded:
            null == isExpanded
                ? _value.isExpanded
                : isExpanded // ignore: cast_nullable_to_non_nullable
                    as bool,
        locationId:
            freezed == locationId
                ? _value.locationId
                : locationId // ignore: cast_nullable_to_non_nullable
                    as String?,
        checklistId:
            freezed == checklistId
                ? _value.checklistId
                : checklistId // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MissedTasksSectionImpl implements _MissedTasksSection {
  _$MissedTasksSectionImpl({
    required this.shiftId,
    required this.shiftName,
    @TimeOfDayConverter() this.startTime,
    @TimeOfDayConverter() this.endTime,
    required final List<DailyChecklistTask> tasks,
    this.isExpanded = false,
    this.locationId,
    this.checklistId,
  }) : _tasks = tasks;

  factory _$MissedTasksSectionImpl.fromJson(Map<String, dynamic> json) =>
      _$$MissedTasksSectionImplFromJson(json);

  @override
  final String shiftId;
  @override
  final String shiftName;
  @override
  @TimeOfDayConverter()
  final TimeOfDay? startTime;
  @override
  @TimeOfDayConverter()
  final TimeOfDay? endTime;
  final List<DailyChecklistTask> _tasks;
  @override
  List<DailyChecklistTask> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

  @override
  @JsonKey()
  final bool isExpanded;
  @override
  final String? locationId;
  @override
  final String? checklistId;

  @override
  String toString() {
    return 'MissedTasksSection(shiftId: $shiftId, shiftName: $shiftName, startTime: $startTime, endTime: $endTime, tasks: $tasks, isExpanded: $isExpanded, locationId: $locationId, checklistId: $checklistId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MissedTasksSectionImpl &&
            (identical(other.shiftId, shiftId) || other.shiftId == shiftId) &&
            (identical(other.shiftName, shiftName) ||
                other.shiftName == shiftName) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            (identical(other.isExpanded, isExpanded) ||
                other.isExpanded == isExpanded) &&
            (identical(other.locationId, locationId) ||
                other.locationId == locationId) &&
            (identical(other.checklistId, checklistId) ||
                other.checklistId == checklistId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    shiftId,
    shiftName,
    startTime,
    endTime,
    const DeepCollectionEquality().hash(_tasks),
    isExpanded,
    locationId,
    checklistId,
  );

  /// Create a copy of MissedTasksSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MissedTasksSectionImplCopyWith<_$MissedTasksSectionImpl> get copyWith =>
      __$$MissedTasksSectionImplCopyWithImpl<_$MissedTasksSectionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MissedTasksSectionImplToJson(this);
  }
}

abstract class _MissedTasksSection implements MissedTasksSection {
  factory _MissedTasksSection({
    required final String shiftId,
    required final String shiftName,
    @TimeOfDayConverter() final TimeOfDay? startTime,
    @TimeOfDayConverter() final TimeOfDay? endTime,
    required final List<DailyChecklistTask> tasks,
    final bool isExpanded,
    final String? locationId,
    final String? checklistId,
  }) = _$MissedTasksSectionImpl;

  factory _MissedTasksSection.fromJson(Map<String, dynamic> json) =
      _$MissedTasksSectionImpl.fromJson;

  @override
  String get shiftId;
  @override
  String get shiftName;
  @override
  @TimeOfDayConverter()
  TimeOfDay? get startTime;
  @override
  @TimeOfDayConverter()
  TimeOfDay? get endTime;
  @override
  List<DailyChecklistTask> get tasks;
  @override
  bool get isExpanded;
  @override
  String? get locationId;
  @override
  String? get checklistId;

  /// Create a copy of MissedTasksSection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MissedTasksSectionImplCopyWith<_$MissedTasksSectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
