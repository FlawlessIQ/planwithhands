import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

/// Migrates the users collection to the new schema.
Future<void> migrateUsersCollection() async {
  final users = await FirestoreEnforcer.instance.collection('users').get();
  for (final doc in users.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    // Migrate accessLevel → userRole
    if (data.containsKey('accessLevel')) {
      updates['userRole'] = data['accessLevel'];
      updates['accessLevel'] = FieldValue.delete();
    }

    // Migrate email/userEmail → emailAddress
    if (data.containsKey('userEmail') || data.containsKey('email')) {
      final email = data['userEmail'] ?? data['email'];
      updates['emailAddress'] = email;
      if (data.containsKey('userEmail')) {
        updates['userEmail'] = FieldValue.delete();
      }
      if (data.containsKey('email')) updates['email'] = FieldValue.delete();
    }

    // Migrate locationId → locationIds
    if (data.containsKey('locationId')) {
      updates['locationIds'] = [data['locationId']];
      updates['locationId'] = FieldValue.delete();
    }

    // Remove old roles array
    if (data.containsKey('roles')) {
      updates['roles'] = FieldValue.delete();
    }

    // Preserve createdAt or set if missing
    if (!data.containsKey('createdAt')) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }

    // Always set updatedAt
    updates['updatedAt'] = FieldValue.serverTimestamp();

    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
    }
  }
}

/// Migrates checklists by moving tasks array to a subcollection.
Future<void> migrateChecklistsToSubcollections(String orgId) async {
  final checklists =
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(orgId)
          .collection('checklists')
          .get();

  for (final checklistDoc in checklists.docs) {
    final data = checklistDoc.data();
    final tasks = data['tasks'] as List? ?? [];
    // Remove old tasks array
    await checklistDoc.reference.update({'tasks': FieldValue.delete()});

    // Fan out tasks into subcollection
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      await checklistDoc.reference.collection('tasks').add({
        'description': task is String ? task : (task['description'] ?? ''),
        'order': i,
      });
    }
  }
}

/// Migrates all checklists in all locations and shifts to use tasks subcollections (nested schema).
Future<void> migrateAllChecklistsToSubcollections(String orgId) async {
  final firestore = FirestoreEnforcer.instance;
  final locationsSnap =
      await firestore
          .collection('organizations')
          .doc(orgId)
          .collection('locations')
          .get();
  for (final locationDoc in locationsSnap.docs) {
    final shiftsSnap = await locationDoc.reference.collection('shifts').get();
    for (final shiftDoc in shiftsSnap.docs) {
      final checklistsSnap =
          await shiftDoc.reference.collection('checklists').get();
      for (final checklistDoc in checklistsSnap.docs) {
        final data = checklistDoc.data();
        final tasks = data['tasks'] as List? ?? [];
        // Remove old tasks array
        if (tasks.isNotEmpty) {
          await checklistDoc.reference.update({'tasks': FieldValue.delete()});
          // Fan out tasks into subcollection
          for (final task in tasks) {
            final taskId =
                task['taskId'] ?? firestore.collection('dummy').doc().id;
            await checklistDoc.reference
                .collection('tasks')
                .doc(taskId)
                .set(task);
          }
        }
      }
    }
  }
}

/// Migrates shifts to use Timestamp fields and new field names.
Future<void> migrateShiftsToTimestamps(String orgId) async {
  final shifts =
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(orgId)
          .collection('shifts')
          .get();

  for (final shiftDoc in shifts.docs) {
    final data = shiftDoc.data();
    final updates = <String, dynamic>{};

    // Convert startTime/endTime from string to Timestamp
    if (data['startTime'] is String) {
      updates['startTime'] = Timestamp.fromDate(
        DateTime.parse(data['startTime']),
      );
    }
    if (data['endTime'] is String) {
      updates['endTime'] = Timestamp.fromDate(DateTime.parse(data['endTime']));
    }

    // Remove hour/minute fields
    updates['startTimeHour'] = FieldValue.delete();
    updates['startTimeMinute'] = FieldValue.delete();
    updates['endTimeHour'] = FieldValue.delete();
    updates['endTimeMinute'] = FieldValue.delete();

    // Rename shiftDate -> startDate as Timestamp
    if (data['shiftDate'] is String) {
      updates['startDate'] = Timestamp.fromDate(
        DateTime.parse(data['shiftDate']),
      );
      updates['shiftDate'] = FieldValue.delete();
    }

    if (updates.isNotEmpty) {
      await shiftDoc.reference.update(updates);
    }
  }
}

/// Migrates notifications to use targets map and readBy array.
Future<void> migrateNotifications(String orgId) async {
  final notifs =
      await FirestoreEnforcer.instance
          .collection('organizations')
          .doc(orgId)
          .collection('notifications')
          .get();

  for (final notifDoc in notifs.docs) {
    final data = notifDoc.data();
    final updates = <String, dynamic>{};

    // Replace recipientId: "all" with targets map
    if (data['recipientId'] == 'all') {
      updates['targets'] = {
        'roles': ['all'],
        'locationIds': [],
        'userIds': [],
      };
      updates['recipientId'] = FieldValue.delete();
    }

    // Move read boolean to readBy array
    if (data.containsKey('read')) {
      if (data['read'] == true) {
        updates['readBy'] = [];
      }
      updates['read'] = FieldValue.delete();
    }

    if (updates.isNotEmpty) {
      await notifDoc.reference.update(updates);
    }
  }
}

/// Adds timestamps and orgId to all docs in a collection.
Future<void> addTimestampsAndOrgIdToCollection(String collection) async {
  final docs = await FirestoreEnforcer.instance.collection(collection).get();
  for (final doc in docs.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    if (!data.containsKey('createdAt')) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }
    updates['updatedAt'] = FieldValue.serverTimestamp();
    if (!data.containsKey('organizationId')) {
      updates['organizationId'] = 'UNKNOWN_ORG';
    }

    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
    }
  }
}

/// Example entry point for running all migrations (call from admin context)
Future<void> runAllMigrations(String orgId) async {
  await migrateUsersCollection();
  await migrateAllChecklistsToSubcollections(orgId);
  await migrateShiftsToTimestamps(orgId);
  await migrateNotifications(orgId);
  await addTimestampsAndOrgIdToCollection('training_materials');
  await addTimestampsAndOrgIdToCollection('locations');
  await addTimestampsAndOrgIdToCollection('organizations');
}
