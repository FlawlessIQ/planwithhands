import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hands_app/data/models/user_data.dart';

part 'user_state.freezed.dart';
part 'user_state.g.dart';

@riverpod
class UserState extends _$UserState {
  @override
  UserStateData build() {
    return UserStateData();
  }

  void setUserData(UserData userData) {
    state = state.copyWith(userData: userData);
  }

  void addLocationIdToUser(String locationId) {
    if (state.userData == null) return;

    List<String> updatedLocationIds = [
      ...state.userData!.locationIds,
      locationId,
    ];

    state = state.copyWith(
      userData: state.userData!.copyWith(locationIds: updatedLocationIds),
    );
  }
}

@freezed
class UserStateData with _$UserStateData {
  factory UserStateData({UserData? userData}) = _UserStateData;

  factory UserStateData.fromJson(Map<String, dynamic> json) =>
      _$UserStateDataFromJson(json);
}
