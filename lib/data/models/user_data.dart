// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/constants/firestore_names.dart';
import 'package:hands_app/data/models/timestamp_converter.dart';

part 'user_data.freezed.dart';
part 'user_data.g.dart';

enum UserRole { staff, manager, admin }

@freezed
class UserData with _$UserData {
  factory UserData({
    @JsonKey(name: UserFieldNames.userId) required String userId,
    @JsonKey(name: UserFieldNames.createdAt)
    @TimestampConverter()
    required DateTime createdAt,
    @JsonKey(name: UserFieldNames.emailAddress) required String userEmail,
    @JsonKey(name: UserFieldNames.userRole) required int userRole, // Changed from accessLevel
    @JsonKey(name: UserFieldNames.organizationId) required String organizationId,
    @JsonKey(name: UserFieldNames.locationIds)
    required List<String> locationIds,
    @JsonKey(name: UserFieldNames.firstName) required String firstName,
    @JsonKey(name: UserFieldNames.lastName) required String lastName,
    @JsonKey(name: UserFieldNames.phoneNumber) required String phoneNumber,
    @JsonKey(name: 'jobTypes') required List<String> jobTypes, // Changed from jobType to jobTypes
  }) = _UserData;

  factory UserData.fromJson(Map<String, Object?> json) =>
      _$UserDataFromJson(json);
}
