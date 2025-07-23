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

String _$userStateHash() => r'e8678c2f56937f044bed90f182a315d73c812fd6';

/// See also [UserState].
@ProviderFor(UserState)
final userStateProvider =
    AutoDisposeNotifierProvider<UserState, UserStateData>.internal(
      UserState.new,
      name: r'userStateProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$userStateHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserState = AutoDisposeNotifier<UserStateData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
