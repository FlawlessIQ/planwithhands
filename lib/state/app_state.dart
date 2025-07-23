import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/checklist_data.dart';
import 'package:hands_app/data/models/location_data.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/data/models/shift_data_converter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_state.freezed.dart';
part 'app_state.g.dart';

@Riverpod(keepAlive: true)
class AppState extends _$AppState {
  @override
  AppStateData build() {
    return AppStateData();
  }

  void setCurrentPageIndex(int newIndex) {
    state = state.copyWith(currentPageIndex: newIndex);
  }

  void setIsSettingsOpen(bool isSettingsOpen) {
    state = state.copyWith(isSettingsOpen: isSettingsOpen);
  }
}

@freezed
class AppStateData with _$AppStateData {
  factory AppStateData({
    @Default(0) int currentPageIndex,
    @Default(false) bool isSettingsOpen,
    LocationData? selectedLocation,
    @ShiftDataConverter() ShiftData? selectedShift,
    ChecklistData? selectedChecklist,
  }) = _AppStateData;

  factory AppStateData.fromJson(Map<String, dynamic> json) =>
      _$AppStateDataFromJson(json);
}
