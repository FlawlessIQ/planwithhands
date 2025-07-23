// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UserData _$UserDataFromJson(Map<String, dynamic> json) {
  return _UserData.fromJson(json);
}

/// @nodoc
mixin _$UserData {
  @JsonKey(name: UserFieldNames.userId)
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: UserFieldNames.createdAt)
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: UserFieldNames.emailAddress)
  String get userEmail => throw _privateConstructorUsedError;
  @JsonKey(name: UserFieldNames.userRole)
  int get userRole => throw _privateConstructorUsedError; // Changed from accessLevel
  @JsonKey(name: UserFieldNames.organizationId)
  String get organizationId => throw _privateConstructorUsedError;
  @JsonKey(name: UserFieldNames.locationIds)
  List<String> get locationIds => throw _privateConstructorUsedError;
  @JsonKey(name: UserFieldNames.firstName)
  String get firstName => throw _privateConstructorUsedError;
  @JsonKey(name: UserFieldNames.lastName)
  String get lastName => throw _privateConstructorUsedError;
  @JsonKey(name: UserFieldNames.phoneNumber)
  String get phoneNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'jobTypes')
  List<String> get jobTypes => throw _privateConstructorUsedError;

  /// Serializes this UserData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserDataCopyWith<UserData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserDataCopyWith<$Res> {
  factory $UserDataCopyWith(UserData value, $Res Function(UserData) then) =
      _$UserDataCopyWithImpl<$Res, UserData>;
  @useResult
  $Res call({
    @JsonKey(name: UserFieldNames.userId) String userId,
    @JsonKey(name: UserFieldNames.createdAt)
    @TimestampConverter()
    DateTime createdAt,
    @JsonKey(name: UserFieldNames.emailAddress) String userEmail,
    @JsonKey(name: UserFieldNames.userRole) int userRole,
    @JsonKey(name: UserFieldNames.organizationId) String organizationId,
    @JsonKey(name: UserFieldNames.locationIds) List<String> locationIds,
    @JsonKey(name: UserFieldNames.firstName) String firstName,
    @JsonKey(name: UserFieldNames.lastName) String lastName,
    @JsonKey(name: UserFieldNames.phoneNumber) String phoneNumber,
    @JsonKey(name: 'jobTypes') List<String> jobTypes,
  });
}

/// @nodoc
class _$UserDataCopyWithImpl<$Res, $Val extends UserData>
    implements $UserDataCopyWith<$Res> {
  _$UserDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? createdAt = null,
    Object? userEmail = null,
    Object? userRole = null,
    Object? organizationId = null,
    Object? locationIds = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? phoneNumber = null,
    Object? jobTypes = null,
  }) {
    return _then(
      _value.copyWith(
            userId:
                null == userId
                    ? _value.userId
                    : userId // ignore: cast_nullable_to_non_nullable
                        as String,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            userEmail:
                null == userEmail
                    ? _value.userEmail
                    : userEmail // ignore: cast_nullable_to_non_nullable
                        as String,
            userRole:
                null == userRole
                    ? _value.userRole
                    : userRole // ignore: cast_nullable_to_non_nullable
                        as int,
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
            firstName:
                null == firstName
                    ? _value.firstName
                    : firstName // ignore: cast_nullable_to_non_nullable
                        as String,
            lastName:
                null == lastName
                    ? _value.lastName
                    : lastName // ignore: cast_nullable_to_non_nullable
                        as String,
            phoneNumber:
                null == phoneNumber
                    ? _value.phoneNumber
                    : phoneNumber // ignore: cast_nullable_to_non_nullable
                        as String,
            jobTypes:
                null == jobTypes
                    ? _value.jobTypes
                    : jobTypes // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserDataImplCopyWith<$Res>
    implements $UserDataCopyWith<$Res> {
  factory _$$UserDataImplCopyWith(
    _$UserDataImpl value,
    $Res Function(_$UserDataImpl) then,
  ) = __$$UserDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: UserFieldNames.userId) String userId,
    @JsonKey(name: UserFieldNames.createdAt)
    @TimestampConverter()
    DateTime createdAt,
    @JsonKey(name: UserFieldNames.emailAddress) String userEmail,
    @JsonKey(name: UserFieldNames.userRole) int userRole,
    @JsonKey(name: UserFieldNames.organizationId) String organizationId,
    @JsonKey(name: UserFieldNames.locationIds) List<String> locationIds,
    @JsonKey(name: UserFieldNames.firstName) String firstName,
    @JsonKey(name: UserFieldNames.lastName) String lastName,
    @JsonKey(name: UserFieldNames.phoneNumber) String phoneNumber,
    @JsonKey(name: 'jobTypes') List<String> jobTypes,
  });
}

/// @nodoc
class __$$UserDataImplCopyWithImpl<$Res>
    extends _$UserDataCopyWithImpl<$Res, _$UserDataImpl>
    implements _$$UserDataImplCopyWith<$Res> {
  __$$UserDataImplCopyWithImpl(
    _$UserDataImpl _value,
    $Res Function(_$UserDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? createdAt = null,
    Object? userEmail = null,
    Object? userRole = null,
    Object? organizationId = null,
    Object? locationIds = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? phoneNumber = null,
    Object? jobTypes = null,
  }) {
    return _then(
      _$UserDataImpl(
        userId:
            null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                    as String,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        userEmail:
            null == userEmail
                ? _value.userEmail
                : userEmail // ignore: cast_nullable_to_non_nullable
                    as String,
        userRole:
            null == userRole
                ? _value.userRole
                : userRole // ignore: cast_nullable_to_non_nullable
                    as int,
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
        firstName:
            null == firstName
                ? _value.firstName
                : firstName // ignore: cast_nullable_to_non_nullable
                    as String,
        lastName:
            null == lastName
                ? _value.lastName
                : lastName // ignore: cast_nullable_to_non_nullable
                    as String,
        phoneNumber:
            null == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                    as String,
        jobTypes:
            null == jobTypes
                ? _value._jobTypes
                : jobTypes // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserDataImpl implements _UserData {
  _$UserDataImpl({
    @JsonKey(name: UserFieldNames.userId) required this.userId,
    @JsonKey(name: UserFieldNames.createdAt)
    @TimestampConverter()
    required this.createdAt,
    @JsonKey(name: UserFieldNames.emailAddress) required this.userEmail,
    @JsonKey(name: UserFieldNames.userRole) required this.userRole,
    @JsonKey(name: UserFieldNames.organizationId) required this.organizationId,
    @JsonKey(name: UserFieldNames.locationIds)
    required final List<String> locationIds,
    @JsonKey(name: UserFieldNames.firstName) required this.firstName,
    @JsonKey(name: UserFieldNames.lastName) required this.lastName,
    @JsonKey(name: UserFieldNames.phoneNumber) required this.phoneNumber,
    @JsonKey(name: 'jobTypes') required final List<String> jobTypes,
  }) : _locationIds = locationIds,
       _jobTypes = jobTypes;

  factory _$UserDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserDataImplFromJson(json);

  @override
  @JsonKey(name: UserFieldNames.userId)
  final String userId;
  @override
  @JsonKey(name: UserFieldNames.createdAt)
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @JsonKey(name: UserFieldNames.emailAddress)
  final String userEmail;
  @override
  @JsonKey(name: UserFieldNames.userRole)
  final int userRole;
  // Changed from accessLevel
  @override
  @JsonKey(name: UserFieldNames.organizationId)
  final String organizationId;
  final List<String> _locationIds;
  @override
  @JsonKey(name: UserFieldNames.locationIds)
  List<String> get locationIds {
    if (_locationIds is EqualUnmodifiableListView) return _locationIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_locationIds);
  }

  @override
  @JsonKey(name: UserFieldNames.firstName)
  final String firstName;
  @override
  @JsonKey(name: UserFieldNames.lastName)
  final String lastName;
  @override
  @JsonKey(name: UserFieldNames.phoneNumber)
  final String phoneNumber;
  final List<String> _jobTypes;
  @override
  @JsonKey(name: 'jobTypes')
  List<String> get jobTypes {
    if (_jobTypes is EqualUnmodifiableListView) return _jobTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_jobTypes);
  }

  @override
  String toString() {
    return 'UserData(userId: $userId, createdAt: $createdAt, userEmail: $userEmail, userRole: $userRole, organizationId: $organizationId, locationIds: $locationIds, firstName: $firstName, lastName: $lastName, phoneNumber: $phoneNumber, jobTypes: $jobTypes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserDataImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.userEmail, userEmail) ||
                other.userEmail == userEmail) &&
            (identical(other.userRole, userRole) ||
                other.userRole == userRole) &&
            (identical(other.organizationId, organizationId) ||
                other.organizationId == organizationId) &&
            const DeepCollectionEquality().equals(
              other._locationIds,
              _locationIds,
            ) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            const DeepCollectionEquality().equals(other._jobTypes, _jobTypes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    createdAt,
    userEmail,
    userRole,
    organizationId,
    const DeepCollectionEquality().hash(_locationIds),
    firstName,
    lastName,
    phoneNumber,
    const DeepCollectionEquality().hash(_jobTypes),
  );

  /// Create a copy of UserData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserDataImplCopyWith<_$UserDataImpl> get copyWith =>
      __$$UserDataImplCopyWithImpl<_$UserDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserDataImplToJson(this);
  }
}

abstract class _UserData implements UserData {
  factory _UserData({
    @JsonKey(name: UserFieldNames.userId) required final String userId,
    @JsonKey(name: UserFieldNames.createdAt)
    @TimestampConverter()
    required final DateTime createdAt,
    @JsonKey(name: UserFieldNames.emailAddress) required final String userEmail,
    @JsonKey(name: UserFieldNames.userRole) required final int userRole,
    @JsonKey(name: UserFieldNames.organizationId)
    required final String organizationId,
    @JsonKey(name: UserFieldNames.locationIds)
    required final List<String> locationIds,
    @JsonKey(name: UserFieldNames.firstName) required final String firstName,
    @JsonKey(name: UserFieldNames.lastName) required final String lastName,
    @JsonKey(name: UserFieldNames.phoneNumber)
    required final String phoneNumber,
    @JsonKey(name: 'jobTypes') required final List<String> jobTypes,
  }) = _$UserDataImpl;

  factory _UserData.fromJson(Map<String, dynamic> json) =
      _$UserDataImpl.fromJson;

  @override
  @JsonKey(name: UserFieldNames.userId)
  String get userId;
  @override
  @JsonKey(name: UserFieldNames.createdAt)
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @JsonKey(name: UserFieldNames.emailAddress)
  String get userEmail;
  @override
  @JsonKey(name: UserFieldNames.userRole)
  int get userRole; // Changed from accessLevel
  @override
  @JsonKey(name: UserFieldNames.organizationId)
  String get organizationId;
  @override
  @JsonKey(name: UserFieldNames.locationIds)
  List<String> get locationIds;
  @override
  @JsonKey(name: UserFieldNames.firstName)
  String get firstName;
  @override
  @JsonKey(name: UserFieldNames.lastName)
  String get lastName;
  @override
  @JsonKey(name: UserFieldNames.phoneNumber)
  String get phoneNumber;
  @override
  @JsonKey(name: 'jobTypes')
  List<String> get jobTypes;

  /// Create a copy of UserData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserDataImplCopyWith<_$UserDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
