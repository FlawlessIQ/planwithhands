import 'dart:math';

import 'package:hands_app/data/models/location_data.dart';
import 'package:hands_app/data/models/organization_data.dart';
import 'package:hands_app/data/models/shift_data.dart';
import 'package:hands_app/data/models/task_data.dart';
import 'package:uuid/uuid.dart';

var emptyDummyOrgData = OrganizationData(
  id: '12346',
  name: 'Empty Organization',
  createdAt: DateTime.now(),
  locations: [],
);

var dummyOrgData = OrganizationData(
  id: '65434',
  name: 'Golden Fork Organization',
  createdAt: DateTime.now(),
  locations: [
    LocationData(
      locationId: Uuid().v4(),
      locationName: 'Golden Fork Main',
      createdAt: DateTime.now(),
      locationAddress: '12345 Eatin Lane',
      shifts: [
        ShiftData(
          shiftId: '12345',
          shiftName: 'Morning Shift',
          createdAt: DateTime.now(),
          startTime: '07:00',
          endTime: '12:00',
          organizationId: '65434',
          checklistTemplateIds: ['template1', 'template2'],
          activeDays: const [],
        ),
        ShiftData(
          shiftId: '12346',
          shiftName: 'Afternoon Shift',
          createdAt: DateTime.now(),
          startTime: '13:00',
          endTime: '18:00',
          organizationId: '65434',
          checklistTemplateIds: ['template3'],
          activeDays: const [],
        ),
      ],
    ),
    LocationData(
      locationId: Uuid().v4(),
      locationName: 'Golden Fork South',
      createdAt: DateTime.now(),
      locationAddress: '67890 Snack Ave',
      shifts: [
        ShiftData(
          shiftId: '12347',
          shiftName: 'Morning Shift',
          createdAt: DateTime.now(),
          startTime: '07:00',
          endTime: '12:00',
          organizationId: '65434',
          checklistTemplateIds: ['template4'],
          activeDays: const [],
        ),
        ShiftData(
          shiftId: '12348',
          shiftName: 'Evening Shift',
          createdAt: DateTime.now(),
          startTime: '17:00',
          endTime: '22:00',
          organizationId: '65434',
          checklistTemplateIds: ['template5'],
          activeDays: const [],
        ),
      ],
    ),
  ],
);

final Map<String, List<TaskData>> dummyTasksByChecklistId = {
  '23456': [
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Clean Sink',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Pickup Cups',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Idle Around Aimlessly for Several Hours',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Work',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
  ],
  '54675': [
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Fix Rafters',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Fix Falling from Rafters',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
  ],
  '56789': [
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Wipe Tables',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Restock Supplies',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
  ],
  '34567': [
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Setup Coffee Station',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Prep Pastries',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
  ],
  '67890': [
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Clear Tables',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Clean Counters',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
    TaskData(
      taskId: Uuid().v4(),
      taskName: 'Sweep Floors',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(Duration(hours: Random().nextInt(4) + 1)),
    ),
  ],
};

Future<List<TaskData>> fetchDummyTasksForChecklist(String checklistId) async {
  // Simulate async fetch
  await Future.delayed(Duration(milliseconds: 100));
  return dummyTasksByChecklistId[checklistId] ?? [];
}
