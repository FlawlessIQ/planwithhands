// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operational_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OperationalStateDataImpl _$$OperationalStateDataImplFromJson(
  Map<String, dynamic> json,
) => _$OperationalStateDataImpl(
  organizationData:
      json['organizationData'] == null
          ? null
          : OrganizationData.fromJson(
            json['organizationData'] as Map<String, dynamic>,
          ),
  selectedLocation:
      json['selectedLocation'] == null
          ? null
          : LocationData.fromJson(
            json['selectedLocation'] as Map<String, dynamic>,
          ),
  selectedShift: _$JsonConverterFromJson<Map<String, dynamic>, ShiftData>(
    json['selectedShift'],
    const ShiftDataConverter().fromJson,
  ),
  expandedChecklists:
      (json['expandedChecklists'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  dashboardFilters:
      (json['dashboardFilters'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const ['completed', 'incomplete'],
);

Map<String, dynamic> _$$OperationalStateDataImplToJson(
  _$OperationalStateDataImpl instance,
) => <String, dynamic>{
  'organizationData': instance.organizationData,
  'selectedLocation': instance.selectedLocation,
  'selectedShift': _$JsonConverterToJson<Map<String, dynamic>, ShiftData>(
    instance.selectedShift,
    const ShiftDataConverter().toJson,
  ),
  'expandedChecklists': instance.expandedChecklists,
  'dashboardFilters': instance.dashboardFilters,
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$operationalStateHash() => r'10bd842b9f75c1acfc5a8fd94c379810689eb8f8';

/// See also [OperationalState].
@ProviderFor(OperationalState)
final operationalStateProvider =
    NotifierProvider<OperationalState, OperationalStateData>.internal(
      OperationalState.new,
      name: r'operationalStateProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$operationalStateHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OperationalState = Notifier<OperationalStateData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
