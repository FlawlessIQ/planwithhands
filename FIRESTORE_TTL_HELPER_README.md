# Firestore TTL (Time-To-Live) Helper

This helper automatically manages `expiresAt` fields for Firestore collections that require Time-To-Live (TTL) policies.

## Overview

The TTL helper provides automatic `expiresAt` field management for both Flutter client and Cloud Functions, ensuring consistent TTL behavior across your application without requiring manual field management.

## Collections with TTL Policies

| Collection | TTL Period | Purpose |
|------------|------------|---------|
| `daily_checklists` | 30 days | Daily operational checklists |
| `tasks` | 30 days | Task documents within checklists |
| `notifications` | 30 days | User and organization notifications |
| `messages` | 30 days | User messages |
| `daily_summary_by_location` | 30 days | Location-level daily summaries |
| `daily_summary_by_shift` | 30 days | Shift-level daily summaries |
| `invites` | 7 days | User invitation tokens |
| `debug_logs` | 7 days | Debug and diagnostic logs |
| `debug_checklists` | 7 days | Debug checklist data |
| `debug_tasks` | 7 days | Debug task data |
| `debug_notifications` | 7 days | Debug notification data |
| `daily_summary_by_organization` | 90 days | Organization-level summaries |
| `daily_summary_by_organization_location` | 90 days | Org+location summaries |
| `daily_summary_by_organization_shift` | 90 days | Org+shift summaries |

## Usage

### Flutter/Dart Client

```dart
import 'package:hands_app/utils/firestore_ttl_helper.dart';

// Automatic TTL-aware document creation
final docRef = FirebaseFirestore.instance.collection('notifications').doc();
await FirestoreTTLHelper.setWithTTL(docRef, {
  'title': 'Test Notification',
  'message': 'This will automatically get expiresAt field',
  'createdAt': FieldValue.serverTimestamp(),
});

// Batch operations with TTL
final batch = FirebaseFirestore.instance.batch();
FirestoreTTLHelper.batchSetWithTTL(batch, docRef, data);
await batch.commit();

// Add to collection with TTL
final collectionRef = FirebaseFirestore.instance.collection('tasks');
await FirestoreTTLHelper.addWithTTL(collectionRef, taskData);
```

### Cloud Functions (TypeScript)

```typescript
import { FirestoreTTLHelper } from './firestoreTTLHelper';

// Automatic TTL in Functions
const docRef = db.collection('notifications').doc();
await FirestoreTTLHelper.setWithTTL(docRef, {
  title: 'Test Notification',
  message: 'This will automatically get expiresAt field',
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
});

// Batch operations
const batch = db.batch();
FirestoreTTLHelper.batchSetWithTTL(batch, docRef, data);
await batch.commit();
```

### Cloud Functions (JavaScript)

```javascript
const FirestoreTTLHelper = require('./firestoreTTLHelper');

// Automatic TTL in JavaScript Functions
const docRef = db.collection('notifications').doc();
await FirestoreTTLHelper.setWithTTL(docRef, {
  title: 'Test Notification',
  message: 'This will automatically get expiresAt field',
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

## Key Features

### Automatic Field Management
- Automatically adds `expiresAt` fields to documents in TTL-enabled collections
- Does NOT overwrite existing `expiresAt` values
- Works with nested subcollections (e.g., `organizations/{orgId}/locations/{locId}/daily_checklists/{checklistId}/tasks/{taskId}`)

### Path-Aware TTL Detection
- Analyzes document paths to determine the appropriate collection type
- Supports complex nested paths like `organizations/abc/locations/xyz/daily_checklists/123/tasks/456`
- Extracts the relevant collection name (`tasks` in the example above)

### Consistent API
- Drop-in replacement for standard Firestore operations
- Same method signatures with automatic TTL enhancement
- Works with `set()`, `add()`, batch operations, and transactions

## Implementation Details

### TTL Calculation
TTL timestamps are calculated as `DateTime.now() + Duration(days: ttlDays)` on the client/server when the document is created.

### Collection Path Analysis
The helper analyzes document reference paths to determine which collection the document belongs to:
- `/notifications/doc1` → `notifications` collection → 30 days TTL
- `/organizations/org1/locations/loc1/daily_checklists/check1/tasks/task1` → `tasks` collection → 30 days TTL

### Non-TTL Collections
Documents in collections without TTL policies (like `users`, `organizations`, `locations`) are written normally without `expiresAt` fields.

## Enabling TTL in Firestore Console

After implementing the helper, enable TTL policies in the Firebase Console:

1. Open Firebase Console → Firestore → Data
2. Click "Indexes & TTL" → "TTL policies" 
3. Click "Create TTL policy"
4. Set collection scope and field name: `expiresAt`
5. Confirm and enable

Note: TTL deletion is eventually consistent and may take up to 72 hours.

## Migration for Existing Documents

Use the provided backfill script to add TTL fields to existing documents:

```bash
# From functions directory
node scripts/backfillExpiresAt.js --collections=tasks,notifications --dry-run
node scripts/backfillExpiresAt.js --collections=tasks,notifications
```

## Best Practices

1. **Always use the TTL helper** for document writes in TTL-enabled collections
2. **Test thoroughly** in development environment before production deployment  
3. **Monitor TTL policies** to ensure they're working as expected
4. **Consider data retention requirements** when setting TTL periods
5. **Use dry-run mode** for migration scripts to preview changes

## Troubleshooting

### Documents Not Being Deleted
- Check that TTL policy is enabled in Firebase Console
- Verify `expiresAt` field contains valid Timestamp values
- Remember TTL is eventually consistent (up to 72 hours)

### Missing expiresAt Fields
- Ensure you're using TTL helper methods instead of direct Firestore calls
- Check collection name mapping in helper configuration
- Verify document paths for nested subcollections

### Development vs Production
- TTL policies must be configured in each Firebase project
- Test scripts and helpers in development environment first
- Consider different TTL periods for development vs production
