import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExtendedUserData {
  final String userId;
  final String firstName;
  final String lastName;
  final String emailAddress;
  final int userRole; // 0=General, 1=Manager, 2=Admin
  final String organizationId;
  final String? locationId; // For general users
  final List<String>? locationIds; // For managers
  final List<String> jobTypes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Scheduling fields
  final Map<String, bool> availability; // dayShiftKey → available
  final Map<String, TimeOfDay> earliestStart; // weekday → earliest TimeOfDay
  final Map<String, dynamic> notificationSettings;

  ExtendedUserData({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.emailAddress,
    required this.userRole,
    required this.organizationId,
    this.locationId,
    this.locationIds,
    required this.jobTypes,
    required this.createdAt,
    this.updatedAt,
    required this.availability,
    required this.earliestStart,
    required this.notificationSettings,
  });

  factory ExtendedUserData.fromMap(Map<String, dynamic> map, String id) {
    return ExtendedUserData(
      userId: id,
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      emailAddress: map['emailAddress'] ?? map['userEmail'] ?? '',
      userRole: map['userRole'] ?? 0,
      organizationId: map['organizationId'] ?? '',
      locationId: map['locationId'],
      locationIds:
          map['locationIds'] != null
              ? List<String>.from(map['locationIds'])
              : null,
      jobTypes:
          map['jobTypes'] != null
              ? List<String>.from(map['jobTypes'])
              : (map['jobType'] != null
                  ? List<String>.from(map['jobType'])
                  : []),
      createdAt:
          map['createdAt'] != null
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      updatedAt:
          map['updatedAt'] != null
              ? (map['updatedAt'] as Timestamp).toDate()
              : null,
      availability: Map<String, bool>.from(map['availability'] ?? {}),
      earliestStart: _parseEarliestStart(map['earliestStart'] ?? {}),
      notificationSettings: Map<String, dynamic>.from(
        map['notificationSettings'] ??
            {
              'scheduleUpdates': true,
              'shiftReminders': true,
              'emailNotifications': true,
              'pushNotifications': true,
            },
      ),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'emailAddress': emailAddress,
      'userRole': userRole,
      'organizationId': organizationId,
      'jobType': jobTypes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'availability': availability,
      'earliestStart': _serializeEarliestStart(earliestStart),
      'notificationSettings': notificationSettings,
    };

    if (userRole == 1 && locationIds != null) {
      map['locationIds'] = locationIds;
    } else if (userRole == 0 && locationId != null) {
      map['locationId'] = locationId;
    }

    return map;
  }

  static Map<String, TimeOfDay> _parseEarliestStart(Map<String, dynamic> map) {
    final result = <String, TimeOfDay>{};
    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final hour = value['hour'] as int? ?? 9;
        final minute = value['minute'] as int? ?? 0;
        result[key] = TimeOfDay(hour: hour, minute: minute);
      }
    });
    return result;
  }

  static Map<String, dynamic> _serializeEarliestStart(
    Map<String, TimeOfDay> map,
  ) {
    final result = <String, dynamic>{};
    map.forEach((key, timeOfDay) {
      result[key] = {'hour': timeOfDay.hour, 'minute': timeOfDay.minute};
    });
    return result;
  }

  ExtendedUserData copyWith({
    String? userId,
    String? firstName,
    String? lastName,
    String? emailAddress,
    int? userRole,
    String? organizationId,
    String? locationId,
    List<String>? locationIds,
    List<String>? jobTypes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, bool>? availability,
    Map<String, TimeOfDay>? earliestStart,
    Map<String, dynamic>? notificationSettings,
  }) {
    return ExtendedUserData(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      emailAddress: emailAddress ?? this.emailAddress,
      userRole: userRole ?? this.userRole,
      organizationId: organizationId ?? this.organizationId,
      locationId: locationId ?? this.locationId,
      locationIds: locationIds ?? this.locationIds,
      jobTypes: jobTypes ?? this.jobTypes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      availability: availability ?? this.availability,
      earliestStart: earliestStart ?? this.earliestStart,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  String get roleText {
    switch (userRole) {
      case 2:
        return 'Admin';
      case 1:
        return 'Manager';
      default:
        return 'General User';
    }
  }

  bool get isAvailableForShift =>
      availability.values.any((available) => available);

  @override
  String toString() {
    return 'ExtendedUserData(userId: $userId, name: $fullName, role: $roleText)';
  }
}
