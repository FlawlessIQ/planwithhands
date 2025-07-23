import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleEntryData {
  final String id;
  final String dayShiftKey;            // e.g. "Tuesday_Dinner"
  final Map<String, int> requiredRoles; // roleId → target count
  final List<String> assignedUserIds;
  final String scheduleId;
  final String shiftId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScheduleEntryData({
    required this.id,
    required this.dayShiftKey,
    required this.requiredRoles,
    required this.assignedUserIds,
    required this.scheduleId,
    required this.shiftId,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduleEntryData.fromMap(Map<String, dynamic> map, String id) {
    return ScheduleEntryData(
      id: id,
      dayShiftKey: (map['dayShiftKey'] ?? '').trim(),
      requiredRoles: Map<String, int>.from(map['requiredRoles'] ?? {}),
      assignedUserIds: List<String>.from(map['assignedUserIds'] ?? []),
      scheduleId: map['scheduleId'] ?? '',
      shiftId: map['shiftId'] ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayShiftKey': dayShiftKey.trim(),
      'requiredRoles': requiredRoles,
      'assignedUserIds': assignedUserIds,
      'scheduleId': scheduleId,
      'shiftId': shiftId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ScheduleEntryData copyWith({
    String? id,
    String? dayShiftKey,
    Map<String, int>? requiredRoles,
    List<String>? assignedUserIds,
    String? scheduleId,
    String? shiftId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleEntryData(
      id: id ?? this.id,
      dayShiftKey: dayShiftKey ?? this.dayShiftKey,
      requiredRoles: requiredRoles ?? Map<String, int>.from(this.requiredRoles),
      assignedUserIds: assignedUserIds ?? List<String>.from(this.assignedUserIds),
      scheduleId: scheduleId ?? this.scheduleId,
      shiftId: shiftId ?? this.shiftId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  int get totalAssigned => assignedUserIds.length;
  
  int get totalRequired => requiredRoles.values.fold(0, (sum, count) => sum + count);
  
  bool get isFullyStaffed => totalAssigned >= totalRequired;
  
  bool get isOverStaffed => totalAssigned > totalRequired;

  int getRequiredCountForRole(String roleId) => requiredRoles[roleId] ?? 0;
  
  int getAssignedCountForRole(String roleId, Map<String, List<String>> userRoleMap) {
    return assignedUserIds.where((userId) {
      final userRoles = userRoleMap[userId] ?? [];
      return userRoles.contains(roleId);
    }).length;
  }

  @override
  String toString() {
    return 'ScheduleEntryData(id: $id, dayShiftKey: $dayShiftKey, totalAssigned: $totalAssigned, totalRequired: $totalRequired)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ScheduleEntryData &&
      other.id == id &&
      other.dayShiftKey == dayShiftKey &&
      other.scheduleId == scheduleId &&
      other.shiftId == shiftId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      dayShiftKey.hashCode ^
      scheduleId.hashCode ^
      shiftId.hashCode;
  }
}
