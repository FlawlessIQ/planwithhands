# FIREBASE INFINITE LOOP INCIDENT REPORT
## September 10, 2025

### INCIDENT SUMMARY
- **Time**: ~2-3 hours on September 10, 2025
- **Cause**: Infinite loop in onGeneralNotificationCreated Firebase Function
- **Impact**: ~145 million database operations, ~$200 unexpected charges

### ROOT CAUSE ANALYSIS
**The Bug:**
```typescript
// PROBLEMATIC CODE - Function triggered by:
.document("organizations/{orgId}/notifications/{notifId}")

// But then wrote to THE SAME COLLECTION:
.collection("organizations")
.doc(orgId)
.collection("notifications")  // ← SAME PATH!
```

**Why it happened:**
- Function listened to `organizations/{orgId}/notifications/{notifId}`
- Function created new docs in `organizations/{orgId}/notifications/`
- Each new document triggered the function again → infinite loop

### IMMEDIATE ACTIONS TAKEN
1. **Detected issue** when push notifications stopped working and saw Firebase console deleting massive numbers
2. **Deleted the function** using `firebase functions:delete onGeneralNotificationCreated`
3. **Fixed the code** to write to `userNotifications` collection instead
4. **Attempted cleanup** using Firebase CLI and custom scripts
5. **Downgraded to Spark plan** to prevent further charges
6. **Contacted Firebase Support** for billing assistance

### CURRENT STATUS
- ✅ Infinite loop STOPPED (function deleted)
- ✅ Code FIXED (writes to different collection)
- ⚠️ Cleanup may be incomplete due to quota limits
- ⚠️ On Spark plan with limited quotas
- ⏳ Awaiting Firebase Support response

### PREVENTION MEASURES
1. **Code review** - Always check if function writes to same collection it monitors
2. **Testing isolation** - Test functions with minimal data first
3. **Monitoring** - Set up alerts for unusual quota usage
4. **Quota limits** - Consider setting billing alerts

### LESSONS LEARNED
- Firestore triggers can create infinite loops if not carefully designed
- Firebase billing can escalate extremely quickly with runaway processes
- Firebase CLI deletion is more efficient than custom scripts for mass cleanup
- Having a separate test environment would have prevented this

### FILES AFFECTED
- `functions/src/messagingNotifications.ts` - Fixed infinite loop
- `functions/src/index.ts` - Disabled problematic function export
- Database: Millions of duplicate notifications created (cleanup needed)
