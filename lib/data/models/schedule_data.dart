import 'package:cloud_firestore/cloud_firestore.dart';

ScheduleData fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return ScheduleData(
    id: doc.id,
    startDate: (data['startDate'] as Timestamp).toDate(),
    endDate: (data['endDate'] as Timestamp).toDate(),
    published: data['published'] ?? false,
    organizationId: data['organizationId'] ?? '',
    locationId: data['locationId'] ?? '',
    createdAt:
        data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : null,
    updatedAt:
        data['updatedAt'] != null
            ? (data['updatedAt'] as Timestamp).toDate()
            : null,
  );
}

class ScheduleData {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final bool published;
  final String organizationId;
  final String locationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScheduleData({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.published,
    required this.organizationId,
    required this.locationId,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduleData.fromMap(Map<String, dynamic> map, String id) {
    return ScheduleData(
      id: id,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      published: map['published'] ?? false,
      organizationId: map['organizationId'] ?? '',
      locationId: map['locationId'] ?? '',
      createdAt:
          map['createdAt'] != null
              ? (map['createdAt'] as Timestamp).toDate()
              : null,
      updatedAt:
          map['updatedAt'] != null
              ? (map['updatedAt'] as Timestamp).toDate()
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'published': published,
      'organizationId': organizationId,
      'locationId': locationId,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ScheduleData copyWith({
    String? id,
    DateTime? startDate,
    DateTime? endDate,
    bool? published,
    String? organizationId,
    String? locationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleData(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      published: published ?? this.published,
      organizationId: organizationId ?? this.organizationId,
      locationId: locationId ?? this.locationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ScheduleData(id: $id, startDate: $startDate, endDate: $endDate, published: $published)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ScheduleData &&
        other.id == id &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.published == published &&
        other.organizationId == organizationId &&
        other.locationId == locationId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        published.hashCode ^
        organizationId.hashCode ^
        locationId.hashCode;
  }
}
