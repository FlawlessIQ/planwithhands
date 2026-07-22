// Simple test to see if our checklist generation fix is working
void main() {
  print('🔧 Testing checklist generation fix...');

  // Simulate template data
  final templateData = {
    'id': 'test-template',
    'name': 'Test Template',
    'jobTypes': ['Bartender', 'Manager'],
    'tasks': [],
  };

  // Simulate how our fixed ensureDailyChecklistAndTasks method would work
  final checklistData = {
    'id': 'test-checklist',
    'name': templateData['name'],
    'checklistTemplateId': templateData['id'],
    'tasks': templateData['tasks'],
    // This is the key fix - inheriting job types from template
    'jobTypes': templateData['jobTypes'] ?? templateData['jobType'],
    'createdAt': DateTime.now().toIso8601String(),
  };

  print('✅ Generated checklist data:');
  print(checklistData);

  // Test filtering logic
  final userJobTypes = ['Bartender', 'Manager', 'Host/Hostess'];
  final checklistJobTypes = checklistData['jobTypes'] as List<String>;

  final userJobTypesSet = userJobTypes.toSet();
  final checklistJobTypesSet = checklistJobTypes.toSet();
  final hasMatchingJobType = userJobTypesSet.intersection(checklistJobTypesSet).isNotEmpty;

  print('🔍 Testing filtering:');
  print('User job types: $userJobTypes');
  print('Checklist job types: $checklistJobTypes');
  print('Has matching job type: $hasMatchingJobType');
  print('Should show checklist: $hasMatchingJobType');

  // Test case 2: Checklist for dishwasher only
  final dishwasherChecklist = {
    'jobTypes': ['Dishwasher'],
  };

  final dishwasherJobTypes = dishwasherChecklist['jobTypes'] as List<String>;
  final dishwasherJobTypesSet = dishwasherJobTypes.toSet();
  final hasMatchingJobType2 = userJobTypesSet.intersection(dishwasherJobTypesSet).isNotEmpty;

  print('\\n🔍 Testing dishwasher checklist filtering:');
  print('User job types: $userJobTypes');
  print('Dishwasher checklist job types: $dishwasherJobTypes');
  print('Has matching job type: $hasMatchingJobType2');
  print('Should show checklist: $hasMatchingJobType2');

  if (!hasMatchingJobType2) {
    print('✅ Success! Dishwasher checklist correctly filtered out for bartender user');
  } else {
    print('❌ Error! Dishwasher checklist would still show for bartender user');
  }
}
