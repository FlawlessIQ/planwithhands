# Location Breakdown Feature - October 15, 2025

## What Was Added

Added **per-location performance breakdown** to daily summary emails and notifications, showing completion rates for each location based on **today's tasks only** (excluding carry-forward tasks).

## Why This Matters

Previously, the summary only showed overall organization performance. Now managers can see:
- Which locations are performing well
- Which locations need attention
- Performance comparisons across locations

## What's Included

### In-App Notification
Shows location breakdown with emoji indicators:
```
📍 Performance by Location:
✅ Lakeside BBQ: 30% (14/46)
⚠️ Downtown tap: 65% (13/20)
✅ Northside Grill: 92% (23/25)
```

### Email
Beautiful HTML table showing:
- Location name
- Completion percentage
- Task counts (completed/total)
- Color-coded indicators (green/yellow/red)

## Technical Details

### What Gets Counted

**ONLY regular tasks scheduled for today** - carry-forward tasks are explicitly excluded from location performance metrics.

For each location:
- `totalRegular`: Tasks scheduled for today (not carry-forward)
- `completedRegular`: Today's tasks that were completed
- `incompletedRegular`: Today's tasks that are incomplete
- `completionPercentage`: (completed / total) * 100
- `totalCarryForward`: Tracked separately for context but not used in percentage

### Why Exclude Carry-Forward?

Carry-forward tasks are from previous days. Including them would:
- ❌ Make today's performance look artificially bad
- ❌ Punish locations for yesterday's issues
- ❌ Make comparisons unfair

By excluding them:
- ✅ Shows true daily performance
- ✅ Fair comparison between locations
- ✅ Clear actionable insights

### Example Calculation

**Lakeside BBQ on Oct 14:**
- Regular tasks: 46 (scheduled for Oct 14)
  - Completed: 14
  - Incomplete: 32
- Carry-forward tasks: 37 (from previous days)
  - Not counted in performance

**Completion Rate**: 14/46 = 30% ✅ (accurate)  
**NOT**: 14/83 = 17% ❌ (misleading if carry-forward included)

## What the Email Shows

### Location Breakdown Table
```
📍 Performance by Location (Today's Tasks Only)
─────────────────────────────────────────────
✅ Lakeside BBQ        30%  (14/46)
⚠️  Downtown tap       65%  (13/20)  
✅ Northside Grill     92%  (23/25)
```

### Color Indicators
- 🟢 **90%+**: Green - Excellent performance
- 🟡 **70-89%**: Yellow - Good, needs minor attention
- 🔴 **<70%**: Red - Requires immediate attention

## Code Changes

### Files Modified
- `/functions/src/scheduledDailySummary.ts`

### Key Changes

1. **Added location stats tracking**:
```typescript
const locationStats: Record<string, {
  locationName: string;
  totalRegular: number;
  completedRegular: number;
  incompletedRegular: number;
  totalCarryForward: number;
}> = {};
```

2. **Updated task counting**:
```typescript
if (isCarryForward) {
  carryForwardTasks++;
  locationStats[locationId].totalCarryForward++;
} else {
  // Only count non-carry-forward tasks for location performance
  locationStats[locationId].totalRegular++;
  if (isCompleted) {
    locationStats[locationId].completedRegular++;
  } else {
    locationStats[locationId].incompletedRegular++;
  }
}
```

3. **Added to summary data**:
```typescript
locationBreakdown: Object.values(locationStats).map(loc => ({
  locationName: loc.locationName,
  totalRegular: loc.totalRegular,
  completedRegular: loc.completedRegular,
  incompletedRegular: loc.incompletedRegular,
  completionPercentage: loc.totalRegular > 0 ? (loc.completedRegular / loc.totalRegular * 100) : 0,
  totalCarryForward: loc.totalCarryForward,
}))
```

4. **Added to notification content**:
```typescript
if (locationBreakdown && locationBreakdown.length > 0) {
  content += `📍 Performance by Location:\n`;
  for (const loc of locationBreakdown) {
    const emoji = loc.completionPercentage >= 90 ? '✅' : loc.completionPercentage >= 70 ? '⚠️' : '❌';
    content += `${emoji} ${loc.locationName}: ${Math.round(loc.completionPercentage)}% (${loc.completedRegular}/${loc.totalRegular})\n`;
  }
  content += `\n`;
}
```

5. **Added to email HTML**:
```typescript
locationBreakdownHtml = '<table style="width:100%; border-collapse:collapse; margin-top:8px;">';
// ... HTML table generation ...
```

## Deployment

```bash
cd functions
firebase deploy --only functions:scheduledDailySummary
```

**Status**: ✅ Deployed October 15, 2025

## Testing

### Expected Results for Tomorrow (Oct 16)

The daily summary will include a location breakdown section showing:
1. Each location that had tasks scheduled
2. Completion percentage for each location
3. Task counts (completed/total) for each location
4. Visual indicators (✅/⚠️/❌) based on performance

### What Won't Be Included
- Locations with zero tasks scheduled for that day
- Carry-forward task counts in the percentage calculation
- Locations that only have carry-forward tasks (no regular tasks)

## Benefits

### For Managers
- **Quick identification** of problem locations
- **Fair comparisons** between locations
- **Actionable insights** for where to focus attention

### For Operations
- **Performance tracking** by location over time
- **Trend identification** for specific locations
- **Resource allocation** decisions based on data

### For Staff
- **Recognition** when locations perform well
- **Accountability** for location performance
- **Clear expectations** with measurable metrics

## Future Enhancements (Potential)

1. **Trend tracking**: Show location performance over time (7-day average)
2. **Shift breakdown**: Break down by shift within each location
3. **Top/Bottom performers**: Highlight best and worst locations
4. **Alerts**: Auto-flag locations consistently below threshold
5. **Historical comparison**: Compare to same day last week/month

## Success Metrics

The feature is working correctly if:
- ✅ Location breakdown appears in both email and notification
- ✅ Percentages are based on regular tasks only (not carry-forward)
- ✅ Locations with no regular tasks are excluded
- ✅ Task counts add up correctly per location
- ✅ Visual indicators match performance levels

---

**Added**: October 15, 2025  
**Deployed**: October 15, 2025  
**Next Summary**: October 16, 2025 at 2 AM Pacific  
**Status**: ✅ Active
