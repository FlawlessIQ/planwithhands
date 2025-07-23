import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hands_app/data/models/location_data.dart';
import 'package:hands_app/data/models/organization_data.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/data/models/shift_data_converter.dart';

part 'operational_state.freezed.dart';
part 'operational_state.g.dart';

@Riverpod(keepAlive: true)
class OperationalState extends _$OperationalState {
  @override
  OperationalStateData build() {
    return OperationalStateData();
  }

  // Organization State Logic

  void setOrganizationDataToState(OrganizationData organizationData) {
    state = state.copyWith(organizationData: organizationData);
  }

  void addLocationToOrganization(LocationData locationData) {
    if (state.organizationData == null) return;

    List<LocationData> updatedLocations = [
      ...state.organizationData!.locations,
      locationData,
    ];

    state = state.copyWith(
      organizationData: state.organizationData!.copyWith(
        locations: updatedLocations,
      ),
    );
  }

  // Location State Logic

  void selectLocation(LocationData location) {
    state = state.copyWith(selectedLocation: location);
  }

  void clearSelectedLocation() {
    state = state.copyWith(selectedLocation: null);
  }

  void addShiftToLocation(String locationId, ShiftData shift) {
    if (state.organizationData == null) return;

    var updatedLocations = state.organizationData!.locations.map((location) {
      if (location.locationId == locationId) {
        return location.copyWith(shifts: [...location.shifts, shift]);
      }
      return location;
    }).toList();

    state = state.copyWith(
      organizationData: state.organizationData!.copyWith(
        locations: updatedLocations,
      ),
    );
  }

  // Shift State Logic

  void selectShift(ShiftData shift) {
    state = state.copyWith(selectedShift: shift);
  }

  void clearSelectedShift() {
    state = state.copyWith(selectedShift: null);
  }

  void editShiftData(String locationId, ShiftData updatedShift) {
    if (state.organizationData == null) return;

    var locations = [...state.organizationData!.locations];

    int locationIndex =
        locations.indexWhere((location) => location.locationId == locationId);

    if (locationIndex != -1) {
      var mutableShifts = [...locations[locationIndex].shifts];
      int shiftIndex =
          mutableShifts.indexWhere((shift) => shift.shiftId == updatedShift.shiftId);

      if (shiftIndex != -1) {
        mutableShifts[shiftIndex] = updatedShift;

        var updatedLocation =
            locations[locationIndex].copyWith(shifts: mutableShifts);

        locations[locationIndex] = updatedLocation;

        state = state.copyWith(
          organizationData:
              state.organizationData!.copyWith(locations: locations),
        );
      }
    }
  }

  void deleteShift(String locationId, ShiftData shiftToDelete) {
    if (state.organizationData == null) return;

    var locations = [...state.organizationData!.locations];

    int locationIndex =
        locations.indexWhere((location) => location.locationId == locationId);

    if (locationIndex != -1) {
      var mutableShifts = [...locations[locationIndex].shifts];
      mutableShifts.removeWhere((shift) => shift.shiftId == shiftToDelete.shiftId);

      var updatedLocation =
          locations[locationIndex].copyWith(shifts: mutableShifts);

      locations[locationIndex] = updatedLocation;

      state = state.copyWith(
        organizationData:
            state.organizationData!.copyWith(locations: locations),
      );
    }
  }

  // Manager Dashboard State Logic

  void toggleDashboardFilter(String filterId) {
    final newFilters = [...state.dashboardFilters];
    if (newFilters.contains(filterId)) {
      newFilters.remove(filterId);
    } else {
      newFilters.add(filterId);
    }
    state = state.copyWith(dashboardFilters: newFilters);
  }

  void clearDashboardFilters() {
    state = state.copyWith(dashboardFilters: []);
  }
}

@freezed
class OperationalStateData with _$OperationalStateData {
  factory OperationalStateData({
    OrganizationData? organizationData,
    LocationData? selectedLocation,
    @ShiftDataConverter() ShiftData? selectedShift,
    @Default([]) List<String> expandedChecklists,
    @Default(['completed', 'incomplete']) List<String> dashboardFilters,
  }) = _OperationalStateData;

  factory OperationalStateData.fromJson(Map<String, dynamic> json) =>
      _$OperationalStateDataFromJson(json);
}
