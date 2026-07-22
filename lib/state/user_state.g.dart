// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserStateDataImpl _$$UserStateDataImplFromJson(Map<String, dynamic> json) =>
    _$UserStateDataImpl(
      userData:
          json['userData'] == null
              ? null
              : UserData.fromJson(json['userData'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$UserStateDataImplToJson(_$UserStateDataImpl instance) =>
    <String, dynamic>{'userData': instance.userData};

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userStateHash() => r'c32d88e82f329b922e89bdc2b6871d00d3228c54';

/// See also [UserState].
@ProviderFor(UserState)
final userStateProvider = NotifierProvider<UserState, UserStateData>.internal(
  UserState.new,
  name: r'userStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UserState = Notifier<UserStateData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
