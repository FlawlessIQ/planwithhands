// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

OrganizationData _$OrganizationDataFromJson(Map<String, dynamic> json) {
  return _OrganizationData.fromJson(json);
}

/// @nodoc
mixin _$OrganizationData {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String get subscriptionStatus => throw _privateConstructorUsedError;
  int get employeeCount => throw _privateConstructorUsedError;
  String? get stripeCustomerId => throw _privateConstructorUsedError;
  String? get stripeSubscriptionId => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  List<LocationData> get locations => throw _privateConstructorUsedError;

  /// Serializes this OrganizationData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrganizationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrganizationDataCopyWith<OrganizationData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrganizationDataCopyWith<$Res> {
  factory $OrganizationDataCopyWith(
    OrganizationData value,
    $Res Function(OrganizationData) then,
  ) = _$OrganizationDataCopyWithImpl<$Res, OrganizationData>;
  @useResult
  $Res call({
    String id,
    String name,
    String address,
    String phone,
    String subscriptionStatus,
    int employeeCount,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    @TimestampConverter() DateTime createdAt,
    List<LocationData> locations,
  });
}

/// @nodoc
class _$OrganizationDataCopyWithImpl<$Res, $Val extends OrganizationData>
    implements $OrganizationDataCopyWith<$Res> {
  _$OrganizationDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrganizationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? address = null,
    Object? phone = null,
    Object? subscriptionStatus = null,
    Object? employeeCount = null,
    Object? stripeCustomerId = freezed,
    Object? stripeSubscriptionId = freezed,
    Object? createdAt = null,
    Object? locations = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            address:
                null == address
                    ? _value.address
                    : address // ignore: cast_nullable_to_non_nullable
                        as String,
            phone:
                null == phone
                    ? _value.phone
                    : phone // ignore: cast_nullable_to_non_nullable
                        as String,
            subscriptionStatus:
                null == subscriptionStatus
                    ? _value.subscriptionStatus
                    : subscriptionStatus // ignore: cast_nullable_to_non_nullable
                        as String,
            employeeCount:
                null == employeeCount
                    ? _value.employeeCount
                    : employeeCount // ignore: cast_nullable_to_non_nullable
                        as int,
            stripeCustomerId:
                freezed == stripeCustomerId
                    ? _value.stripeCustomerId
                    : stripeCustomerId // ignore: cast_nullable_to_non_nullable
                        as String?,
            stripeSubscriptionId:
                freezed == stripeSubscriptionId
                    ? _value.stripeSubscriptionId
                    : stripeSubscriptionId // ignore: cast_nullable_to_non_nullable
                        as String?,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            locations:
                null == locations
                    ? _value.locations
                    : locations // ignore: cast_nullable_to_non_nullable
                        as List<LocationData>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrganizationDataImplCopyWith<$Res>
    implements $OrganizationDataCopyWith<$Res> {
  factory _$$OrganizationDataImplCopyWith(
    _$OrganizationDataImpl value,
    $Res Function(_$OrganizationDataImpl) then,
  ) = __$$OrganizationDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String address,
    String phone,
    String subscriptionStatus,
    int employeeCount,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    @TimestampConverter() DateTime createdAt,
    List<LocationData> locations,
  });
}

/// @nodoc
class __$$OrganizationDataImplCopyWithImpl<$Res>
    extends _$OrganizationDataCopyWithImpl<$Res, _$OrganizationDataImpl>
    implements _$$OrganizationDataImplCopyWith<$Res> {
  __$$OrganizationDataImplCopyWithImpl(
    _$OrganizationDataImpl _value,
    $Res Function(_$OrganizationDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrganizationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? address = null,
    Object? phone = null,
    Object? subscriptionStatus = null,
    Object? employeeCount = null,
    Object? stripeCustomerId = freezed,
    Object? stripeSubscriptionId = freezed,
    Object? createdAt = null,
    Object? locations = null,
  }) {
    return _then(
      _$OrganizationDataImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        address:
            null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                    as String,
        phone:
            null == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                    as String,
        subscriptionStatus:
            null == subscriptionStatus
                ? _value.subscriptionStatus
                : subscriptionStatus // ignore: cast_nullable_to_non_nullable
                    as String,
        employeeCount:
            null == employeeCount
                ? _value.employeeCount
                : employeeCount // ignore: cast_nullable_to_non_nullable
                    as int,
        stripeCustomerId:
            freezed == stripeCustomerId
                ? _value.stripeCustomerId
                : stripeCustomerId // ignore: cast_nullable_to_non_nullable
                    as String?,
        stripeSubscriptionId:
            freezed == stripeSubscriptionId
                ? _value.stripeSubscriptionId
                : stripeSubscriptionId // ignore: cast_nullable_to_non_nullable
                    as String?,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        locations:
            null == locations
                ? _value._locations
                : locations // ignore: cast_nullable_to_non_nullable
                    as List<LocationData>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrganizationDataImpl implements _OrganizationData {
  const _$OrganizationDataImpl({
    this.id = '',
    this.name = '',
    this.address = '',
    this.phone = '',
    this.subscriptionStatus = 'pending',
    this.employeeCount = 0,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    @TimestampConverter() required this.createdAt,
    final List<LocationData> locations = const [],
  }) : _locations = locations;

  factory _$OrganizationDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrganizationDataImplFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String address;
  @override
  @JsonKey()
  final String phone;
  @override
  @JsonKey()
  final String subscriptionStatus;
  @override
  @JsonKey()
  final int employeeCount;
  @override
  final String? stripeCustomerId;
  @override
  final String? stripeSubscriptionId;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  final List<LocationData> _locations;
  @override
  @JsonKey()
  List<LocationData> get locations {
    if (_locations is EqualUnmodifiableListView) return _locations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_locations);
  }

  @override
  String toString() {
    return 'OrganizationData(id: $id, name: $name, address: $address, phone: $phone, subscriptionStatus: $subscriptionStatus, employeeCount: $employeeCount, stripeCustomerId: $stripeCustomerId, stripeSubscriptionId: $stripeSubscriptionId, createdAt: $createdAt, locations: $locations)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrganizationDataImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.subscriptionStatus, subscriptionStatus) ||
                other.subscriptionStatus == subscriptionStatus) &&
            (identical(other.employeeCount, employeeCount) ||
                other.employeeCount == employeeCount) &&
            (identical(other.stripeCustomerId, stripeCustomerId) ||
                other.stripeCustomerId == stripeCustomerId) &&
            (identical(other.stripeSubscriptionId, stripeSubscriptionId) ||
                other.stripeSubscriptionId == stripeSubscriptionId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            const DeepCollectionEquality().equals(
              other._locations,
              _locations,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    address,
    phone,
    subscriptionStatus,
    employeeCount,
    stripeCustomerId,
    stripeSubscriptionId,
    createdAt,
    const DeepCollectionEquality().hash(_locations),
  );

  /// Create a copy of OrganizationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrganizationDataImplCopyWith<_$OrganizationDataImpl> get copyWith =>
      __$$OrganizationDataImplCopyWithImpl<_$OrganizationDataImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$OrganizationDataImplToJson(this);
  }
}

abstract class _OrganizationData implements OrganizationData {
  const factory _OrganizationData({
    final String id,
    final String name,
    final String address,
    final String phone,
    final String subscriptionStatus,
    final int employeeCount,
    final String? stripeCustomerId,
    final String? stripeSubscriptionId,
    @TimestampConverter() required final DateTime createdAt,
    final List<LocationData> locations,
  }) = _$OrganizationDataImpl;

  factory _OrganizationData.fromJson(Map<String, dynamic> json) =
      _$OrganizationDataImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get address;
  @override
  String get phone;
  @override
  String get subscriptionStatus;
  @override
  int get employeeCount;
  @override
  String? get stripeCustomerId;
  @override
  String? get stripeSubscriptionId;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  List<LocationData> get locations;

  /// Create a copy of OrganizationData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrganizationDataImplCopyWith<_$OrganizationDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
