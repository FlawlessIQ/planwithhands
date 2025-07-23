// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AppStateData _$AppStateDataFromJson(Map<String, dynamic> json) {
  return _AppStateData.fromJson(json);
}

/// @nodoc
mixin _$AppStateData {
  int get currentPageIndex => throw _privateConstructorUsedError;
  bool get isSettingsOpen => throw _privateConstructorUsedError;
  LocationData? get selectedLocation => throw _privateConstructorUsedError;
  @ShiftDataConverter()
  ShiftData? get selectedShift => throw _privateConstructorUsedError;
  ChecklistData? get selectedChecklist => throw _privateConstructorUsedError;

  /// Serializes this AppStateData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppStateDataCopyWith<AppStateData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppStateDataCopyWith<$Res> {
  factory $AppStateDataCopyWith(
    AppStateData value,
    $Res Function(AppStateData) then,
  ) = _$AppStateDataCopyWithImpl<$Res, AppStateData>;
  @useResult
  $Res call({
    int currentPageIndex,
    bool isSettingsOpen,
    LocationData? selectedLocation,
    @ShiftDataConverter() ShiftData? selectedShift,
    ChecklistData? selectedChecklist,
  });

  $LocationDataCopyWith<$Res>? get selectedLocation;
  $ShiftDataCopyWith<$Res>? get selectedShift;
  $ChecklistDataCopyWith<$Res>? get selectedChecklist;
}

/// @nodoc
class _$AppStateDataCopyWithImpl<$Res, $Val extends AppStateData>
    implements $AppStateDataCopyWith<$Res> {
  _$AppStateDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentPageIndex = null,
    Object? isSettingsOpen = null,
    Object? selectedLocation = freezed,
    Object? selectedShift = freezed,
    Object? selectedChecklist = freezed,
  }) {
    return _then(
      _value.copyWith(
            currentPageIndex:
                null == currentPageIndex
                    ? _value.currentPageIndex
                    : currentPageIndex // ignore: cast_nullable_to_non_nullable
                        as int,
            isSettingsOpen:
                null == isSettingsOpen
                    ? _value.isSettingsOpen
                    : isSettingsOpen // ignore: cast_nullable_to_non_nullable
                        as bool,
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
            selectedChecklist:
                freezed == selectedChecklist
                    ? _value.selectedChecklist
                    : selectedChecklist // ignore: cast_nullable_to_non_nullable
                        as ChecklistData?,
          )
          as $Val,
    );
  }

  /// Create a copy of AppStateData
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

  /// Create a copy of AppStateData
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

  /// Create a copy of AppStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ChecklistDataCopyWith<$Res>? get selectedChecklist {
    if (_value.selectedChecklist == null) {
      return null;
    }

    return $ChecklistDataCopyWith<$Res>(_value.selectedChecklist!, (value) {
      return _then(_value.copyWith(selectedChecklist: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AppStateDataImplCopyWith<$Res>
    implements $AppStateDataCopyWith<$Res> {
  factory _$$AppStateDataImplCopyWith(
    _$AppStateDataImpl value,
    $Res Function(_$AppStateDataImpl) then,
  ) = __$$AppStateDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int currentPageIndex,
    bool isSettingsOpen,
    LocationData? selectedLocation,
    @ShiftDataConverter() ShiftData? selectedShift,
    ChecklistData? selectedChecklist,
  });

  @override
  $LocationDataCopyWith<$Res>? get selectedLocation;
  @override
  $ShiftDataCopyWith<$Res>? get selectedShift;
  @override
  $ChecklistDataCopyWith<$Res>? get selectedChecklist;
}

/// @nodoc
class __$$AppStateDataImplCopyWithImpl<$Res>
    extends _$AppStateDataCopyWithImpl<$Res, _$AppStateDataImpl>
    implements _$$AppStateDataImplCopyWith<$Res> {
  __$$AppStateDataImplCopyWithImpl(
    _$AppStateDataImpl _value,
    $Res Function(_$AppStateDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? currentPageIndex = null,
    Object? isSettingsOpen = null,
    Object? selectedLocation = freezed,
    Object? selectedShift = freezed,
    Object? selectedChecklist = freezed,
  }) {
    return _then(
      _$AppStateDataImpl(
        currentPageIndex:
            null == currentPageIndex
                ? _value.currentPageIndex
                : currentPageIndex // ignore: cast_nullable_to_non_nullable
                    as int,
        isSettingsOpen:
            null == isSettingsOpen
                ? _value.isSettingsOpen
                : isSettingsOpen // ignore: cast_nullable_to_non_nullable
                    as bool,
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
        selectedChecklist:
            freezed == selectedChecklist
                ? _value.selectedChecklist
                : selectedChecklist // ignore: cast_nullable_to_non_nullable
                    as ChecklistData?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppStateDataImpl implements _AppStateData {
  _$AppStateDataImpl({
    this.currentPageIndex = 0,
    this.isSettingsOpen = false,
    this.selectedLocation,
    @ShiftDataConverter() this.selectedShift,
    this.selectedChecklist,
  });

  factory _$AppStateDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppStateDataImplFromJson(json);

  @override
  @JsonKey()
  final int currentPageIndex;
  @override
  @JsonKey()
  final bool isSettingsOpen;
  @override
  final LocationData? selectedLocation;
  @override
  @ShiftDataConverter()
  final ShiftData? selectedShift;
  @override
  final ChecklistData? selectedChecklist;

  @override
  String toString() {
    return 'AppStateData(currentPageIndex: $currentPageIndex, isSettingsOpen: $isSettingsOpen, selectedLocation: $selectedLocation, selectedShift: $selectedShift, selectedChecklist: $selectedChecklist)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppStateDataImpl &&
            (identical(other.currentPageIndex, currentPageIndex) ||
                other.currentPageIndex == currentPageIndex) &&
            (identical(other.isSettingsOpen, isSettingsOpen) ||
                other.isSettingsOpen == isSettingsOpen) &&
            (identical(other.selectedLocation, selectedLocation) ||
                other.selectedLocation == selectedLocation) &&
            (identical(other.selectedShift, selectedShift) ||
                other.selectedShift == selectedShift) &&
            (identical(other.selectedChecklist, selectedChecklist) ||
                other.selectedChecklist == selectedChecklist));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    currentPageIndex,
    isSettingsOpen,
    selectedLocation,
    selectedShift,
    selectedChecklist,
  );

  /// Create a copy of AppStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppStateDataImplCopyWith<_$AppStateDataImpl> get copyWith =>
      __$$AppStateDataImplCopyWithImpl<_$AppStateDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppStateDataImplToJson(this);
  }
}

abstract class _AppStateData implements AppStateData {
  factory _AppStateData({
    final int currentPageIndex,
    final bool isSettingsOpen,
    final LocationData? selectedLocation,
    @ShiftDataConverter() final ShiftData? selectedShift,
    final ChecklistData? selectedChecklist,
  }) = _$AppStateDataImpl;

  factory _AppStateData.fromJson(Map<String, dynamic> json) =
      _$AppStateDataImpl.fromJson;

  @override
  int get currentPageIndex;
  @override
  bool get isSettingsOpen;
  @override
  LocationData? get selectedLocation;
  @override
  @ShiftDataConverter()
  ShiftData? get selectedShift;
  @override
  ChecklistData? get selectedChecklist;

  /// Create a copy of AppStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppStateDataImplCopyWith<_$AppStateDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
