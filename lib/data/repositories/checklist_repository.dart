import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/data/models/checklist_data.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class ChecklistRepository {
  final FirebaseFirestore _firestore = FirestoreEnforcer.instance;

  Stream<List<ChecklistData>> fetchChecklists(
    String organizationId,
    String locationId,
    String shiftId,
    List<String> roles,
  ) {
    return _firestore
        .collection(
          'organizations/$organizationId/locations/$locationId/shifts/$shiftId/checklists',
        )
        .where('roles', arrayContainsAny: roles)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChecklistData.fromJson(doc.data()))
                  .toList(),
        );
  }
}
