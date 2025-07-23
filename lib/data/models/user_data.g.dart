// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserDataImpl _$$UserDataImplFromJson(Map<String, dynamic> json) =>
    _$UserDataImpl(
      userId: json['userId'] as String,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      userEmail: json['emailAddress'] as String,
      userRole: (json['userRole'] as num).toInt(),
      organizationId: json['organizationId'] as String,
      locationIds:
          (json['locationIds'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      jobTypes:
          (json['jobTypes'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$UserDataImplToJson(_$UserDataImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'createdAt': const TimestampConverter().toJson(instance.createdAt),
      'emailAddress': instance.userEmail,
      'userRole': instance.userRole,
      'organizationId': instance.organizationId,
      'locationIds': instance.locationIds,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'phoneNumber': instance.phoneNumber,
      'jobTypes': instance.jobTypes,
    };
