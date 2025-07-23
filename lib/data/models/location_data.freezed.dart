// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'location_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

LocationData _$LocationDataFromJson(Map<String, dynamic> json) {
  return _LocationData.fromJson(json);
}

/// @nodoc
mixin _$LocationData {
  String get locationId => throw _privateConstructorUsedError;
  String get locationName => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get locationAddress => throw _privateConstructorUsedError;
  @ShiftDataListConverter()
  List<ShiftData> get shifts => throw _privateConstructorUsedError;

  /// Serializes this LocationData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LocationDataCopyWith<LocationData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LocationDataCopyWith<$Res> {
  factory $LocationDataCopyWith(
    LocationData value,
    $Res Function(LocationData) then,
  ) = _$LocationDataCopyWithImpl<$Res, LocationData>;
  @useResult
  $Res call({
    String locationId,
    String locationName,
    DateTime createdAt,
    String locationAddress,
    @ShiftDataListConverter() List<ShiftData> shifts,
  });
}

/// @nodoc
class _$LocationDataCopyWithImpl<$Res, $Val extends LocationData>
    implements $LocationDataCopyWith<$Res> {
  _$LocationDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? locationId = null,
    Object? locationName = null,
    Object? createdAt = null,
    Object? locationAddress = null,
    Object? shifts = null,
  }) {
    return _then(
      _value.copyWith(
            locationId:
                null == locationId
                    ? _value.locationId
                    : locationId // ignore: cast_nullable_to_non_nullable
                        as String,
            locationName:
                null == locationName
                    ? _value.locationName
                    : locationName // ignore: cast_nullable_to_non_nullable
                        as String,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            locationAddress:
                null == locationAddress
                    ? _value.locationAddress
                    : locationAddress // ignore: cast_nullable_to_non_nullable
                        as String,
            shifts:
                null == shifts
                    ? _value.shifts
                    : shifts // ignore: cast_nullable_to_non_nullable
                        as List<ShiftData>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$LocationDataImplCopyWith<$Res>
    implements $LocationDataCopyWith<$Res> {
  factory _$$LocationDataImplCopyWith(
    _$LocationDataImpl value,
    $Res Function(_$LocationDataImpl) then,
  ) = __$$LocationDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String locationId,
    String locationName,
    DateTime createdAt,
    String locationAddress,
    @ShiftDataListConverter() List<ShiftData> shifts,
  });
}

/// @nodoc
class __$$LocationDataImplCopyWithImpl<$Res>
    extends _$LocationDataCopyWithImpl<$Res, _$LocationDataImpl>
    implements _$$LocationDataImplCopyWith<$Res> {
  __$$LocationDataImplCopyWithImpl(
    _$LocationDataImpl _value,
    $Res Function(_$LocationDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? locationId = null,
    Object? locationName = null,
    Object? createdAt = null,
    Object? locationAddress = null,
    Object? shifts = null,
  }) {
    return _then(
      _$LocationDataImpl(
        locationId:
            null == locationId
                ? _value.locationId
                : locationId // ignore: cast_nullable_to_non_nullable
                    as String,
        locationName:
            null == locationName
                ? _value.locationName
                : locationName // ignore: cast_nullable_to_non_nullable
                    as String,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        locationAddress:
            null == locationAddress
                ? _value.locationAddress
                : locationAddress // ignore: cast_nullable_to_non_nullable
                    as String,
        shifts:
            null == shifts
                ? _value._shifts
                : shifts // ignore: cast_nullable_to_non_nullable
                    as List<ShiftData>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$LocationDataImpl implements _LocationData {
  _$LocationDataImpl({
    required this.locationId,
    required this.locationName,
    required this.createdAt,
    required this.locationAddress,
    @ShiftDataListConverter() final List<ShiftData> shifts = const [],
  }) : _shifts = shifts;

  factory _$LocationDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$LocationDataImplFromJson(json);

  @override
  final String locationId;
  @override
  final String locationName;
  @override
  final DateTime createdAt;
  @override
  final String locationAddress;
  final List<ShiftData> _shifts;
  @override
  @JsonKey()
  @ShiftDataListConverter()
  List<ShiftData> get shifts {
    if (_shifts is EqualUnmodifiableListView) return _shifts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_shifts);
  }

  @override
  String toString() {
    return 'LocationData(locationId: $locationId, locationName: $locationName, createdAt: $createdAt, locationAddress: $locationAddress, shifts: $shifts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LocationDataImpl &&
            (identical(other.locationId, locationId) ||
                other.locationId == locationId) &&
            (identical(other.locationName, locationName) ||
                other.locationName == locationName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.locationAddress, locationAddress) ||
                other.locationAddress == locationAddress) &&
            const DeepCollectionEquality().equals(other._shifts, _shifts));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    locationId,
    locationName,
    createdAt,
    locationAddress,
    const DeepCollectionEquality().hash(_shifts),
  );

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LocationDataImplCopyWith<_$LocationDataImpl> get copyWith =>
      __$$LocationDataImplCopyWithImpl<_$LocationDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LocationDataImplToJson(this);
  }
}

abstract class _LocationData implements LocationData {
  factory _LocationData({
    required final String locationId,
    required final String locationName,
    required final DateTime createdAt,
    required final String locationAddress,
    @ShiftDataListConverter() final List<ShiftData> shifts,
  }) = _$LocationDataImpl;

  factory _LocationData.fromJson(Map<String, dynamic> json) =
      _$LocationDataImpl.fromJson;

  @override
  String get locationId;
  @override
  String get locationName;
  @override
  DateTime get createdAt;
  @override
  String get locationAddress;
  @override
  @ShiftDataListConverter()
  List<ShiftData> get shifts;

  /// Create a copy of LocationData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LocationDataImplCopyWith<_$LocationDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
