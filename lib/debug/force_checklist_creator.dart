import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hands_app/models/daily_checklist.dart';

class ForceChecklistCreator {
  /// Force creates emergency checklists when no templates exist
  Future<List<DailyChecklist>> createEmergencyChecklists(
    String organizationId,
    String locationId,
    String date,
  ) async {
    debugPrint('ForceChecklistCreator: Creating emergency checklists for $organizationId/$locationId on $date');
    
    final List<DailyChecklist> createdChecklists = [];
    
    // Create default emergency checklists
    final emergencyTemplates = [
      {
        'title': 'Emergency Safety Check',
        'description': 'Basic safety verification checklist',
        'tasks': [
          {'title': 'Check emergency exits', 'description': 'Check emergency exits', 'taskId': 'task1', 'isCompleted': false},
          {'title': 'Verify fire extinguisher locations', 'description': 'Verify fire extinguisher locations', 'taskId': 'task2', 'isCompleted': false},
          {'title': 'Confirm first aid kit accessibility', 'description': 'Confirm first aid kit accessibility', 'taskId': 'task3', 'isCompleted': false},
          {'title': 'Test emergency communication devices', 'description': 'Test emergency communication devices', 'taskId': 'task4', 'isCompleted': false},
        ],
      },
      {
        'title': 'Basic Operations Check',
        'description': 'Essential operational checklist',
        'tasks': [
          {'title': 'Equipment status check', 'description': 'Equipment status check', 'taskId': 'task1', 'isCompleted': false},
          {'title': 'Inventory verification', 'description': 'Inventory verification', 'taskId': 'task2', 'isCompleted': false},
          {'title': 'Cleanliness inspection', 'description': 'Cleanliness inspection', 'taskId': 'task3', 'isCompleted': false},
          {'title': 'Security check', 'description': 'Security check', 'taskId': 'task4', 'isCompleted': false},
        ],
      },
    ];
    
    try {
      for (int i = 0; i < emergencyTemplates.length; i++) {
        final template = emergencyTemplates[i];
        
        final now = DateTime.now();
        
        final checklistData = {
          'checklistTemplateId': 'emergency_template_$i',
          'templateName': template['title'],
          'title': template['title'],
          'description': template['description'],
          'tasks': template['tasks'],
          'date': date,
          'shiftId': 'emergency_shift',
          'locationId': locationId,
          'organizationId': organizationId,
          'isCompleted': false,
          'completedItems': 0,
          'totalItems': (template['tasks'] as List).length,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
          'emergencyCreated': true, // Flag to identify emergency-created checklists
        };
        
        // Save to Firestore
        final docRef = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(organizationId)
            .collection('locations')
            .doc(locationId)
            .collection('daily_checklists')
            .add(checklistData);
        
        // Create DailyChecklist object
        final checklist = DailyChecklist.fromMap(checklistData, docRef.id);
        createdChecklists.add(checklist);
        
        debugPrint('ForceChecklistCreator: Created emergency checklist "${template['title']}" with ID ${docRef.id}');
      }
    } catch (e) {
      debugPrint('ForceChecklistCreator: Error creating emergency checklists: $e');
      rethrow;
    }
    
    debugPrint('ForceChecklistCreator: Successfully created ${createdChecklists.length} emergency checklists');
    return createdChecklists;
  }

  static Future<void> createTestChecklistForShift({
    required String organizationId,
    required String locationId,
    required String shiftId,
    required String shiftName,
  }) async {
    try {
      debugPrint('[ForceChecklistCreator] Creating test checklist for shift $shiftId');
      
      // 1. Create a basic checklist template
      final templateRef = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('checklist_templates')
          .add({
        'name': 'Auto-Generated Checklist for $shiftName',
        'description': 'Basic checklist to test functionality',
        'tasks': [
          {
            'name': 'Check equipment',
            'description': 'Verify all equipment is working',
            'photoRequired': false,
            'order': 0,
          },
          {
            'name': 'Clean workspace',
            'description': 'Clean and sanitize work area',
            'photoRequired': true,
            'order': 1,
          },
          {
            'name': 'Review procedures',
            'description': 'Review safety and operational procedures',
            'photoRequired': false,
            'order': 2,
          },
        ],
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('[ForceChecklistCreator] Created template: ${templateRef.id}');
      
      // 2. Associate the template with the shift
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('shifts')
          .doc(shiftId)
          .update({
        'checklistTemplateIds': FieldValue.arrayUnion([templateRef.id])
      });
      
      debugPrint('[ForceChecklistCreator] Associated template ${templateRef.id} with shift $shiftId');
      
      // 3. Create today's daily checklist
      final today = DateTime.now();
      final dateString = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      await FirebaseFirestore.instance
          .collection('organizations')
          .doc(organizationId)
          .collection('locations')
          .doc(locationId)
          .collection('daily_checklists')
          .add({
        'shiftId': shiftId,
        'organizationId': organizationId,
        'locationId': locationId,
        'templateId': templateRef.id,
        'templateName': 'Auto-Generated Checklist for $shiftName',
        'date': dateString,
        'tasks': [
          {
            'id': 'task1',
            'taskId': 'task1',
            'title': 'Check equipment',
            'name': 'Check equipment',
            'description': 'Verify all equipment is working',
            'completed': false,
            'isCompleted': false,
            'photoRequired': false,
            'order': 0,
          },
          {
            'id': 'task2',
            'taskId': 'task2',
            'title': 'Clean workspace',
            'name': 'Clean workspace',
            'description': 'Clean and sanitize work area',
            'completed': false,
            'isCompleted': false,
            'photoRequired': true,
            'order': 1,
          },
          {
            'id': 'task3',
            'taskId': 'task3',
            'title': 'Review procedures',
            'name': 'Review procedures',
            'description': 'Review safety and operational procedures',
            'completed': false,
            'isCompleted': false,
            'photoRequired': false,
            'order': 2,
          },
        ],
        'isCompleted': false,
        'completedItems': 0,
        'totalItems': 3,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('[ForceChecklistCreator] Successfully created daily checklist for today');
      
    } catch (e, stack) {
      debugPrint('[ForceChecklistCreator] Error: $e\n$stack');
    }
  }
}
