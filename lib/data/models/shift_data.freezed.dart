// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shift_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ShiftData _$ShiftDataFromJson(Map<String, dynamic> json) {
  return _ShiftData.fromJson(json);
}

/// @nodoc
mixin _$ShiftData {
  String get shiftId => throw _privateConstructorUsedError;
  String get shiftName => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get startTime => throw _privateConstructorUsedError;
  String get endTime => throw _privateConstructorUsedError;
  String get organizationId => throw _privateConstructorUsedError;
  List<String> get locationIds => throw _privateConstructorUsedError;
  List<String> get checklistTemplateIds => throw _privateConstructorUsedError;
  List<String> get jobType => throw _privateConstructorUsedError;
  Map<String, int> get staffingLevels => throw _privateConstructorUsedError;
  List<String> get days => throw _privateConstructorUsedError;
  bool get repeatsDaily => throw _privateConstructorUsedError;
  List<int> get activeDays => throw _privateConstructorUsedError;
  List<String> get assignedUserIds => throw _privateConstructorUsedError;
  List<String> get volunteers => throw _privateConstructorUsedError;
  bool get published => throw _privateConstructorUsedError;
  @NullableTimestampConverter()
  DateTime? get shiftDate => throw _privateConstructorUsedError;
  @NullableTimestampConverter()
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this ShiftData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShiftData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShiftDataCopyWith<ShiftData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShiftDataCopyWith<$Res> {
  factory $ShiftDataCopyWith(ShiftData value, $Res Function(ShiftData) then) =
      _$ShiftDataCopyWithImpl<$Res, ShiftData>;
  @useResult
  $Res call({
    String shiftId,
    String shiftName,
    @TimestampConverter() DateTime createdAt,
    String startTime,
    String endTime,
    String organizationId,
    List<String> locationIds,
    List<String> checklistTemplateIds,
    List<String> jobType,
    Map<String, int> staffingLevels,
    List<String> days,
    bool repeatsDaily,
    List<int> activeDays,
    List<String> assignedUserIds,
    List<String> volunteers,
    bool published,
    @NullableTimestampConverter() DateTime? shiftDate,
    @NullableTimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class _$ShiftDataCopyWithImpl<$Res, $Val extends ShiftData>
    implements $ShiftDataCopyWith<$Res> {
  _$ShiftDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShiftData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shiftId = null,
    Object? shiftName = null,
    Object? createdAt = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? organizationId = null,
    Object? locationIds = null,
    Object? checklistTemplateIds = null,
    Object? jobType = null,
    Object? staffingLevels = null,
    Object? days = null,
    Object? repeatsDaily = null,
    Object? activeDays = null,
    Object? assignedUserIds = null,
    Object? volunteers = null,
    Object? published = null,
    Object? shiftDate = freezed,
    Object? updatedAt = freezed,
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
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            startTime:
                null == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as String,
            endTime:
                null == endTime
                    ? _value.endTime
                    : endTime // ignore: cast_nullable_to_non_nullable
                        as String,
            organizationId:
                null == organizationId
                    ? _value.organizationId
                    : organizationId // ignore: cast_nullable_to_non_nullable
                        as String,
            locationIds:
                null == locationIds
                    ? _value.locationIds
                    : locationIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            checklistTemplateIds:
                null == checklistTemplateIds
                    ? _value.checklistTemplateIds
                    : checklistTemplateIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            jobType:
                null == jobType
                    ? _value.jobType
                    : jobType // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            staffingLevels:
                null == staffingLevels
                    ? _value.staffingLevels
                    : staffingLevels // ignore: cast_nullable_to_non_nullable
                        as Map<String, int>,
            days:
                null == days
                    ? _value.days
                    : days // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            repeatsDaily:
                null == repeatsDaily
                    ? _value.repeatsDaily
                    : repeatsDaily // ignore: cast_nullable_to_non_nullable
                        as bool,
            activeDays:
                null == activeDays
                    ? _value.activeDays
                    : activeDays // ignore: cast_nullable_to_non_nullable
                        as List<int>,
            assignedUserIds:
                null == assignedUserIds
                    ? _value.assignedUserIds
                    : assignedUserIds // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            volunteers:
                null == volunteers
                    ? _value.volunteers
                    : volunteers // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            published:
                null == published
                    ? _value.published
                    : published // ignore: cast_nullable_to_non_nullable
                        as bool,
            shiftDate:
                freezed == shiftDate
                    ? _value.shiftDate
                    : shiftDate // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            updatedAt:
                freezed == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ShiftDataImplCopyWith<$Res>
    implements $ShiftDataCopyWith<$Res> {
  factory _$$ShiftDataImplCopyWith(
    _$ShiftDataImpl value,
    $Res Function(_$ShiftDataImpl) then,
  ) = __$$ShiftDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String shiftId,
    String shiftName,
    @TimestampConverter() DateTime createdAt,
    String startTime,
    String endTime,
    String organizationId,
    List<String> locationIds,
    List<String> checklistTemplateIds,
    List<String> jobType,
    Map<String, int> staffingLevels,
    List<String> days,
    bool repeatsDaily,
    List<int> activeDays,
    List<String> assignedUserIds,
    List<String> volunteers,
    bool published,
    @NullableTimestampConverter() DateTime? shiftDate,
    @NullableTimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class __$$ShiftDataImplCopyWithImpl<$Res>
    extends _$ShiftDataCopyWithImpl<$Res, _$ShiftDataImpl>
    implements _$$ShiftDataImplCopyWith<$Res> {
  __$$ShiftDataImplCopyWithImpl(
    _$ShiftDataImpl _value,
    $Res Function(_$ShiftDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShiftData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shiftId = null,
    Object? shiftName = null,
    Object? createdAt = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? organizationId = null,
    Object? locationIds = null,
    Object? checklistTemplateIds = null,
    Object? jobType = null,
    Object? staffingLevels = null,
    Object? days = null,
    Object? repeatsDaily = null,
    Object? activeDays = null,
    Object? assignedUserIds = null,
    Object? volunteers = null,
    Object? published = null,
    Object? shiftDate = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$ShiftDataImpl(
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
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        startTime:
            null == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as String,
        endTime:
            null == endTime
                ? _value.endTime
                : endTime // ignore: cast_nullable_to_non_nullable
                    as String,
        organizationId:
            null == organizationId
                ? _value.organizationId
                : organizationId // ignore: cast_nullable_to_non_nullable
                    as String,
        locationIds:
            null == locationIds
                ? _value._locationIds
                : locationIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        checklistTemplateIds:
            null == checklistTemplateIds
                ? _value._checklistTemplateIds
                : checklistTemplateIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        jobType:
            null == jobType
                ? _value._jobType
                : jobType // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        staffingLevels:
            null == staffingLevels
                ? _value._staffingLevels
                : staffingLevels // ignore: cast_nullable_to_non_nullable
                    as Map<String, int>,
        days:
            null == days
                ? _value._days
                : days // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        repeatsDaily:
            null == repeatsDaily
                ? _value.repeatsDaily
                : repeatsDaily // ignore: cast_nullable_to_non_nullable
                    as bool,
        activeDays:
            null == activeDays
                ? _value._activeDays
                : activeDays // ignore: cast_nullable_to_non_nullable
                    as List<int>,
        assignedUserIds:
            null == assignedUserIds
                ? _value._assignedUserIds
                : assignedUserIds // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        volunteers:
            null == volunteers
                ? _value._volunteers
                : volunteers // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        published:
            null == published
                ? _value.published
                : published // ignore: cast_nullable_to_non_nullable
                    as bool,
        shiftDate:
            freezed == shiftDate
                ? _value.shiftDate
                : shiftDate // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        updatedAt:
            freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShiftDataImpl implements _ShiftData {
  _$ShiftDataImpl({
    this.shiftId = '',
    this.shiftName = 'Unnamed Shift',
    @TimestampConverter() required this.createdAt,
    this.startTime = 'N/A',
    this.endTime = 'N/A',
    this.organizationId = '',
    final List<String> locationIds = const [],
    final List<String> checklistTemplateIds = const [],
    final List<String> jobType = const [],
    final Map<String, int> staffingLevels = const {},
    final List<String> days = const [],
    this.repeatsDaily = false,
    required final List<int> activeDays,
    final List<String> assignedUserIds = const [],
    final List<String> volunteers = const [],
    this.published = false,
    @NullableTimestampConverter() this.shiftDate,
    @NullableTimestampConverter() this.updatedAt,
  }) : _locationIds = locationIds,
       _checklistTemplateIds = checklistTemplateIds,
       _jobType = jobType,
       _staffingLevels = staffingLevels,
       _days = days,
       _activeDays = activeDays,
       _assignedUserIds = assignedUserIds,
       _volunteers = volunteers;

  factory _$ShiftDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShiftDataImplFromJson(json);

  @override
  @JsonKey()
  final String shiftId;
  @override
  @JsonKey()
  final String shiftName;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @JsonKey()
  final String startTime;
  @override
  @JsonKey()
  final String endTime;
  @override
  @JsonKey()
  final String organizationId;
  final List<String> _locationIds;
  @override
  @JsonKey()
  List<String> get locationIds {
    if (_locationIds is EqualUnmodifiableListView) return _locationIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_locationIds);
  }

  final List<String> _checklistTemplateIds;
  @override
  @JsonKey()
  List<String> get checklistTemplateIds {
    if (_checklistTemplateIds is EqualUnmodifiableListView)
      return _checklistTemplateIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_checklistTemplateIds);
  }

  final List<String> _jobType;
  @override
  @JsonKey()
  List<String> get jobType {
    if (_jobType is EqualUnmodifiableListView) return _jobType;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_jobType);
  }

  final Map<String, int> _staffingLevels;
  @override
  @JsonKey()
  Map<String, int> get staffingLevels {
    if (_staffingLevels is EqualUnmodifiableMapView) return _staffingLevels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_staffingLevels);
  }

  final List<String> _days;
  @override
  @JsonKey()
  List<String> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  @override
  @JsonKey()
  final bool repeatsDaily;
  final List<int> _activeDays;
  @override
  List<int> get activeDays {
    if (_activeDays is EqualUnmodifiableListView) return _activeDays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_activeDays);
  }

  final List<String> _assignedUserIds;
  @override
  @JsonKey()
  List<String> get assignedUserIds {
    if (_assignedUserIds is EqualUnmodifiableListView) return _assignedUserIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assignedUserIds);
  }

  final List<String> _volunteers;
  @override
  @JsonKey()
  List<String> get volunteers {
    if (_volunteers is EqualUnmodifiableListView) return _volunteers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_volunteers);
  }

  @override
  @JsonKey()
  final bool published;
  @override
  @NullableTimestampConverter()
  final DateTime? shiftDate;
  @override
  @NullableTimestampConverter()
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'ShiftData(shiftId: $shiftId, shiftName: $shiftName, createdAt: $createdAt, startTime: $startTime, endTime: $endTime, organizationId: $organizationId, locationIds: $locationIds, checklistTemplateIds: $checklistTemplateIds, jobType: $jobType, staffingLevels: $staffingLevels, days: $days, repeatsDaily: $repeatsDaily, activeDays: $activeDays, assignedUserIds: $assignedUserIds, volunteers: $volunteers, published: $published, shiftDate: $shiftDate, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShiftDataImpl &&
            (identical(other.shiftId, shiftId) || other.shiftId == shiftId) &&
            (identical(other.shiftName, shiftName) ||
                other.shiftName == shiftName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.organizationId, organizationId) ||
                other.organizationId == organizationId) &&
            const DeepCollectionEquality().equals(
              other._locationIds,
              _locationIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._checklistTemplateIds,
              _checklistTemplateIds,
            ) &&
            const DeepCollectionEquality().equals(other._jobType, _jobType) &&
            const DeepCollectionEquality().equals(
              other._staffingLevels,
              _staffingLevels,
            ) &&
            const DeepCollectionEquality().equals(other._days, _days) &&
            (identical(other.repeatsDaily, repeatsDaily) ||
                other.repeatsDaily == repeatsDaily) &&
            const DeepCollectionEquality().equals(
              other._activeDays,
              _activeDays,
            ) &&
            const DeepCollectionEquality().equals(
              other._assignedUserIds,
              _assignedUserIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._volunteers,
              _volunteers,
            ) &&
            (identical(other.published, published) ||
                other.published == published) &&
            (identical(other.shiftDate, shiftDate) ||
                other.shiftDate == shiftDate) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    shiftId,
    shiftName,
    createdAt,
    startTime,
    endTime,
    organizationId,
    const DeepCollectionEquality().hash(_locationIds),
    const DeepCollectionEquality().hash(_checklistTemplateIds),
    const DeepCollectionEquality().hash(_jobType),
    const DeepCollectionEquality().hash(_staffingLevels),
    const DeepCollectionEquality().hash(_days),
    repeatsDaily,
    const DeepCollectionEquality().hash(_activeDays),
    const DeepCollectionEquality().hash(_assignedUserIds),
    const DeepCollectionEquality().hash(_volunteers),
    published,
    shiftDate,
    updatedAt,
  );

  /// Create a copy of ShiftData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShiftDataImplCopyWith<_$ShiftDataImpl> get copyWith =>
      __$$ShiftDataImplCopyWithImpl<_$ShiftDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShiftDataImplToJson(this);
  }
}

abstract class _ShiftData implements ShiftData {
  factory _ShiftData({
    final String shiftId,
    final String shiftName,
    @TimestampConverter() required final DateTime createdAt,
    final String startTime,
    final String endTime,
    final String organizationId,
    final List<String> locationIds,
    final List<String> checklistTemplateIds,
    final List<String> jobType,
    final Map<String, int> staffingLevels,
    final List<String> days,
    final bool repeatsDaily,
    required final List<int> activeDays,
    final List<String> assignedUserIds,
    final List<String> volunteers,
    final bool published,
    @NullableTimestampConverter() final DateTime? shiftDate,
    @NullableTimestampConverter() final DateTime? updatedAt,
  }) = _$ShiftDataImpl;

  factory _ShiftData.fromJson(Map<String, dynamic> json) =
      _$ShiftDataImpl.fromJson;

  @override
  String get shiftId;
  @override
  String get shiftName;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  String get startTime;
  @override
  String get endTime;
  @override
  String get organizationId;
  @override
  List<String> get locationIds;
  @override
  List<String> get checklistTemplateIds;
  @override
  List<String> get jobType;
  @override
  Map<String, int> get staffingLevels;
  @override
  List<String> get days;
  @override
  bool get repeatsDaily;
  @override
  List<int> get activeDays;
  @override
  List<String> get assignedUserIds;
  @override
  List<String> get volunteers;
  @override
  bool get published;
  @override
  @NullableTimestampConverter()
  DateTime? get shiftDate;
  @override
  @NullableTimestampConverter()
  DateTime? get updatedAt;

  /// Create a copy of ShiftData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShiftDataImplCopyWith<_$ShiftDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
