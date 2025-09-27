import 'package:hands_app/utils/firestore_enforcer.dart';
import 'package:hands_app/services/daily_summary_service.dart';

/// Comprehensive diagnostic tool for daily summary content analysis
/// This will show exactly what data is being collected and why summaries might be lacking content
void main() async {
  print('🔍 Daily Summary Content Diagnostic Tool');
  print('=========================================');

  try {
    // Configuration - replace with your actual organization ID
    const testOrgId = 'vnE0olvi1Tswjtdb19MI'; // Replace with actual org ID
    
    final firestore = FirestoreEnforcer.instance;
    final service = DailySummaryService();

    print('\n📅 Analyzing yesterday\'s data...');
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    
    print('Target Date: $dateStr');
    print('Organization ID: $testOrgId');

    // Step 1: Check what locations exist
    print('\n🏢 Step 1: Checking organization locations...');
    final locationsQuery = await firestore
        .collection('organizations')
        .doc(testOrgId)
        .collection('locations')
        .get();

    print('Found ${locationsQuery.docs.length} locations:');
    for (final locationDoc in locationsQuery.docs) {
      final locationData = locationDoc.data();
      final locationName = locationData['locationName'] ?? 'Unknown';
      print('  • ${locationDoc.id}: $locationName');
    }

    // Step 2: Check for daily checklists
    print('\n📋 Step 2: Checking daily checklists for $dateStr...');
    
    int totalChecklists = 0;
    int totalTasks = 0;
    int totalCompleted = 0;
    int totalNotes = 0;
    int totalMissedWithReasons = 0;
    int totalPhotoBypassed = 0;

    for (final locationDoc in locationsQuery.docs) {
      final locationId = locationDoc.id;
      final locationName = locationDoc.data()['locationName'] ?? 'Unknown';

      print('\n  📍 Location: $locationName ($locationId)');

      // Check both possible paths for daily checklists
      final checklistPaths = [
        // New structure: organizations/{orgId}/locations/{locationId}/daily_checklists
        firestore
            .collection('organizations')
            .doc(testOrgId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .where('date', isEqualTo: dateStr),
        
        // Legacy structure: organizations/{orgId}/dailyChecklists  
        firestore
            .collection('organizations')
            .doc(testOrgId)
            .collection('dailyChecklists')
            .where('date', isEqualTo: dateStr)
            .where('locationId', isEqualTo: locationId),
      ];

      for (int pathIndex = 0; pathIndex < checklistPaths.length; pathIndex++) {
        final query = checklistPaths[pathIndex];
        final results = await query.get();
        
        if (results.docs.isNotEmpty) {
          print('    📁 Found ${results.docs.length} checklists in ${pathIndex == 0 ? 'NEW' : 'LEGACY'} structure');
          totalChecklists += results.docs.length;

          for (final checklistDoc in results.docs) {
            final checklistData = checklistDoc.data();
            final shiftId = checklistData['shiftId'] ?? 'unknown';
            final templateName = checklistData['templateName'] ?? 'Unknown Checklist';

            print('      📝 Checklist: $templateName (Shift: $shiftId)');

            // Analyze tasks from subcollection (new system)
            final subcollectionTasks = await checklistDoc.reference.collection('tasks').get();
            if (subcollectionTasks.docs.isNotEmpty) {
              print('        📂 Found ${subcollectionTasks.docs.length} tasks in subcollection');
              
              for (final taskDoc in subcollectionTasks.docs) {
                final taskData = taskDoc.data();
                await _analyzeTask(taskData, '        ');
                totalTasks++;
                if (taskData['completed'] == true) totalCompleted++;
                if (taskData['notes']?.toString().trim().isNotEmpty == true) totalNotes++;
                if (taskData['completed'] != true && taskData['reason']?.toString().trim().isNotEmpty == true) {
                  totalMissedWithReasons++;
                }
                if (taskData['completed'] == true && 
                    taskData['photoRequired'] == true && 
                    (taskData['proofImageUrl']?.toString().isEmpty ?? true)) {
                  totalPhotoBypassed++;
                }
              }
            }

            // Analyze tasks from legacy array
            final legacyTasks = List<Map<String, dynamic>>.from(checklistData['tasks'] ?? []);
            if (legacyTasks.isNotEmpty) {
              print('        📋 Found ${legacyTasks.length} tasks in legacy array');
              
              for (final taskData in legacyTasks) {
                await _analyzeTask(taskData, '        ');
                totalTasks++;
                if (taskData['completed'] == true || taskData['isCompleted'] == true) totalCompleted++;
                if (taskData['notes']?.toString().trim().isNotEmpty == true) totalNotes++;
                if ((taskData['completed'] != true && taskData['isCompleted'] != true) && 
                    (taskData['reason']?.toString().trim().isNotEmpty == true || 
                     taskData['notCompletedReason']?.toString().trim().isNotEmpty == true)) {
                  totalMissedWithReasons++;
                }
                if ((taskData['completed'] == true || taskData['isCompleted'] == true) && 
                    taskData['photoRequired'] == true && 
                    (taskData['proofImageUrl']?.toString().isEmpty ?? true)) {
                  totalPhotoBypassed++;
                }
              }
            }

            if (subcollectionTasks.docs.isEmpty && legacyTasks.isEmpty) {
              print('        ⚠️  No tasks found in either subcollection or legacy array');
            }
          }
        } else if (pathIndex == 1) {
          print('    ❌ No checklists found in either structure');
        }
      }
    }

    // Step 3: Generate sample summary to see actual output
    print('\n🧪 Step 3: Testing actual summary generation...');
    try {
      await service.generateAndSendDailySummary(organizationId: testOrgId, targetDate: yesterday);
      print('✅ Summary generation completed - check your notifications!');
    } catch (e) {
      print('❌ Error generating summary: $e');
    }

    // Step 4: Summary and recommendations
    print('\n📊 ANALYSIS SUMMARY');
    print('==================');
    print('Manual count:');
    print('  📋 Total Checklists: $totalChecklists');
    print('  📝 Total Tasks: $totalTasks');
    print('  ✅ Completed Tasks: $totalCompleted');
    print('  📝 Tasks with Notes: $totalNotes');
    print('  ❌ Missed with Reasons: $totalMissedWithReasons');
    print('  📷 Photo Bypassed: $totalPhotoBypassed');

    if (totalTasks == 0) {
      print('\n🚨 ISSUE FOUND: No tasks detected!');
      print('Possible causes:');
      print('  • Wrong organization ID');
      print('  • Wrong date format or date');
      print('  • Tasks stored in different collection structure');
      print('  • No checklists were created for this date');
    } else if (totalNotes == 0 && totalMissedWithReasons == 0 && totalPhotoBypassed == 0) {
      print('\n⚠️  LIMITED CONTENT: Tasks found but no interesting events');
      print('Summary would show:');
      print('  • Overall completion percentage');
      print('  • Basic task counts');
      print('  • Generic encouragement message');
      print('\nTo get more insights:');
      print('  • Staff should add notes to tasks');
      print('  • Incomplete tasks should include reasons');
      print('  • Photo requirements should be enforced');
    } else {
      print('\n✅ GOOD DATA: Rich content available for summary');
      print('Summary should include:');
      if (totalNotes > 0) print('  • Task notes and observations');
      if (totalMissedWithReasons > 0) print('  • Missed tasks with explanations');
      if (totalPhotoBypassed > 0) print('  • Photo compliance issues');
    }

  } catch (e, stackTrace) {
    print('❌ Error during analysis: $e');
    print('Stack trace: $stackTrace');
    print('\n💡 Troubleshooting:');
    print('  • Ensure Firebase is initialized');
    print('  • Update testOrgId with your actual organization ID');
    print('  • Check Firebase project connection');
    print('  • Verify Firestore rules allow read access');
  }
}

/// Helper function to analyze individual task data
Future<void> _analyzeTask(Map<String, dynamic> taskData, String indent) async {
  final taskName = taskData['taskName'] ?? 
                   taskData['description'] ?? 
                   taskData['title'] ?? 
                   taskData['name'] ?? 
                   'Unknown Task';
  
  final isCompleted = taskData['completed'] == true || taskData['isCompleted'] == true;
  final hasNotes = taskData['notes']?.toString().trim().isNotEmpty == true;
  final hasReason = (taskData['reason']?.toString().trim().isNotEmpty == true) || 
                    (taskData['notCompletedReason']?.toString().trim().isNotEmpty == true);
  final photoRequired = taskData['photoRequired'] == true;
  final hasPhoto = (taskData['proofImageUrl']?.toString().isNotEmpty == true) ||
                   (taskData['photoUrl']?.toString().isNotEmpty == true);

  final status = isCompleted ? '✅' : '❌';
  final extras = <String>[];
  
  if (hasNotes) extras.add('📝 notes');
  if (!isCompleted && hasReason) extras.add('❌ reason');
  if (isCompleted && photoRequired && !hasPhoto) extras.add('📷 photo missing');
  if (photoRequired) extras.add('📸 photo req');
  
  final extrasStr = extras.isNotEmpty ? ' (${extras.join(', ')})' : '';
  
  print('$indent$status $taskName$extrasStr');
  
  if (hasNotes) {
    print('$indent   📝 Note: "${taskData['notes']}"');
  }
  if (hasReason) {
    final reason = taskData['reason'] ?? taskData['notCompletedReason'];
    print('$indent   ❌ Reason: "$reason"');
  }
}