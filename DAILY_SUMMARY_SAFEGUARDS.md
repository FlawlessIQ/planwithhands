# Daily Summary System - Protective Safeguards

## Current Issues Identified

1. **Deployment Disruptions**: Function redeployments can interrupt Cloud Scheduler
2. **Time Change Confusion**: Changing time to earlier than current time won't send until tomorrow
3. **No Change Validation**: Users can change time multiple times causing missed summaries
4. **No Retry Mechanism**: Failed sends are just lost
5. **Limited Visibility**: Hard to know why a summary didn't send

## Recommended Safeguards

### 1. ⚠️ Time Change Validation & Rate Limiting

**Problem**: Users can change the time multiple times, and changes to past times won't take effect.

**Solution**:
```typescript
// In the organization settings update endpoint
interface TimeChangeValidation {
  // Prevent more than 1 change per day
  lastTimeChange?: Timestamp;
  changeCount?: number;
}

async function validateTimeChange(
  orgId: string,
  newTime: string,
  timezone: string
): Promise<{ allowed: boolean; warning?: string; action?: string }> {
  
  // Check last change
  const org = await getOrganization(orgId);
  const lastChange = org.dailySummaryLastChange?.toDate();
  const now = new Date();
  
  // Rate limiting: Only allow 1 change per day
  if (lastChange) {
    const hoursSinceChange = (now.getTime() - lastChange.getTime()) / (1000 * 60 * 60);
    if (hoursSinceChange < 24) {
      return {
        allowed: false,
        warning: `Time can only be changed once per day. Last changed ${Math.floor(hoursSinceChange)}h ago.`,
      };
    }
  }
  
  // Check if new time has already passed today
  const { DateTime } = require('luxon');
  const [hours, minutes] = newTime.split(':').map(Number);
  const localNow = DateTime.now().setZone(timezone);
  const targetTime = DateTime.fromObject(
    { hour: hours, minute: minutes },
    { zone: timezone }
  );
  
  if (targetTime.hour < localNow.hour || 
     (targetTime.hour === localNow.hour && targetTime.minute < localNow.minute)) {
    return {
      allowed: true,
      warning: `⚠️ The time ${newTime} has already passed today. Summary will be sent tomorrow at this time.`,
      action: 'Would you like to send today\'s summary immediately?',
    };
  }
  
  return { allowed: true };
}
```

### 2. 🔄 Retry Mechanism

**Problem**: If the hourly execution misses a summary, it's never retried.

**Solution**:
```typescript
// Add to scheduledDailySummary function
async function checkForMissedSummaries() {
  const now = new Date();
  const todayStr = now.toISOString().split('T')[0];
  
  // Check all enabled orgs
  const orgsSnapshot = await db.collection('organizations')
    .where('dailySummaryEnabled', '==', true)
    .get();
  
  for (const orgDoc of orgsSnapshot.docs) {
    const org = orgDoc.data();
    
    // Check if summary should have been sent today but wasn't
    const { shouldHaveSent, hoursPastDue } = await checkIfOverdue(org, todayStr);
    
    if (shouldHaveSent && hoursPastDue > 0 && hoursPastDue < 6) {
      // Retry if less than 6 hours past due
      console.log(`🔄 RETRY: Sending overdue summary for ${org.name}`);
      await sendDailySummary(orgDoc.id, org);
    }
  }
}
```

### 3. 🚨 Better Error Logging & Alerts

**Problem**: Silent failures make debugging difficult.

**Solution**:
```typescript
// Add structured error logging
interface SummaryAttemptLog {
  organizationId: string;
  attemptTime: Timestamp;
  targetTime: string;
  success: boolean;
  error?: string;
  reason?: 'time_mismatch' | 'no_data' | 'send_failed' | 'disabled';
}

// Log every org check
async function logSummaryAttempt(log: SummaryAttemptLog) {
  await db.collection('daily_summary_attempts').add({
    ...log,
    timestamp: FieldValue.serverTimestamp(),
  });
}

// Alert on failures
if (!success && org.alertOnFailure) {
  await sendAlertEmail(org.ownerEmail, {
    subject: 'Daily Summary Failed',
    body: `Summary failed to send at ${targetTime}. Reason: ${reason}`,
  });
}
```

### 4. ⏱️ Time Window Restrictions

**Problem**: Unrestricted times can cause issues (e.g., 3 AM when no one is awake).

**Solution**:
```typescript
// Restrict to business hours
function validateBusinessHours(time: string): { valid: boolean; message?: string } {
  const [hours] = time.split(':').map(Number);
  
  // Only allow 6 AM - 11 PM
  if (hours < 6 || hours >= 23) {
    return {
      valid: false,
      message: 'Summary time must be between 6:00 AM and 11:00 PM',
    };
  }
  
  return { valid: true };
}
```

### 5. 🎯 Immediate Send Option

**Problem**: Changing time to earlier than current doesn't help for today.

**Solution**: Add UI button and backend function:
```typescript
// New Cloud Function
export const sendTodaySummaryNow = onCall(async (request) => {
  const { organizationId } = request.data;
  
  // Verify user is admin
  if (!await isAdmin(request.auth.uid, organizationId)) {
    throw new Error('Unauthorized');
  }
  
  // Check if already sent today
  const todayStr = new Date().toISOString().split('T')[0];
  const alreadySent = await checkIfSent(organizationId, todayStr);
  
  if (alreadySent) {
    throw new Error('Summary already sent today');
  }
  
  // Send immediately
  await triggerDailySummary({ data: { organizationId } });
  
  return { success: true, message: 'Summary sent immediately' };
});
```

### 6. 📊 Summary Status Dashboard

**Problem**: No visibility into what's happening with summaries.

**Solution**: Add to UI:
```typescript
interface SummaryStatus {
  lastSent: Date;
  nextScheduled: Date;
  missedDays: number;
  recentFailures: string[];
  schedulerHealth: 'healthy' | 'warning' | 'error';
}

// Real-time status check
async function getSummaryStatus(orgId: string): Promise<SummaryStatus> {
  // Check last sent
  const lastLog = await getLastSummaryLog(orgId);
  
  // Calculate next scheduled
  const org = await getOrganization(orgId);
  const nextScheduled = calculateNextSend(org.dailySummaryTime, org.timezone);
  
  // Count missed days in last 7 days
  const missedDays = await countMissedDays(orgId, 7);
  
  // Check recent failures
  const failures = await getRecentFailures(orgId, 3);
  
  return { lastSent, nextScheduled, missedDays, recentFailures, schedulerHealth };
}
```

### 7. 🔐 Change Confirmation

**Problem**: Accidental changes can disrupt schedules.

**Solution**:
```typescript
// Require confirmation for time changes
interface TimeChangeConfirmation {
  oldTime: string;
  newTime: string;
  impact: string;
  requiresPassword?: boolean;
}

// Show impact before confirming
function calculateImpact(oldTime: string, newTime: string): string {
  const hourDiff = calculateHourDifference(oldTime, newTime);
  
  if (hourDiff > 0) {
    return `⚠️ Summary will now be sent ${hourDiff} hours LATER each day.`;
  } else if (hourDiff < 0) {
    return `⚠️ Summary will now be sent ${Math.abs(hourDiff)} hours EARLIER each day. Today's summary will be sent tomorrow.`;
  }
  
  return 'Minute adjustment only.';
}
```

## Implementation Priority

### Phase 1 (Immediate - High Impact)
1. ✅ **Time change validation** - Prevent confusion
2. ✅ **Warning for past times** - Inform users
3. ✅ **Immediate send option** - Fix today's summary

### Phase 2 (Near Term - Reliability)
4. 🔄 **Retry mechanism** - Catch missed summaries
5. 📊 **Better logging** - Debug issues
6. 🚨 **Failure alerts** - Proactive monitoring

### Phase 3 (Long Term - UX)
7. ⏱️ **Time restrictions** - Prevent bad configs
8. 🎯 **Status dashboard** - Visibility
9. 🔐 **Change confirmation** - Prevent accidents

## Recommended Limits

```typescript
const DAILY_SUMMARY_LIMITS = {
  // Rate limiting
  MAX_TIME_CHANGES_PER_DAY: 1,
  MIN_HOURS_BETWEEN_CHANGES: 24,
  
  // Time windows
  EARLIEST_SEND_HOUR: 6,   // 6 AM
  LATEST_SEND_HOUR: 23,    // 11 PM
  
  // Retry behavior
  RETRY_WINDOW_HOURS: 6,    // Retry if less than 6 hours late
  MAX_RETRY_ATTEMPTS: 3,
  
  // Data requirements
  MIN_CHECKLISTS_FOR_SEND: 1,  // Don't send if no data
  
  // Validation
  REQUIRE_CONFIRMATION_FOR_CHANGES: true,
  REQUIRE_PASSWORD_FOR_MAJOR_CHANGES: false,
};
```

## Testing Strategy

1. **Time Change Tests**:
   - Change to past time → Show warning
   - Change to future time → Confirm next send
   - Change twice in 24h → Block second change

2. **Retry Tests**:
   - Simulate missed send → Verify retry
   - Multiple failures → Verify alert

3. **Validation Tests**:
   - Set time to 3 AM → Reject
   - Set time to 8 AM → Accept
   - Invalid format → Show error

## Monitoring & Alerts

```typescript
// Daily health check
export const dailySummaryHealthCheck = onSchedule('0 23 * * *', async () => {
  const orgs = await getEnabledOrganizations();
  const issues = [];
  
  for (const org of orgs) {
    const status = await getSummaryStatus(org.id);
    
    if (status.missedDays > 1) {
      issues.push({
        org: org.name,
        issue: `Missed ${status.missedDays} days`,
        action: 'Check scheduler and logs',
      });
    }
  }
  
  if (issues.length > 0) {
    await sendAdminAlert('Daily Summary Health Issues', issues);
  }
});
```
