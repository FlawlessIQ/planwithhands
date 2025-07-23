// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UserStateData _$UserStateDataFromJson(Map<String, dynamic> json) {
  return _UserStateData.fromJson(json);
}

/// @nodoc
mixin _$UserStateData {
  UserData? get userData => throw _privateConstructorUsedError;

  /// Serializes this UserStateData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserStateDataCopyWith<UserStateData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserStateDataCopyWith<$Res> {
  factory $UserStateDataCopyWith(
    UserStateData value,
    $Res Function(UserStateData) then,
  ) = _$UserStateDataCopyWithImpl<$Res, UserStateData>;
  @useResult
  $Res call({UserData? userData});

  $UserDataCopyWith<$Res>? get userData;
}

/// @nodoc
class _$UserStateDataCopyWithImpl<$Res, $Val extends UserStateData>
    implements $UserStateDataCopyWith<$Res> {
  _$UserStateDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? userData = freezed}) {
    return _then(
      _value.copyWith(
            userData:
                freezed == userData
                    ? _value.userData
                    : userData // ignore: cast_nullable_to_non_nullable
                        as UserData?,
          )
          as $Val,
    );
  }

  /// Create a copy of UserStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserDataCopyWith<$Res>? get userData {
    if (_value.userData == null) {
      return null;
    }

    return $UserDataCopyWith<$Res>(_value.userData!, (value) {
      return _then(_value.copyWith(userData: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UserStateDataImplCopyWith<$Res>
    implements $UserStateDataCopyWith<$Res> {
  factory _$$UserStateDataImplCopyWith(
    _$UserStateDataImpl value,
    $Res Function(_$UserStateDataImpl) then,
  ) = __$$UserStateDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({UserData? userData});

  @override
  $UserDataCopyWith<$Res>? get userData;
}

/// @nodoc
class __$$UserStateDataImplCopyWithImpl<$Res>
    extends _$UserStateDataCopyWithImpl<$Res, _$UserStateDataImpl>
    implements _$$UserStateDataImplCopyWith<$Res> {
  __$$UserStateDataImplCopyWithImpl(
    _$UserStateDataImpl _value,
    $Res Function(_$UserStateDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserStateData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? userData = freezed}) {
    return _then(
      _$UserStateDataImpl(
        userData:
            freezed == userData
                ? _value.userData
                : userData // ignore: cast_nullable_to_non_nullable
                    as UserData?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserStateDataImpl implements _UserStateData {
  _$UserStateDataImpl({this.userData});

  factory _$UserStateDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserStateDataImplFromJson(json);

  @override
  final UserData? userData;

  @override
  String toString() {
    return 'UserStateData(userData: $userData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserStateDataImpl &&
            (identical(other.userData, userData) ||
                other.userData == userData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, userData);

  /// Create a copy of UserStateData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserStateDataImplCopyWith<_$UserStateDataImpl> get copyWith =>
      __$$UserStateDataImplCopyWithImpl<_$UserStateDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserStateDataImplToJson(this);
  }
}

abstract class _UserStateData implements UserStateData {
  factory _UserStateData({final UserData? userData}) = _$UserStateDataImpl;

  factory _UserStateData.fromJson(Map<String, dynamic> json) =
      _$UserStateDataImpl.fromJson;

  @override
  UserData? get userData;

  /// Create a copy of UserStateData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserStateDataImplCopyWith<_$UserStateDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
