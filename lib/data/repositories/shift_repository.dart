import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class ShiftRepository {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  Stream<List<ShiftData>> fetchShifts(
    String organizationId,
    String locationId,
    List<String> jobTypes,
  ) {
    return _firestore
        .collection(
          'organizations/$organizationId/locations/$locationId/shifts',
        )
        .where('jobTypes', arrayContainsAny: jobTypes)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ShiftData.fromJson(doc.data()))
                  .toList(),
        );
  }
}
