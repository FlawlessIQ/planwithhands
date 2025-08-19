# Daily Checklist Subcollection Migration Guide

This document explains the new subcollection-based task management system and how to migrate from the legacy array-based approach.

## Overview

### Old System (Arrays)
```
daily_checklists/{id}
├── tasks: [array of task objects]
├── organizationId
├── locationId
├── shiftId
└── templateId
```

### New System (Subcollections)
```
daily_checklists/{id}
├── organizationId
├── locationId
├── shiftId
├── templateId
└── tasks/{taskId} (subcollection)
    ├── taskId
    ├── taskName
    ├── completed
    ├── photoRequired
    ├── createdAt
    ├── dueDate
    ├── completedBy?
    ├── completedAt?
    ├── proofImageUrl?
    ├── notes?
    └── isCarryForward?
```

## Benefits of Subcollections

1. **Real-time Updates**: Stream individual task changes without downloading entire arrays
2. **Atomic Operations**: Update single tasks without transaction conflicts
3. **Better Performance**: Only load/update specific tasks when needed
4. **Scalability**: No document size limits for large checklists
5. **Concurrent Access**: Multiple users can update different tasks simultaneously

## New DailyChecklistService Methods

### 1. Deterministic ID Generation

```dart
// Checklist ID
String checklistId = "${organizationId}_${locationId}_${shiftId}_${templateId}_${dateString}";

// Task ID (for template tasks)
String taskId = sha1("${templateTaskId}|${checklistId}|${dateString}").substring(0, 16);

// Carry-forward task ID
String cfTaskId = sha1("${originalChecklistId}|${originalTaskId}|${dateString}").substring(0, 16);
```

### 2. Idempotent Generation

```dart
// Ensure daily checklist and tasks exist (safe to call multiple times)
await service.ensureDailyChecklistAndTasks(
  organizationId: 'org123',
  locationId: 'loc456',
  shiftId: 'shift789',
  templateId: 'template001',
  dateString: '2024-01-15',
);
```

### 3. Carry-forward Operations

```dart
// Carry forward yesterday's incomplete tasks to today
await service.carryForwardMissedTasksToSubcollections(
  organizationId: 'org123',
  locationId: 'loc456',
  dateString: '2024-01-15', // Today's date
);
```

### 4. Atomic Task Operations

```dart
// Complete a task
await service.completeTask(
  organizationId: 'org123',
  locationId: 'loc456',
  checklistId: 'checklist_id',
  taskId: 'task_id',
  userId: 'user123',
);

// Uncomplete a task
await service.uncompleteTask(
  organizationId: 'org123',
  locationId: 'loc456',
  checklistId: 'checklist_id',
  taskId: 'task_id',
);

// Update task notes
await service.updateTaskNotes(
  organizationId: 'org123',
  locationId: 'loc456',
  checklistId: 'checklist_id',
  taskId: 'task_id',
  notes: 'Task completed successfully',
);

// Update task photo
await service.updateTaskPhotoInSubcollection(
  organizationId: 'org123',
  locationId: 'loc456',
  checklistId: 'checklist_id',
  taskId: 'task_id',
  proofImageUrl: 'https://storage.googleapis.com/...',
);
```

### 5. Real-time Streaming

```dart
// Stream tasks for a checklist
Stream<List<TaskData>> tasksStream = service.streamChecklistTasks(
  organizationId: 'org123',
  locationId: 'loc456',
  checklistId: 'checklist_id',
);

// Use in widget
StreamBuilder<List<TaskData>>(
  stream: tasksStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final tasks = snapshot.data!;
      return ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return CheckboxListTile(
            value: task.completed,
            title: Text(task.taskName),
            onChanged: (completed) async {
              if (completed == true) {
                await service.completeTask(/* ... */);
              } else {
                await service.uncompleteTask(/* ... */);
              }
            },
          );
        },
      );
    }
    return CircularProgressIndicator();
  },
)
```

### 6. Statistics and Reporting

```dart
// Get completion stats for today
final stats = await service.getTodayCompletionStats(
  organizationId: 'org123',
  locationId: 'loc456',
  dateString: '2024-01-15',
);

print('Total: ${stats['totalTasks']}');
print('Completed: ${stats['completedTasks']}');
print('Progress: ${stats['completionPercentage']}%');
```

## Migration Process

### Step 1: Assessment

Use the migration helper to assess your current data:

```dart
final migrationHelper = TaskMigrationHelper();

// Generate a report
final report = await migrationHelper.generateMigrationReport(
  organizationId: 'org123',
  locationId: 'loc456',
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 1, 31),
);

print('Migration Report: $report');
```

### Step 2: Dry Run

Always run a dry migration first to see what would be migrated:

```dart
// Dry run migration (safe - won't change data)
await migrationHelper.migrateDateRange(
  organizationId: 'org123',
  locationId: 'loc456',
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 1, 7),
  dryRun: true, // Safe mode
);
```

### Step 3: Actual Migration

Once satisfied with dry run results:

```dart
// Actual migration (CAREFUL - this modifies data)
await migrationHelper.migrateDateRange(
  organizationId: 'org123',
  locationId: 'loc456',
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 1, 7),
  dryRun: false, // Live migration
);
```

### Step 4: Verification

Verify the migration was successful:

```dart
final verification = await migrationHelper.verifyMigration(
  organizationId: 'org123',
  locationId: 'loc456',
  checklistId: 'specific_checklist_id',
);

print('Migration Status: $verification');
```

## UI Integration Examples

### Real-time Task List

See `lib/examples/subcollection_tasks_example.dart` for a complete example of:
- Streaming task updates
- Atomic task operations
- Progress tracking
- Error handling

### Dashboard Integration

Replace array-based queries with subcollection queries:

```dart
// OLD: Query entire checklist document
final checklistDoc = await checklistRef.get();
final tasks = checklistDoc.data()['tasks'] as List;

// NEW: Stream subcollection directly
final tasksStream = checklistRef.collection('tasks').snapshots();
```

## Performance Considerations

### Benefits
- **Reduced Data Transfer**: Only changed tasks are sent over the network
- **Concurrent Updates**: Multiple users can update different tasks simultaneously
- **Scalability**: No document size limits (1MB limit removed)
- **Real-time**: Instant updates for individual task changes

### Trade-offs
- **Query Complexity**: Some aggregate queries require collection group queries
- **Cold Start**: Initial subcollection reads may be slightly slower
- **Firestore Costs**: More granular operations may increase read/write counts

## Best Practices

### 1. Use Deterministic IDs
Always use the deterministic ID generation methods to ensure consistency across multiple calls.

### 2. Handle Errors Gracefully
```dart
try {
  await service.completeTask(/* ... */);
} catch (e) {
  // Show user-friendly error message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to complete task: $e')),
  );
}
```

### 3. Implement Offline Support
Use Firestore's offline persistence for better user experience:

```dart
FirebaseFirestore.instance.enablePersistence();
```

### 4. Batch Operations When Possible
For bulk operations, use Firestore batches:

```dart
final batch = FirebaseFirestore.instance.batch();
// Add multiple operations to batch
await batch.commit();
```

## Migration Timeline

### Phase 1: Preparation (Week 1)
- Review current data structure
- Run migration reports
- Test new methods in development

### Phase 2: Pilot Migration (Week 2)
- Migrate small date range in staging
- Test real-time functionality
- Validate data integrity

### Phase 3: Production Migration (Week 3)
- Migrate historical data in batches
- Deploy new UI components
- Monitor performance metrics

### Phase 4: Cleanup (Week 4)
- Remove legacy array-based code
- Update documentation
- Train team on new patterns

## Troubleshooting

### Common Issues

1. **Checklist Not Found**
   - Ensure checklist exists before querying tasks
   - Use `ensureDailyChecklistAndTasks()` to create if needed

2. **Task ID Conflicts**
   - Use deterministic ID generation methods
   - Check for existing tasks before creating

3. **Permission Errors**
   - Verify Firestore security rules allow subcollection access
   - Check user authentication status

4. **Performance Issues**
   - Use appropriate indexes for queries
   - Implement pagination for large task lists
   - Consider caching frequently accessed data

### Support

For questions or issues with the migration:
1. Check the example files in `lib/examples/`
2. Review migration helper in `lib/utils/task_migration_helper.dart`
3. Test with small datasets first
4. Monitor Firestore usage and costs during migration

## Future Enhancements

The subcollection architecture enables future features:
- Task dependencies and workflows
- Real-time collaboration indicators
- Advanced filtering and search
- Task templates and automation
- Performance analytics and insights
