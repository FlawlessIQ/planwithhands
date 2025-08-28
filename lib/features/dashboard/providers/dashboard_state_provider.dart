import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/models/daily_checklist.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_state_provider.freezed.dart';

@freezed
class DashboardState with _$DashboardState {
  const factory DashboardState({
    @Default(true) bool isLoading,
    String? errorMessage,
    @Default([]) List<ShiftData> assignedShifts,
    @Default([]) List<List<DailyChecklist>> allChecklists,
    @Default(false) bool hasLoadedOnce,
    String? lastLoadedDate,
  }) = _DashboardState;
}

// This will be expanded with the logic from the user_dashboard_page.dart
class DashboardController extends StateNotifier<DashboardState> {
  DashboardController() : super(const DashboardState());

  // Methods to load/refresh data will be moved here.
  void setAssignedShifts(List<ShiftData> shifts, {String? forDate}) {
    state = state.copyWith(
      assignedShifts: List<ShiftData>.unmodifiable(shifts),
      lastLoadedDate: forDate ?? state.lastLoadedDate,
      isLoading: false,
      hasLoadedOnce: true,
      errorMessage: null,
    );
  }

  void clearForNewDay(String newDate) {
    state = state.copyWith(assignedShifts: const [], lastLoadedDate: newDate, allChecklists: const []);
  }

  void addShiftIfAbsent(ShiftData shift, {String? forDate}) {
    final exists = state.assignedShifts.any((s) => s.shiftId == shift.shiftId);
    if (exists) return;
    final updated = [shift, ...state.assignedShifts];
    setAssignedShifts(updated, forDate: forDate);
  }

  void replaceShiftsPreservingOrder(List<ShiftData> newShifts, {String? forDate}) {
    // Use incoming order; ensure uniqueness by shiftId
    final seen = <String>{};
    final deduped = <ShiftData>[];
    for (final s in newShifts) {
      if (seen.add(s.shiftId)) deduped.add(s);
    }
    setAssignedShifts(deduped, forDate: forDate);
  }
}

final dashboardControllerProvider = StateNotifierProvider<DashboardController, DashboardState>((ref) {
  return DashboardController();
});
