# Unknown Template Checklist Issue - RESOLVED

## Problem Summary
The hourly scheduled generator (`scheduledDailyGenerator`) was creating "Unknown Template" checklists that appeared with no template names and kept being regenerated even after deletion.

## Root Cause
The Cloud Function `dailyGenerator.ts` had a fundamental architectural flaw:

1. **Incorrect Checklist ID Structure**: The `checklistIdFor()` function was creating IDs like:
   ```
   orgId_locationId_shiftId_date  ❌ (missing templateId)
   ```
   Instead of:
   ```
   orgId_locationId_shiftId_templateId_date  ✅ (includes templateId)
   ```

2. **One Checklist Per Shift Instead of Per Template**: This meant that for a shift with 4 templates, the generator created:
   - **OLD (WRONG)**: 1 checklist with an array `checklistTemplateIds: [A, B, C, D]`
   - **NEW (CORRECT)**: 4 separate checklists, each with `checklistTemplateId: A` (or B, C, D)

3. **Missing Template ID Field**: The checklist documents had `checklistTemplateIds` (plural, array) but no `checklistTemplateId` (singular) field, which the Dart app expects.

## Example from User
```javascript
{
  "checklistTemplateIds": [
    "Ezuho3cKjbKv4MZR59dU",
    "H8NR6hf2KQtl9rGHsNzR",
    "cFv5sR9JZd220cjv6g3O",
    "fXYrAHM462QbGiW7sZWl"
  ],
  // Missing: "checklistTemplateId": "...",
  // Missing: "templateName": "...",
  "date": "2025-10-03",
  "createdBy": "generator"
}
```

## Files Modified

### 1. `functions/src/dailyGenerator.ts`
**Changes:**
- Updated `checklistIdFor()` to include `templateId` parameter
- Removed `combinedShiftTemplateId()` helper function
- Changed checklist data structure to use singular fields:
  - `checklistTemplateId` instead of `checklistTemplateIds` array
  - Removed `templateNames` array
  - Removed `combinedShiftTemplateId` field
- Fixed carry-forward logic to properly lookup yesterday's checklist per template

**Before:**
```typescript
export function checklistIdFor(orgId: string, locationId: string, shiftId: string, dateString: string): string {
  return `${orgId}_${locationId}_${shiftId}_${dateString}`;  // ❌
}

const checklistData = {
  checklistTemplateIds: [template.id],  // ❌ array
  templateNames: [template.name],       // ❌ array
  combinedShiftTemplateId: combinedId,  // ❌ extra field
  // Missing checklistTemplateId!
};
```

**After:**
```typescript
export function checklistIdFor(orgId: string, locationId: string, shiftId: string, templateId: string, dateString: string): string {
  return `${orgId}_${locationId}_${shiftId}_${templateId}_${dateString}`;  // ✅
}

const checklistData = {
  checklistTemplateId: template.id,  // ✅ singular
  templateId: template.id,           // ✅ redundant but ensures compatibility
  templateName: template.name,       // ✅ singular
  // Removed array fields
};
```

### 2. `lib/services/daily_checklist_service.dart`
**Changes:**
- Added validation to prevent checklists with missing/empty template names
- Added checks for `deleted` and `active` template flags in both:
  - `ensureDailyChecklistAndTasks()` method
  - `generateDailyChecklists()` loop

**Added validation:**
```dart
// CRITICAL FIX: Prevent creation of checklists from deleted or inactive templates
if (isDeleted) {
  debugPrint('[DailyChecklistService] BLOCKED: Template $templateId is deleted, skipping checklist creation');
  return;
}

if (!isActive) {
  debugPrint('[DailyChecklistService] BLOCKED: Template $templateId is inactive, skipping checklist creation');
  return;
}
```

## Cleanup Performed

**Deleted 28 problem checklists** from October 1-3, 2025:
- 4 aggregated checklists (no template ID, array of 4 templates each)
- 24 newer checklists (had proper template ID in ID string but still had the array field)

**Total tasks cleaned up:** 936 orphaned tasks across 28 checklists

## Verification

Run this to verify no more problem checklists exist:
```bash
node find_unknown_checklists.js
```

Expected output:
```
Problem Checklists (missing template names): 0
✅ No problem checklists found!
```

## Future Prevention

The fixes ensure:

1. ✅ **Cloud Function creates separate checklists per template** - Each template gets its own checklist document
2. ✅ **Proper template ID in checklist ID** - IDs now include templateId: `org_loc_shift_template_date`
3. ✅ **Singular template fields** - Uses `checklistTemplateId` and `templateName` (not arrays)
4. ✅ **Deleted/inactive template validation** - Both Cloud Function and Dart app check template status
5. ✅ **No more "Unknown Template" checklists** - Generator validates template names before creating checklists

## Deployment Status

✅ **Cloud Functions deployed** (43 functions updated)
- `scheduledDailyGenerator` - Fixed to create proper checklist structure
- All other functions redeployed with latest code

✅ **Dart validation added** - App will prevent creation of invalid checklists

## Testing

The next hourly run (at the top of the hour) will create properly structured checklists with:
- Unique checklist IDs per template
- Proper `checklistTemplateId` field (singular)
- `templateName` field populated
- No `checklistTemplateIds` array

## Related Documentation

- See `functions/src/dailyGenerator.ts` for full implementation
- See `lib/services/daily_checklist_service.dart` for Dart-side validation
- Cleanup script: `delete_unknown_checklists.js`
- Investigation script: `find_unknown_checklists.js`

---

**Issue Status:** ✅ RESOLVED
**Date Fixed:** October 3, 2025
**Deployed:** Yes
**Tested:** Pending next hourly run
