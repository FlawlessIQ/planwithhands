import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/location_data.dart';
import 'package:hands_app/data/models/timestamp_converter.dart';

part 'organization_data.freezed.dart';
part 'organization_data.g.dart';

@freezed
class OrganizationData with _$OrganizationData {
  const factory OrganizationData({
    @Default('') String id,
    @Default('') String name,
    @Default('') String address,
    @Default('') String phone,
    @Default('pending') String subscriptionStatus,
    @Default(0) int employeeCount,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    @TimestampConverter() required DateTime createdAt,
    @Default([]) List<LocationData> locations,
  }) = _OrganizationData;

  factory OrganizationData.fromJson(Map<String, dynamic> json) =>
      _$OrganizationDataFromJson(json);
}
