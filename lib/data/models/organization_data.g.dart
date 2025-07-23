// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrganizationDataImpl _$$OrganizationDataImplFromJson(
  Map<String, dynamic> json,
) => _$OrganizationDataImpl(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  address: json['address'] as String? ?? '',
  phone: json['phone'] as String? ?? '',
  subscriptionStatus: json['subscriptionStatus'] as String? ?? 'pending',
  employeeCount: (json['employeeCount'] as num?)?.toInt() ?? 0,
  stripeCustomerId: json['stripeCustomerId'] as String?,
  stripeSubscriptionId: json['stripeSubscriptionId'] as String?,
  createdAt: const TimestampConverter().fromJson(json['createdAt']),
  locations:
      (json['locations'] as List<dynamic>?)
          ?.map((e) => LocationData.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$$OrganizationDataImplToJson(
  _$OrganizationDataImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'address': instance.address,
  'phone': instance.phone,
  'subscriptionStatus': instance.subscriptionStatus,
  'employeeCount': instance.employeeCount,
  'stripeCustomerId': instance.stripeCustomerId,
  'stripeSubscriptionId': instance.stripeSubscriptionId,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'locations': instance.locations,
};
