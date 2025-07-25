import 'package:hands_app/utils/firestore_enforcer.dart';

class ShiftActions {
  /// Create a shift with Firestore Timestamp fields and correct field names
  static Future<void> createShift({
    required String orgId,
    required String shiftId,
    required Map<String, dynamic> shiftData, // Use Timestamp for startTime/endTime/startDate
  }) async {
    final shiftRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(orgId)
        .collection('shifts')
        .doc(shiftId);
    await shiftRef.set(shiftData);
  }

  /// Update a shift with new schema
  static Future<void> updateShift({
    required String orgId,
    required String shiftId,
    required Map<String, dynamic> updates, // Use Timestamp for startTime/endTime/startDate
  }) async {
    final shiftRef = FirestoreEnforcer.instance
        .collection('organizations')
        .doc(orgId)
        .collection('shifts')
        .doc(shiftId);
    await shiftRef.update(updates);
  }
}
