# Location Consistency Prevention & Monitoring System

This system provides comprehensive monitoring and prevention tools to ensure checklist templates are never assigned to shifts at different locations, preventing the data corruption issue we recently fixed.

## 🚀 Quick Start

### 1. Run Immediate Validation
```bash
# Check all organizations for location consistency issues
node validate_location_consistency.js
```

### 2. Start Monitoring
```bash
# Run a monitoring check and save results
node monitoring_system.js run

# Check current status
node monitoring_system.js status

# View monitoring history
node monitoring_system.js history
```

### 3. Audit Specific Organization
```bash
# Deep audit of a specific organization
node prevention_utilities.js FErQ4pkcrCovJ7T6L13M
```

## 📋 System Components

### 1. **validate_location_consistency.js**
**Purpose**: Core validation engine that checks for cross-location assignment issues

**What it checks**:
- Templates assigned to shifts at different locations
- Shifts with no location assigned
- Templates with no location assigned
- Checklists assigned to wrong shifts
- Orphaned references (non-existent templates/shifts)

**Usage**:
```bash
node validate_location_consistency.js
```

**Output**: Detailed report with severity levels (HIGH/MEDIUM/LOW)

### 2. **prevention_utilities.js**
**Purpose**: Validation functions to prevent issues before they occur

**Key Functions**:
- `validateShiftTemplateAssignment()` - Validates template assignments before saving
- `validateChecklistShiftAssignment()` - Validates checklist assignments
- `safeUpdateShift()` - Safe shift update with validation
- `safeAssignChecklistToShift()` - Safe checklist assignment
- `auditDataIntegrity()` - Comprehensive organization audit

**Usage in Application Code**:
```javascript
const { safeUpdateShift, validateShiftTemplateAssignment } = require('./prevention_utilities');

// Example: Safely update a shift with validation
await safeUpdateShift(orgId, shiftId, {
  checklistTemplateIds: ['template1', 'template2']
});
```

### 3. **monitoring_system.js**
**Purpose**: Automated monitoring with alerting and historical tracking

**Features**:
- Scheduled validation runs
- Automatic alert generation for critical issues
- Historical report storage
- Dashboard integration via Firestore
- Cleanup of old reports

**Commands**:
```bash
# Run monitoring check
node monitoring_system.js run

# View current status
node monitoring_system.js status

# View history (last 7 days by default)
node monitoring_system.js history

# View last 30 days
node monitoring_system.js history 30
```

### 4. **firebase_config.js**
**Purpose**: Shared Firebase configuration to prevent initialization conflicts

## 📊 Monitoring Dashboard Data

The monitoring system stores data in Firestore for dashboard integration:

### Collections Created:
- `system_monitoring/location_consistency` - Current status and latest results
- `system_monitoring/location_consistency/reports/{reportId}` - Historical reports
- `system_alerts` - Active alerts for critical issues

### Alert Types:
- `LOCATION_CONSISTENCY_CRITICAL` - High severity issues found
- `LOCATION_CONSISTENCY_WARNING` - Medium severity issues found
- `MONITORING_FAILURE` - Monitoring system failure

## 🛡️ Prevention Integration

To prevent future issues, integrate the prevention utilities into your application:

### 1. Shift Template Assignment
```javascript
// Before updating shift templates
const { validateShiftTemplateAssignment } = require('./prevention_utilities');

try {
  await validateShiftTemplateAssignment(orgId, shiftData, templateIds);
  // Proceed with update
  await updateShiftTemplates(shiftId, templateIds);
} catch (error) {
  // Handle validation error
  console.error('Invalid template assignment:', error.message);
}
```

### 2. Checklist Assignment
```javascript
// Before assigning checklist to shift
const { validateChecklistShiftAssignment } = require('./prevention_utilities');

try {
  await validateChecklistShiftAssignment(orgId, checklistData, shiftId);
  // Proceed with assignment
  await assignChecklistToShift(checklistId, shiftId);
} catch (error) {
  console.error('Invalid checklist assignment:', error.message);
}
```

### 3. Safe Operations
```javascript
const { safeUpdateShift, safeAssignChecklistToShift } = require('./prevention_utilities');

// These functions include built-in validation
await safeUpdateShift(orgId, shiftId, updateData);
await safeAssignChecklistToShift(orgId, checklistId, shiftId);
```

## ⏰ Scheduled Monitoring

### Setup Cron Job (Recommended)
Add to your server's crontab for automated monitoring:

```bash
# Edit crontab
crontab -e

# Add these lines for daily monitoring at 6 AM
0 6 * * * cd /path/to/your/project && node monitoring_system.js run

# For weekly monitoring (Mondays at 6 AM)
0 6 * * 1 cd /path/to/your/project && node monitoring_system.js run
```

### Cloud Function (Alternative)
Deploy as a scheduled Cloud Function:

```javascript
exports.scheduledLocationCheck = functions.pubsub
  .schedule('0 6 * * *') // Daily at 6 AM
  .onRun(async (context) => {
    const { runMonitoring } = require('./monitoring_system');
    return await runMonitoring();
  });
```

## 🚨 Alert Integration

### Email Notifications
Extend the `sendAlertIfNeeded()` function in monitoring_system.js:

```javascript
// Add to sendAlertIfNeeded function
if (report.highSeverityCount > 0) {
  // Send email
  await sendEmailAlert({
    to: 'admin@yourcompany.com',
    subject: 'Critical Location Consistency Issues',
    body: `Found ${report.highSeverityCount} critical issues...`
  });
}
```

### Slack Integration
```javascript
// Add Slack webhook
const axios = require('axios');

if (report.highSeverityCount > 0) {
  await axios.post(process.env.SLACK_WEBHOOK_URL, {
    text: `🚨 Critical location consistency issues detected: ${report.highSeverityCount} high severity issues found.`
  });
}
```

## 🔍 Issue Types Detected

### HIGH Severity Issues
- **CROSS_LOCATION_ASSIGNMENT**: Template from one location assigned to shift at different location
- **TEMPLATE_NOT_FOUND**: Shift references non-existent template
- **SHIFT_NO_LOCATION**: Shift has no location assigned

### MEDIUM Severity Issues
- **CHECKLIST_WRONG_SHIFT**: Checklist assigned to shift at different location
- **CHECKLIST_ORPHANED_SHIFT**: Checklist assigned to non-existent shift

### LOW Severity Issues
- **ORG_CHECK_ERROR**: Error occurred while checking organization

## 📈 Performance Considerations

- **Batch Operations**: Validation processes multiple organizations efficiently
- **Firestore Optimization**: Uses proper indexing and query optimization
- **Memory Management**: Processes organizations sequentially to manage memory
- **Report Cleanup**: Automatically removes reports older than 30 days

## 🧪 Testing

Test the system with different scenarios:

```bash
# Test validation with clean data
node validate_location_consistency.js

# Test monitoring system
node monitoring_system.js run

# Test specific organization audit
node prevention_utilities.js YOUR_ORG_ID

# Check monitoring status
node monitoring_system.js status
```

## 🛠️ Troubleshooting

### Common Issues

1. **Firebase Permission Errors**
   - Ensure your service account has Firestore read/write permissions
   - Check that you're authenticated: `gcloud auth application-default login`

2. **Database Connection Issues**
   - Verify the `planwithhands` database exists and is accessible
   - Check firebase_config.js for correct database settings

3. **Memory Issues with Large Organizations**
   - The system processes organizations sequentially to manage memory
   - For very large datasets, consider running validation per organization

### Debug Mode
Add debugging to any script:
```bash
DEBUG=* node validate_location_consistency.js
```

## 📝 Regular Maintenance

### Weekly Tasks
1. Review monitoring reports: `node monitoring_system.js history 7`
2. Check for any new alert patterns
3. Verify scheduled monitoring is running

### Monthly Tasks
1. Review prevention utility integration in application code
2. Update alert thresholds if needed
3. Clean up old monitoring data (automatic, but verify)

### After App Updates
1. Test validation system still works: `node validate_location_consistency.js`
2. Verify prevention utilities are still integrated correctly
3. Check that new features don't bypass validation

## 🎯 Success Metrics

Monitor these metrics to ensure the system is working:

- **Zero High Severity Issues**: Target for all validation runs
- **Consistent Check Schedule**: Monitoring runs as scheduled
- **Fast Issue Detection**: Issues caught within 24 hours of occurrence
- **Prevention Success**: No new cross-location assignments created

## 📞 Support

If issues persist:
1. Check the monitoring logs: `node monitoring_system.js history`
2. Run manual validation: `node validate_location_consistency.js`
3. Review recent application changes that might affect location assignments
4. Contact the development team with specific error messages and organization IDs