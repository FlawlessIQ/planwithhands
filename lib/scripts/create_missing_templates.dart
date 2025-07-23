import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Script to create missing checklist templates
/// This will create the templates that the shifts are expecting
class CreateMissingTemplates {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String organizationId = '5dQCGM4MTiJsqVoedI04';

  /// Create all missing templates based on the error logs
  static Future<void> createMissingTemplates() async {
    debugPrint('[CreateTemplates] Starting template creation...');

    final templatesToCreate = [
      {
        'id': 'XCDEWikWhtXK3CqhkoBL',
        'name': 'Kitchen Opening Checklist',
        'description': 'Standard opening checklist for kitchen operations',
        'tasks': [
          {'title': 'Turn on all equipment', 'photoRequired': false},
          {'title': 'Check inventory levels', 'photoRequired': false},
          {'title': 'Clean and sanitize prep areas', 'photoRequired': true},
          {'title': 'Verify temperature logs', 'photoRequired': false},
          {'title': 'Set up cooking stations', 'photoRequired': false},
        ]
      },
      {
        'id': 'ESFpoW8BY5DLHWzdTbaX',
        'name': 'Bar Opening Checklist',
        'description': 'Standard opening checklist for bar operations',
        'tasks': [
          {'title': 'Stock bar with clean glassware', 'photoRequired': false},
          {'title': 'Check liquor inventory', 'photoRequired': false},
          {'title': 'Prepare garnishes and mixers', 'photoRequired': true},
          {'title': 'Clean and sanitize bar area', 'photoRequired': true},
          {'title': 'Test POS system', 'photoRequired': false},
          {'title': 'Set up cash register', 'photoRequired': false},
        ]
      },
      {
        'id': 'JFGjWZRfJ0vEIxwRrunQ',
        'name': 'General Opening Tasks',
        'description': 'General tasks for opening the restaurant',
        'tasks': [
          {'title': 'Unlock front entrance', 'photoRequired': false},
          {'title': 'Turn on lights and music', 'photoRequired': false},
          {'title': 'Check restroom supplies', 'photoRequired': false},
          {'title': 'Review daily specials', 'photoRequired': false},
          {'title': 'Brief team on daily goals', 'photoRequired': false},
        ]
      },
    ];

    for (final template in templatesToCreate) {
      try {
        debugPrint('[CreateTemplates] Creating template: ${template['name']}');
        
        final templateData = {
          'name': template['name'],
          'description': template['description'],
          'tasks': template['tasks'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'category': 'Opening',
        };

        await _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('checklist_templates')
            .doc(template['id'] as String)
            .set(templateData);

        debugPrint('[CreateTemplates] Successfully created template: ${template['name']}');
        
      } catch (e, stack) {
        debugPrint('[CreateTemplates] Error creating template ${template['name']}: $e\n$stack');
      }
    }

    debugPrint('[CreateTemplates] Template creation complete!');
  }

  /// Verify that all templates exist
  static Future<void> verifyTemplates() async {
    debugPrint('[CreateTemplates] Verifying templates...');
    
    final templateIds = [
      'XCDEWikWhtXK3CqhkoBL',
      'ESFpoW8BY5DLHWzdTbaX', 
      'JFGjWZRfJ0vEIxwRrunQ'
    ];

    for (final templateId in templateIds) {
      try {
        final doc = await _firestore
            .collection('organizations')
            .doc(organizationId)
            .collection('checklist_templates')
            .doc(templateId)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          debugPrint('[CreateTemplates] ✅ Template $templateId exists: ${data['name']} (${(data['tasks'] as List).length} tasks)');
        } else {
          debugPrint('[CreateTemplates] ❌ Template $templateId NOT FOUND');
        }
      } catch (e) {
        debugPrint('[CreateTemplates] Error checking template $templateId: $e');
      }
    }
  }
}

/// Standalone function to run template creation
Future<void> runCreateMissingTemplates() async {
  debugPrint('[CreateTemplates] Running missing template creation...');
  await CreateMissingTemplates.createMissingTemplates();
  await CreateMissingTemplates.verifyTemplates();
  debugPrint('[CreateTemplates] All done!');
}
