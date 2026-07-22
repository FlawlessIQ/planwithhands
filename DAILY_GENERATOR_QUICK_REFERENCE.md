# Daily Generator - Quick Reference Guide

## ✅ Validation Status: PRODUCTION READY

After your manual cleanup of invalid templates, the system is now fully protected against "Unknown Template" issues.

---

## What Changed

### Before (Problem):
- Templates without names could be processed
- "Unknown Template" was used as fallback
- Invalid checklists were created daily
- Caused confusion and UI issues

### After (Solution):
- **Validation blocks invalid templates before processing**
- **No fallback names - invalid templates are skipped**
- **Clear warning logs for debugging**
- **All 63 templates in database are valid**

---

## Validation Rules

The generator (`functions/src/dailyGenerator.ts`) validates every template:

```typescript
// ❌ REJECTS:
- Empty names: "", "   ", null, undefined
- "Unknown Template" (any case)
- Non-existent template documents
- Templates not assigned to the location

// ✅ ACCEPTS:
- Templates with valid names
- Templates assigned to location (or global templates)
- Templates that exist in database
```

---

## How It Works

### 1. Scheduled Generation (Every Hour)
```
Cloud Scheduler → scheduledDailyGenerator
  ↓
For each Organization:
  For each Location:
    For each Shift:
      ✓ Validate templates (fetchValidTemplates)
      ✓ Create one checklist per valid template
      ✓ Skip invalid templates with warning
```

### 2. Manual Generation (Testing/Backfill)
```bash
# Generate for specific org and date
node run_generate_for_date.js <orgId> <YYYY-MM-DD>

# Generate for ALL orgs
node run_generate_for_date.js all <YYYY-MM-DD>
```

---

## Monitoring Commands

### Check for Invalid Templates
```bash
node check_invalid_templates.js
```
Expected output: `Invalid templates: 0`

### Demonstrate Validation Rules
```bash
node demonstrate_validation.js
```
Shows validation logic with test cases

### Test Generator for Specific Org
```bash
node run_generate_for_date.js FErQ4pkcrCovJ7T6L13M 2025-10-03
```
Should show warnings only for shifts with no valid templates

### View Generated Checklists
```bash
node -e "const {Firestore}=require('@google-cloud/firestore');
const db=new Firestore({databaseId:'planwithhands'});
(async()=>{
  const snap=await db.collection('organizations')
    .doc('YOUR_ORG_ID')
    .collection('locations')
    .doc('YOUR_LOCATION_ID')
    .collection('daily_checklists')
    .where('date','==','2025-10-03')
    .get();
  console.log('Checklists:', snap.size);
  snap.docs.forEach(d => {
    const data = d.data();
    console.log('-', data.templateName, '(', data.templateId, ')');
  });
})();"
```

---

## Warning Logs (Normal Behavior)

You may see these warnings in Cloud Functions logs:

```json
{"severity":"WARNING","message":"[dailyGenerator] Skip checklist creation - no valid templates for shift XYZ at location ABC"}
```

**This is expected when:**
- A shift has no templates assigned
- All shift templates were deleted
- All shift templates belong to other locations

**Action needed:** None, unless you expected templates for that shift

---

## Architecture

### Checklist Document Structure
```javascript
{
  id: "orgId_locationId_shiftId_templateId_date",
  organizationId: "...",
  locationId: "...",
  shiftId: "...",
  templateId: "...",
  templateName: "...",  // ✅ Always has valid name
  templateNames: ["..."],  // Array with single template name
  checklistTemplateIds: ["..."],  // Array with single template ID
  combinedShiftTemplateId: "shiftId_templateId",
  date: "2025-10-03",
  createdAt: Timestamp,
  createdBy: "generator",
  expiresAt: Timestamp  // 30 days from creation
}
```

### Benefits of Per-Template Checklists
- ✅ Clear template attribution
- ✅ Independent task lists
- ✅ Easier filtering and reporting
- ✅ No ambiguity about template source

---

## Maintenance Schedule

### Monthly (First Week)
```bash
# 1. Scan for invalid templates
node check_invalid_templates.js

# Expected: "Invalid templates: 0"
# If any found, investigate and fix
```

### After Template Changes
```bash
# 2. Test generator with changed org
node run_generate_for_date.js <orgId> <today's date>

# 3. Verify checklists created
# Check that all expected templates generated checklists
```

### Monitor Cloud Functions
- Check logs for unusual `"Skip template"` warnings
- Verify scheduled runs complete successfully
- Monitor checklist creation rates

---

## Troubleshooting

### Problem: Shift generates no checklists

**Check 1: Does shift have templates?**
```javascript
// Query shift document
organizations/{orgId}/shifts/{shiftId}
// Look at: checklistTemplateIds: [...]
```

**Check 2: Are templates valid?**
```bash
node check_invalid_templates.js
```

**Check 3: Are templates assigned to location?**
```javascript
// Query template document
organizations/{orgId}/checklist_templates/{templateId}
// Check: locationIds array includes the location
// OR: locationIds is empty (global template)
```

### Problem: "Unknown Template" checklist appears

**This should not happen anymore!** But if it does:

1. Check generator validation is deployed:
   ```bash
   cd functions
   npm run build
   firebase deploy --only functions:scheduledDailyGenerator
   ```

2. Verify template in database:
   ```bash
   node check_invalid_templates.js
   ```

3. Check Cloud Function logs for errors

---

## Files Reference

### Core Generator
- `functions/src/dailyGenerator.ts` - TypeScript source
- `functions/lib/dailyGenerator.js` - Compiled output

### Validation Scripts
- `check_invalid_templates.js` - Database scan
- `demonstrate_validation.js` - Visual demonstration
- `run_generate_for_date.js` - Manual generator runner

### Documentation
- `DAILY_GENERATOR_VALIDATION.md` - Full validation system docs
- `DAILY_GENERATOR_QUICK_REFERENCE.md` - This file

---

## Quick Wins ✨

### Current Status
- ✅ 63 valid templates across 11 organizations
- ✅ 0 invalid templates
- ✅ Validation system active
- ✅ Per-template checklist generation working
- ✅ Comprehensive logging for debugging

### Going Forward
- ✅ No "Unknown Template" checklists will be created
- ✅ Invalid templates automatically skipped
- ✅ Clear warnings for debugging
- ✅ Easy monitoring with provided scripts

---

**System Status**: 🟢 HEALTHY  
**Last Verified**: October 3, 2025  
**Next Review**: Monthly check recommended
