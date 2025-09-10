import 'package:cloud_firestore/cloud_firestore.dart';

/// Script to fix existing daily checklists by adding job types from their templates
/// Run this to retroactively add job type filtering to existing checklists
Future<void> fixExistingChecklists() async {
  final firestore = FirebaseFirestore.instance;

  print('🔧 Starting to fix existing checklists without job types...');

  try {
    // Get all organizations
    final orgsSnapshot = await firestore.collection('organizations').get();

    for (final orgDoc in orgsSnapshot.docs) {
      final orgId = orgDoc.id;
      print('📋 Processing organization: $orgId');

      // Get all locations for this org
      final locationsSnapshot = await firestore.collection('organizations').doc(orgId).collection('locations').get();

      for (final locationDoc in locationsSnapshot.docs) {
        final locationId = locationDoc.id;
        print('  📍 Processing location: $locationId');

        // Get all daily checklists for this location
        final checklistsSnapshot =
            await firestore
                .collection('organizations')
                .doc(orgId)
                .collection('locations')
                .doc(locationId)
                .collection('daily_checklists')
                .get();

        final batch = firestore.batch();
        int updateCount = 0;

        for (final checklistDoc in checklistsSnapshot.docs) {
          final checklistData = checklistDoc.data();
          final templateId = checklistData['checklistTemplateId'] as String?;

          // Skip if no template ID or already has job types
          if (templateId == null || checklistData.containsKey('jobTypes')) {
            continue;
          }

          try {
            // Get the template to fetch job types
            final templateDoc =
                await firestore
                    .collection('organizations')
                    .doc(orgId)
                    .collection('checklist_templates')
                    .doc(templateId)
                    .get();

            if (templateDoc.exists) {
              final templateData = templateDoc.data()!;
              final jobTypes = templateData['jobTypes'] ?? templateData['jobType'];

              if (jobTypes != null) {
                // Update the checklist with job types from template
                batch.update(checklistDoc.reference, {'jobTypes': jobTypes, 'updatedAt': FieldValue.serverTimestamp()});
                updateCount++;
                print('    ✅ Queued update for checklist ${checklistDoc.id} with jobTypes: $jobTypes');
              }
            }
          } catch (e) {
            print('    ❌ Error processing checklist ${checklistDoc.id}: $e');
          }
        }

        // Commit the batch for this location
        if (updateCount > 0) {
          await batch.commit();
          print('  ✅ Updated $updateCount checklists in location $locationId');
        } else {
          print('  ℹ️ No checklists needed updating in location $locationId');
        }
      }
    }

    print('🎉 Finished fixing existing checklists!');
  } catch (e) {
    print('❌ Error fixing checklists: $e');
  }
}

void main() async {
  await fixExistingChecklists();
}
