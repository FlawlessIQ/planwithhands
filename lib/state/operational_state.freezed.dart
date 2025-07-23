// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'operational_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

OperationalStateData _$OperationalStateDataFromJson(Map<String, dynamic> json) {
  return _OperationalStateData.fromJson(json);
}

/// @nodoc
mixin _$OperationalStateData {
  OrganizationData? get organizationData => throw _privateConstructorUsedError;
  LocationData? get selectedLocation => throw _privateConstructorUsedError;
  @ShiftDataConverter()
  ShiftData? get selectedShift => throw _privateConstructorUsedError;
  List<String> get expandedChecklists => throw _privateConstructorUsedError;
  List<String> get dashboardFilters => throw _privateConstructorUsedError;

  /// Serializes this OperationalStateData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OperationalStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OperationalStateDataCopyWith<OperationalStateData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OperationalStateDataCopyWith<$Res> {
  factory $OperationalStateDataCopyWith(
    OperationalStateData value,
    $Res Function(OperationalStateData) then,
  ) = _$OperationalStateDataCopyWithImpl<$Res, OperationalStateData>;
  @useResult
  $Res call({
    OrganizationData? organizationData,
    LocationData? selectedLocation,
    @ShiftDataConverter() ShiftData? selectedShift,
    List<String> expandedChecklists,
    List<String> dashboardFilters,
  });

  $OrganizationDataCopyWith<$Res>? get organizationData;
  $LocationDataCopyWith<$Res>? get selectedLocation;
  $ShiftDataCopyWith<$Res>? get selectedShift;
}

/// @nodoc
class _$OperationalStateDataCopyWithImpl<
  $Res,
  $Val extends OperationalStateData
>
    implements $OperationalStateDataCopyWith<$Res> {
  _$OperationalStateDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OperationalStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? organizationData = freezed,
    Object? selectedLocation = freezed,
    Object? selectedShift = freezed,
    Object? expandedChecklists = null,
    Object? dashboardFilters = null,
  }) {
    return _then(
      _value.copyWith(
            organizationData:
                freezed == organizationData
                    ? _value.organizationData
                    : organizationData // ignore: cast_nullable_to_non_nullable
                        as OrganizationData?,
            selectedLocation:
                freezed == selectedLocation
                    ? _value.selectedLocation
                    : selectedLocation // ignore: cast_nullable_to_non_nullable
                        as LocationData?,
            selectedShift:
                freezed == selectedShift
                    ? _value.selectedShift
                    : selectedShift // ignore: cast_nullable_to_non_nullable
                        as ShiftData?,
            expandedChecklists:
                null == expandedChecklists
                    ? _value.expandedChecklists
                    : expandedChecklists // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            dashboardFilters:
                null == dashboardFilters
                    ? _value.dashboardFilters
                    : dashboardFilters // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }

  /// Create a copy of OperationalStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OrganizationDataCopyWith<$Res>? get organizationData {
    if (_value.organizationData == null) {
      return null;
    }

    return $OrganizationDataCopyWith<$Res>(_value.organizationData!, (value) {
      return _then(_value.copyWith(organizationData: value) as $Val);
    });
  }

  /// Create a copy of OperationalStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationDataCopyWith<$Res>? get selectedLocation {
    if (_value.selectedLocation == null) {
      return null;
    }

    return $LocationDataCopyWith<$Res>(_value.selectedLocation!, (value) {
      return _then(_value.copyWith(selectedLocation: value) as $Val);
    });
  }

  /// Create a copy of OperationalStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShiftDataCopyWith<$Res>? get selectedShift {
    if (_value.selectedShift == null) {
      return null;
    }

    return $ShiftDataCopyWith<$Res>(_value.selectedShift!, (value) {
      return _then(_value.copyWith(selectedShift: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OperationalStateDataImplCopyWith<$Res>
    implements $OperationalStateDataCopyWith<$Res> {
  factory _$$OperationalStateDataImplCopyWith(
    _$OperationalStateDataImpl value,
    $Res Function(_$OperationalStateDataImpl) then,
  ) = __$$OperationalStateDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    OrganizationData? organizationData,
    LocationData? selectedLocation,
    @ShiftDataConverter() ShiftData? selectedShift,
    List<String> expandedChecklists,
    List<String> dashboardFilters,
  });

  @override
  $OrganizationDataCopyWith<$Res>? get organizationData;
  @override
  $LocationDataCopyWith<$Res>? get selectedLocation;
  @override
  $ShiftDataCopyWith<$Res>? get selectedShift;
}

/// @nodoc
class __$$OperationalStateDataImplCopyWithImpl<$Res>
    extends _$OperationalStateDataCopyWithImpl<$Res, _$OperationalStateDataImpl>
    implements _$$OperationalStateDataImplCopyWith<$Res> {
  __$$OperationalStateDataImplCopyWithImpl(
    _$OperationalStateDataImpl _value,
    $Res Function(_$OperationalStateDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OperationalStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? organizationData = freezed,
    Object? selectedLocation = freezed,
    Object? selectedShift = freezed,
    Object? expandedChecklists = null,
    Object? dashboardFilters = null,
  }) {
    return _then(
      _$OperationalStateDataImpl(
        organizationData:
            freezed == organizationData
                ? _value.organizationData
                : organizationData // ignore: cast_nullable_to_non_nullable
                    as OrganizationData?,
        selectedLocation:
            freezed == selectedLocation
                ? _value.selectedLocation
                : selectedLocation // ignore: cast_nullable_to_non_nullable
                    as LocationData?,
        selectedShift:
            freezed == selectedShift
                ? _value.selectedShift
                : selectedShift // ignore: cast_nullable_to_non_nullable
                    as ShiftData?,
        expandedChecklists:
            null == expandedChecklists
                ? _value._expandedChecklists
                : expandedChecklists // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        dashboardFilters:
            null == dashboardFilters
                ? _value._dashboardFilters
                : dashboardFilters // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OperationalStateDataImpl implements _OperationalStateData {
  _$OperationalStateDataImpl({
    this.organizationData,
    this.selectedLocation,
    @ShiftDataConverter() this.selectedShift,
    final List<String> expandedChecklists = const [],
    final List<String> dashboardFilters = const ['completed', 'incomplete'],
  }) : _expandedChecklists = expandedChecklists,
       _dashboardFilters = dashboardFilters;

  factory _$OperationalStateDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$OperationalStateDataImplFromJson(json);

  @override
  final OrganizationData? organizationData;
  @override
  final LocationData? selectedLocation;
  @override
  @ShiftDataConverter()
  final ShiftData? selectedShift;
  final List<String> _expandedChecklists;
  @override
  @JsonKey()
  List<String> get expandedChecklists {
    if (_expandedChecklists is EqualUnmodifiableListView)
      return _expandedChecklists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_expandedChecklists);
  }

  final List<String> _dashboardFilters;
  @override
  @JsonKey()
  List<String> get dashboardFilters {
    if (_dashboardFilters is EqualUnmodifiableListView)
      return _dashboardFilters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dashboardFilters);
  }

  @override
  String toString() {
    return 'OperationalStateData(organizationData: $organizationData, selectedLocation: $selectedLocation, selectedShift: $selectedShift, expandedChecklists: $expandedChecklists, dashboardFilters: $dashboardFilters)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OperationalStateDataImpl &&
            (identical(other.organizationData, organizationData) ||
                other.organizationData == organizationData) &&
            (identical(other.selectedLocation, selectedLocation) ||
                other.selectedLocation == selectedLocation) &&
            (identical(other.selectedShift, selectedShift) ||
                other.selectedShift == selectedShift) &&
            const DeepCollectionEquality().equals(
              other._expandedChecklists,
              _expandedChecklists,
            ) &&
            const DeepCollectionEquality().equals(
              other._dashboardFilters,
              _dashboardFilters,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    organizationData,
    selectedLocation,
    selectedShift,
    const DeepCollectionEquality().hash(_expandedChecklists),
    const DeepCollectionEquality().hash(_dashboardFilters),
  );

  /// Create a copy of OperationalStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OperationalStateDataImplCopyWith<_$OperationalStateDataImpl>
  get copyWith =>
      __$$OperationalStateDataImplCopyWithImpl<_$OperationalStateDataImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$OperationalStateDataImplToJson(this);
  }
}

abstract class _OperationalStateData implements OperationalStateData {
  factory _OperationalStateData({
    final OrganizationData? organizationData,
    final LocationData? selectedLocation,
    @ShiftDataConverter() final ShiftData? selectedShift,
    final List<String> expandedChecklists,
    final List<String> dashboardFilters,
  }) = _$OperationalStateDataImpl;

  factory _OperationalStateData.fromJson(Map<String, dynamic> json) =
      _$OperationalStateDataImpl.fromJson;

  @override
  OrganizationData? get organizationData;
  @override
  LocationData? get selectedLocation;
  @override
  @ShiftDataConverter()
  ShiftData? get selectedShift;
  @override
  List<String> get expandedChecklists;
  @override
  List<String> get dashboardFilters;

  /// Create a copy of OperationalStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OperationalStateDataImplCopyWith<_$OperationalStateDataImpl>
  get copyWith => throw _privateConstructorUsedError;
}
