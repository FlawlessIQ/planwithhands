# Daily Generator Validation System

## Overview
The daily checklist generator has robust validation to prevent "Unknown Template" issues and ensure only valid templates create checklists.

## Validation Date: October 3, 2025

### Current Status: ✅ ALL TEMPLATES VALID
- **Total Templates in Database**: 63
- **Invalid Templates Found**: 0
- **Validation System**: ACTIVE

---

## Validation Rules Implemented

### 1. Template Name Validation (`fetchValidTemplates`)
Location: `functions/src/dailyGenerator.ts` (lines 72-95)

```typescript
async function fetchValidTemplates(
  orgRef: FirebaseFirestore.DocumentReference,
  locationId: string,
  templateIds: string[],
  logPrefix: string,
): Promise<ValidTemplate[]>
```

**Validation Checks:**

#### ✅ Empty Name Check
```typescript
const templateName = (tData.name || "").toString().trim();
if (!templateName || templateName.toLowerCase() === "unknown template") {
  functions.logger.warn(`Skip template ${templateId} with invalid name: "${templateName}"`);
  continue;
}
```
- Rejects templates with `undefined`, `null`, or empty string names
- Rejects templates explicitly named "Unknown Template" (case-insensitive)
- Logs warnings for rejected templates

#### ✅ Template Existence Check
```typescript
if (!tSnap.exists) {
  functions.logger.warn(`Skip non-existent template ${templateId}`);
  continue;
}
```
- Verifies template document exists before processing
- Prevents errors from stale template references in shifts

#### ✅ Location Assignment Check
```typescript
const locIds = Array.isArray(tData.locationIds) ? (tData.locationIds as string[]) : [];
if (locIds.length > 0 && !locIds.includes(locationId)) {
  functions.logger.warn(`Skip template ${templateId} for location ${locationId}`);
  continue;
}
```
- Ensures templates only generate checklists for assigned locations
- Allows templates without `locationIds` to be used anywhere (global templates)
- Prevents cross-location template assignment errors

---

## Generator Flow

### 1. Scheduled Generator (`scheduledDailyGenerator`)
- Runs every hour via Cloud Scheduler
- Processes all organizations and locations
- Uses timezone-aware date calculation
- Skips locations with no valid templates

### 2. Manual Generator (`generateForOrgDate`)
- Used for testing and manual runs
- Processes single organization for specific date
- Same validation as scheduled generator
- Returns stats: `{createdChecklists, carriedTasks, skipped}`

### 3. Per-Template Checklist Creation
Each valid template creates a separate checklist:
- **Checklist ID Format**: `{orgId}_{locationId}_{shiftId}_{templateId}_{date}`
- **Combined Shift-Template ID**: `{shiftId}_{templateId}`
- **One checklist per shift-template combination**

---

## Prevention Measures

### ❌ What Was Happening Before
1. Templates without names were processed
2. "Unknown Template" was used as fallback
3. Created invalid daily checklists
4. Caused UI filtering issues

### ✅ What Happens Now
1. **Template validation occurs before checklist creation**
2. **Invalid templates are skipped with logged warnings**
3. **Only templates with valid names create checklists**
4. **Logging provides visibility into skipped templates**

---

## Testing & Verification

### Test Run (October 3, 2025)
```bash
node run_generate_for_date.js FErQ4pkcrCovJ7T6L13M 2025-10-03
```

**Results:**
- ✅ 16 checklists created successfully
- ✅ All have valid template names
- ✅ Proper shift-template associations
- ✅ No "Unknown Template" checklists

**Example Output:**
```
Checklists for 2025-10-03: 16
- Template: C Bar - Open (Brunch)
- Template: C Manager - Open (Brunch)
- Template: C Server - Open (Brunch)
- Template: C Busser - Open (Brunch)
[... all with valid names ...]
```

### Database Scan Results
```bash
node check_invalid_templates.js
```

**Results:**
```
Scanning 11 organizations...

=== SUMMARY ===
Valid templates: 63
Invalid templates: 0
```

---

## Monitoring & Maintenance

### Warning Logs to Monitor
Generator logs warnings for skipped templates:

```
{"severity":"WARNING","message":"[generateForOrgDate] Skip checklist creation - no valid templates for shift {shiftId} at location {locationId}"}
```

**This is expected when:**
- A shift references deleted templates
- Templates are assigned to different locations
- Templates have invalid names (should be rare after cleanup)

### Regular Checks
1. **Run validation script monthly:**
   ```bash
   node check_invalid_templates.js
   ```

2. **Monitor Cloud Function logs:**
   - Filter for `"Skip template"` warnings
   - Investigate any templates with empty names
   - Update or delete invalid template references

3. **Database Rules** (Future Enhancement):
   ```javascript
   // Firestore Security Rules
   match /checklist_templates/{templateId} {
     allow create, update: if
       request.resource.data.name is string &&
       request.resource.data.name.size() > 0 &&
       request.resource.data.name.lower() != 'unknown template';
   }
   ```

---

## Architecture Benefits

### Per-Template Checklists
✅ Each template creates its own checklist document  
✅ Clear template attribution (`templateId`, `templateName`)  
✅ Independent task lists per template  
✅ Easier filtering and reporting  

### Validation-First Approach
✅ Invalid data rejected before processing  
✅ Clear error logging for debugging  
✅ No "fallback" names that cause confusion  
✅ Database integrity maintained  

---

## Code References

### TypeScript Source
- **Main Generator**: `functions/src/dailyGenerator.ts`
- **TTL Helper**: `functions/src/firestoreTTLHelper.ts`

### Compiled JavaScript
- **Generator Output**: `functions/lib/dailyGenerator.js`

### Validation Scripts
- **Template Check**: `check_invalid_templates.js`
- **Generator Runner**: `run_generate_for_date.js`

---

## Summary

### ✅ Validation System is Working
- No invalid templates exist in database
- Generator properly filters templates
- Per-template checklists created successfully
- Warning logs provide visibility

### 🎯 Going Forward
- **No "Unknown Template" checklists will be created**
- Invalid templates are skipped with warnings
- Regular monitoring ensures data quality
- System is production-ready

---

**Last Updated**: October 3, 2025  
**Status**: ✅ Production Ready  
**Next Review**: November 2025
