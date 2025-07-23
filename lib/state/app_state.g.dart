// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppStateDataImpl _$$AppStateDataImplFromJson(Map<String, dynamic> json) =>
    _$AppStateDataImpl(
      currentPageIndex: (json['currentPageIndex'] as num?)?.toInt() ?? 0,
      isSettingsOpen: json['isSettingsOpen'] as bool? ?? false,
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
      selectedChecklist:
          json['selectedChecklist'] == null
              ? null
              : ChecklistData.fromJson(
                json['selectedChecklist'] as Map<String, dynamic>,
              ),
    );

Map<String, dynamic> _$$AppStateDataImplToJson(_$AppStateDataImpl instance) =>
    <String, dynamic>{
      'currentPageIndex': instance.currentPageIndex,
      'isSettingsOpen': instance.isSettingsOpen,
      'selectedLocation': instance.selectedLocation,
      'selectedShift': _$JsonConverterToJson<Map<String, dynamic>, ShiftData>(
        instance.selectedShift,
        const ShiftDataConverter().toJson,
      ),
      'selectedChecklist': instance.selectedChecklist,
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

String _$appStateHash() => r'5794f407dc120f4339dcb09ebe808bacfba631cb';

/// See also [AppState].
@ProviderFor(AppState)
final appStateProvider = NotifierProvider<AppState, AppStateData>.internal(
  AppState.new,
  name: r'appStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppState = Notifier<AppStateData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
