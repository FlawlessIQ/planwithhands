"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.triggerDailySummary = exports.scheduledDailySummary = void 0;
exports.generateAndSendDailySummary = generateAndSendDailySummary;
exports.hasDailySummaryBeenSent = hasDailySummaryBeenSent;
exports.markDailySummaryAsSent = markDailySummaryAsSent;
exports.formatDate = formatDate;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const luxon_1 = require("luxon");
const firestoreTTLHelper_1 = require("./firestoreTTLHelper");
const firestore_1 = require("@google-cloud/firestore");
// Ensure we use the correct Firestore database
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
if (!admin.apps.length) {
    admin.initializeApp();
}
/**
 * Scheduled function that runs hourly to check if any organizations need daily summaries
 * Supports flexible user-defined times instead of hardcoded scheduling
 * Runs every hour at minute 0 (e.g., 1:00, 2:00, 3:00, etc.)
 */
exports.scheduledDailySummary = functions.pubsub
    .schedule("0 * * * *") // Every hour at minute 0
    .timeZone("UTC")
    .onRun(async () => {
    const currentUTCHour = new Date().getUTCHours();
    functions.logger.info(`Starting hourly daily summary check at ${currentUTCHour}:00 UTC`);
    let summariesSent = 0;
    let errors = 0;
    let organizationsChecked = 0;
    try {
        // Get all active organizations
        const orgsSnapshot = await db.collection("organizations").get();
        for (const orgDoc of orgsSnapshot.docs) {
            const orgId = orgDoc.id;
            const orgData = orgDoc.data();
            organizationsChecked++;
            try {
                functions.logger.info(`Checking daily summary schedule for organization: ${orgId}`);
                // Get organization timezone
                const orgTimezone = orgData.timezone || 'America/New_York';
                // Convert current UTC time to organization's timezone
                const nowInOrgTZ = luxon_1.DateTime.now().setZone(orgTimezone);
                // Calculate "yesterday" in the organization's timezone
                // When the summary runs at 4 AM on Oct 12, we want to summarize Oct 11
                const yesterdayInOrgTZ = nowInOrgTZ.minus({ days: 1 });
                const summaryDate = yesterdayInOrgTZ.toJSDate();
                const dateStr = formatDate(summaryDate);
                functions.logger.info(`Org ${orgId} timezone: ${orgTimezone}, current time: ${nowInOrgTZ.toISO()}, summary date: ${dateStr}`);
                // Check if summary already sent for this date
                const alreadySent = await hasDailySummaryBeenSent(orgId, dateStr);
                if (alreadySent) {
                    functions.logger.info(`Daily summary already sent for ${orgId} on ${dateStr}`);
                    continue;
                }
                // Check if this organization needs a summary sent at the current UTC hour
                const shouldSend = await shouldSendDailySummaryNow(orgId, orgData, currentUTCHour);
                if (!shouldSend) {
                    functions.logger.debug(`Not time for daily summary in org ${orgId} (current UTC hour: ${currentUTCHour})`);
                    continue;
                }
                functions.logger.info(`Sending daily summary for org ${orgId} at ${currentUTCHour}:00 UTC for date ${dateStr}`);
                // Generate and send daily summary for yesterday's date
                const sent = await generateAndSendDailySummary(orgId, summaryDate, orgData);
                if (!sent) {
                    functions.logger.info(`Daily summary not sent for org ${orgId} on ${dateStr} (skipped)`);
                    continue;
                }
                // Mark as sent
                await markDailySummaryAsSent(orgId, dateStr);
                summariesSent++;
                functions.logger.info(`Daily summary sent successfully for organization: ${orgId}`);
            }
            catch (error) {
                errors++;
                functions.logger.error(`Error processing daily summary for org ${orgId}:`, error);
            }
        }
        functions.logger.info(`Hourly daily summary check completed: ${organizationsChecked} orgs checked, ${summariesSent} summaries sent, ${errors} errors`);
    }
    catch (error) {
        functions.logger.error("Error in hourly daily summary check:", error);
    }
    return null;
});
/**
 * Manually trigger daily summary for a specific organization
 * Can be called via HTTP or from the app
 */
exports.triggerDailySummary = functions.https.onCall(async (data, context) => {
    const { orgId, targetDate } = data;
    if (!orgId) {
        throw new functions.https.HttpsError("invalid-argument", "Organization ID is required");
    }
    // Verify user has permission to trigger summary for this org
    if (context.auth?.uid) {
        const userDoc = await db.collection("users").doc(context.auth.uid).get();
        const userData = userDoc.data();
        if (userData?.organizationId !== orgId || userData?.userRole < 1) {
            throw new functions.https.HttpsError("permission-denied", "Insufficient permissions");
        }
    }
    try {
        const date = targetDate ? new Date(targetDate) : new Date();
        const orgDoc = await db.collection("organizations").doc(orgId).get();
        const orgData = orgDoc.exists ? orgDoc.data() : {};
        const sent = await generateAndSendDailySummary(orgId, date, orgData);
        if (!sent) {
            return { success: true, message: "Daily summary skipped (no activity or no recipients)" };
        }
        functions.logger.info(`Manual daily summary triggered for org ${orgId}`);
        return { success: true, message: "Daily summary sent successfully" };
    }
    catch (error) {
        functions.logger.error(`Error in manual daily summary trigger for org ${orgId}:`, error);
        throw new functions.https.HttpsError("internal", "Failed to generate daily summary");
    }
});
/**
 * Generate and send daily summary for an organization
 */
async function generateAndSendDailySummary(orgId, date, orgData) {
    const dateStr = formatDate(date);
    functions.logger.info(`Generating daily summary for org ${orgId}, date: ${dateStr}`);
    // Collect summary data
    const summaryData = await collectDailySummaryData(orgId, date, orgData);
    // Also collect yesterday's data for deltas/trends
    const yesterday = new Date(date);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayData = await collectDailySummaryData(orgId, yesterday, orgData);
    // Check if there's meaningful content
    const hasContent = summaryData.totalTasks > 0 ||
        summaryData.notesEntries.length > 0 ||
        summaryData.missedTaskEntries.length > 0 ||
        summaryData.photoBypassed.length > 0;
    if (!hasContent) {
        functions.logger.info(`No meaningful activity for ${orgId} on ${dateStr} - skipping summary`);
        return false;
    }
    // Get admin users
    const adminUsers = await getAdminUsers(orgId);
    if (adminUsers.length === 0) {
        functions.logger.warn(`No admin users found for organization ${orgId}`);
        return false;
    }
    // Generate notification content for in-app notifications
    const title = `Daily Summary - ${formatDateReadable(date)}`;
    const message = buildNotificationContent(summaryData, date);
    // Send in-app notification using the outbox system
    await sendNotificationToAdmins(orgId, title, message, adminUsers);
    // Send SendGrid email to admin users
    // Build enhanced HTML sections (tables, top/bottom lists, deltas)
    const enhancedSections = buildEnhancedHtmlSections(summaryData, yesterdayData);
    await sendDailySummaryEmails(orgId, orgData, summaryData, date, adminUsers, enhancedSections);
    functions.logger.info(`Daily summary sent to ${adminUsers.length} admin(s) for org ${orgId} (both in-app and email)`);
    return true;
}
/**
 * Collect comprehensive daily summary data
 * Supports both calendar-day (6am-6am) and business-day (close-to-close) periods
 */
async function collectDailySummaryData(orgId, date, orgData) {
    const notesEntries = [];
    const missedTaskEntries = [];
    const photoBypassed = [];
    let totalTasks = 0;
    let completedTasks = 0;
    let carryForwardTasks = 0;
    // NEW: Track per-location statistics (excluding carry-forward tasks)
    const locationStats = {};
    try {
        // Get summary period setting (default to calendar-day for backward compatibility)
        const dailySummarySettings = orgData?.dailySummarySettings || {};
        const summaryPeriod = dailySummarySettings.summaryPeriod || 'calendar-day';
        functions.logger.info(`Collecting daily summary data for org ${orgId}, period: ${summaryPeriod}`);
        // Determine the date range based on summary period
        let dateQueries = [];
        if (summaryPeriod === 'business-day') {
            // Business day: include tasks from yesterday evening through today evening
            // This covers shifts that run late (e.g., bar closing at 2 AM)
            const yesterday = new Date(date);
            yesterday.setDate(yesterday.getDate() - 1);
            const yesterdayStr = formatDate(yesterday);
            const todayStr = formatDate(date);
            dateQueries = [yesterdayStr, todayStr];
            functions.logger.info(`Business day mode: querying dates ${yesterdayStr} and ${todayStr}`);
        }
        else {
            // Calendar day: standard 6am-6am approach (single date)
            const dateStr = formatDate(date);
            dateQueries = [dateStr];
            functions.logger.info(`Calendar day mode: querying date ${dateStr}`);
        }
        // Get all locations for the organization
        const locationsSnapshot = await db
            .collection("organizations")
            .doc(orgId)
            .collection("locations")
            .get();
        // Get shift names and user names for reference
        const [shiftNames, userNames] = await Promise.all([
            getShiftNames(orgId),
            getUserNames(orgId)
        ]);
        for (const locationDoc of locationsSnapshot.docs) {
            const locationId = locationDoc.id;
            const locationData = locationDoc.data();
            const locationName = locationData.locationName || "Unknown Location";
            // Initialize location stats
            if (!locationStats[locationId]) {
                locationStats[locationId] = {
                    locationName,
                    totalRegular: 0,
                    completedRegular: 0,
                    incompletedRegular: 0,
                    totalCarryForward: 0,
                };
            }
            // Query daily checklists for this location across all relevant dates
            for (const queryDate of dateQueries) {
                const checklistsSnapshot = await db
                    .collection("organizations")
                    .doc(orgId)
                    .collection("locations")
                    .doc(locationId)
                    .collection("daily_checklists")
                    .where("date", "==", queryDate)
                    .get();
                for (const checklistDoc of checklistsSnapshot.docs) {
                    const checklistData = checklistDoc.data();
                    const shiftId = checklistData.shiftId || "unknown";
                    const shiftName = shiftNames[shiftId] || "Unknown Shift";
                    const templateName = checklistData.templateName || "Unknown Checklist";
                    // For business-day mode, filter tasks by time if needed
                    const shouldIncludeChecklist = shouldIncludeChecklistInSummary(checklistData, summaryPeriod, date, queryDate);
                    if (!shouldIncludeChecklist) {
                        continue;
                    }
                    // PRIORITY 2 FIX: Process tasks from subcollection ONLY
                    // Legacy array is deprecated and can cause double-counting
                    // All task data should now be in the subcollection
                    const tasksSnapshot = await checklistDoc.ref.collection("tasks").get();
                    if (tasksSnapshot.empty) {
                        functions.logger.warn(`No tasks found in subcollection for checklist ${checklistDoc.id} - may need migration`);
                    }
                    for (const taskDoc of tasksSnapshot.docs) {
                        const taskData = taskDoc.data();
                        await processTaskForSummary({
                            taskData,
                            shiftName,
                            templateName,
                            locationName,
                            userNames,
                            notesEntries,
                            missedTaskEntries,
                            photoBypassed
                        });
                        totalTasks++;
                        const isCompleted = taskData.completed || taskData.isCompleted || false;
                        const isCarryForward = taskData.isCarryForward || false;
                        if (isCarryForward) {
                            carryForwardTasks++;
                            locationStats[locationId].totalCarryForward++;
                        }
                        else {
                            // Only count non-carry-forward tasks for location performance
                            locationStats[locationId].totalRegular++;
                            if (isCompleted) {
                                locationStats[locationId].completedRegular++;
                            }
                            else {
                                locationStats[locationId].incompletedRegular++;
                            }
                        }
                        // CRITICAL FIX: Only count completed tasks that were scheduled for today (not carry-forward)
                        if (isCompleted && !isCarryForward) {
                            completedTasks++;
                        }
                    }
                }
            }
        }
        // CRITICAL FIX: Calculate metrics excluding carry-forward tasks
        // Carry-forward tasks are from previous days and shouldn't affect today's performance metrics
        const tasksScheduledForToday = totalTasks - carryForwardTasks;
        const overallPercentage = tasksScheduledForToday > 0 ? (completedTasks / tasksScheduledForToday * 100) : 0;
        // CRITICAL FIX: Calculate incomplete from missed array length for consistency
        // This ensures the "incomplete" count matches what's actually shown in the missed tasks list
        const incompleteTasks = missedTaskEntries.length;
        functions.logger.info(`Summary data collected for org ${orgId}, date ${formatDate(date)}: ${totalTasks} total tasks (${carryForwardTasks} carry-forward), ${tasksScheduledForToday} scheduled for today, ${completedTasks} completed, ${incompleteTasks} incomplete (${Math.round(overallPercentage)}%)`);
        if (tasksScheduledForToday === 0) {
            functions.logger.warn(`No tasks scheduled for today for org ${orgId} on date ${formatDate(date)} - verify date calculation and checklist existence`);
        }
        // Convert locationStats to array and calculate percentages
        const locationBreakdown = Object.values(locationStats).map(loc => ({
            locationName: loc.locationName,
            totalRegular: loc.totalRegular,
            completedRegular: loc.completedRegular,
            incompletedRegular: loc.incompletedRegular,
            completionPercentage: loc.totalRegular > 0 ? (loc.completedRegular / loc.totalRegular * 100) : 0,
            totalCarryForward: loc.totalCarryForward,
        })).filter(loc => loc.totalRegular > 0); // Only include locations with regular tasks
        return {
            notesEntries,
            missedTaskEntries,
            photoBypassed,
            totalTasks,
            completedTasks,
            incompleteTasks, // NEW: Explicit incomplete count from array
            overallPercentage,
            summaryPeriod,
            carryForwardTasks, // NEW: Track carry-forward tasks separately
            tasksScheduledForToday, // NEW: Tasks actually scheduled for today
            locationBreakdown, // NEW: Per-location performance breakdown
        };
    }
    catch (error) {
        functions.logger.error("Error collecting daily summary data:", error);
        return {
            notesEntries: [],
            missedTaskEntries: [],
            photoBypassed: [],
            totalTasks: 0,
            completedTasks: 0,
            incompleteTasks: 0, // NEW: Explicit incomplete count
            overallPercentage: 0,
            summaryPeriod: 'calendar-day',
            carryForwardTasks: 0, // NEW: Track carry-forward tasks separately
            tasksScheduledForToday: 0, // NEW: Tasks actually scheduled for today
            locationBreakdown: [], // NEW: Per-location performance breakdown
        };
    }
}
/**
 * Determine if a checklist should be included in the summary based on period and timing
 * PRIORITY 2 FIX: Improved business-day filtering logic
 */
function shouldIncludeChecklistInSummary(checklistData, summaryPeriod, targetDate, queryDate) {
    // Always include for calendar-day mode
    if (summaryPeriod === 'calendar-day') {
        return true;
    }
    // PRIORITY 2 FIX: For business-day mode, only include checklists from the target date
    // The business day represents "close to close", which means we want tasks from
    // the calendar day itself. The query already includes yesterday and today for context,
    // but we should primarily focus on the target date's tasks.
    // 
    // NOTE: If you need to capture late-night shifts that span dates (e.g., bar closing at 2am),
    // implement shift-time-based filtering here using checklistData.shiftStartTime/shiftEndTime
    const checklistDate = checklistData.date;
    const targetDateStr = formatDateForComparison(targetDate);
    // Only include if the checklist is for the target date
    return checklistDate === targetDateStr;
}
function formatDateForComparison(date) {
    return date.getFullYear() + '-' +
        String(date.getMonth() + 1).padStart(2, '0') + '-' +
        String(date.getDate()).padStart(2, '0');
}
/**
 * Process a single task for summary data collection
 */
async function processTaskForSummary(params) {
    const { taskData, shiftName, templateName, locationName, userNames, notesEntries, missedTaskEntries, photoBypassed } = params;
    const taskName = taskData.taskName || taskData.description || taskData.title || taskData.name || "Unknown Task";
    const isCompleted = taskData.completed || taskData.isCompleted || false;
    const isCarryForward = taskData.isCarryForward || false;
    // FIX: Consistent photo detection - check both photoRequired AND isCarryForwardEligible
    const photoRequired = taskData.photoRequired || taskData.isCarryForwardEligible || false;
    const hasPhoto = !!(taskData.proofImageUrl || taskData.photoUrl);
    // Check for task notes
    const notes = taskData.notes;
    if (notes && notes.trim()) {
        const userId = taskData.completedByUserId;
        const userName = userId ? (userNames[userId] || "Unknown User") : "Unknown User";
        notesEntries.push({
            taskName,
            shiftName,
            checklistName: templateName,
            locationName,
            userName,
            userId,
            notes,
            completedAt: taskData.completedAt
        });
    }
    // Check for not completed tasks - CRITICAL FIX: Exclude carry-forward tasks
    // Carry-forward tasks are incomplete by design (from yesterday) and shouldn't count as "missed" today
    // Only count tasks that were supposed to be completed today as "missed"
    if (!isCompleted && !isCarryForward) {
        const reason = taskData.reason || taskData.notCompletedReason;
        const hasReason = !!(reason && reason.trim());
        missedTaskEntries.push({
            taskName,
            shiftName,
            checklistName: templateName,
            locationName,
            reason: hasReason ? reason : 'No reason provided',
            hasReason: hasReason
        });
    }
    // Check for photo bypassed
    if (isCompleted && photoRequired && !hasPhoto) {
        const userId = taskData.completedByUserId;
        const userName = userId ? (userNames[userId] || "Unknown User") : "Unknown User";
        photoBypassed.push({
            taskName,
            shiftName,
            checklistName: templateName,
            locationName,
            userName,
            completedAt: taskData.completedAt
        });
    }
}
/**
 * Get admin users for an organization
 */
async function getAdminUsers(orgId) {
    try {
        const usersSnapshot = await db
            .collection("users")
            .where("organizationId", "==", orgId)
            .where("userRole", "in", [1, 2]) // Managers and admins
            .where("isActive", "==", true)
            .get();
        return usersSnapshot.docs.map(doc => ({
            userId: doc.id,
            firstName: doc.data().firstName || "",
            lastName: doc.data().lastName || "",
            email: doc.data().email || ""
        }));
    }
    catch (error) {
        functions.logger.error("Error getting admin users:", error);
        return [];
    }
}
/**
 * Get shift names map
 */
async function getShiftNames(orgId) {
    try {
        const shiftsSnapshot = await db
            .collection("organizations")
            .doc(orgId)
            .collection("shifts")
            .get();
        const shiftNames = {};
        for (const doc of shiftsSnapshot.docs) {
            const data = doc.data();
            shiftNames[doc.id] = data.shiftName || "Unknown Shift";
        }
        return shiftNames;
    }
    catch (error) {
        functions.logger.error("Error getting shift names:", error);
        return {};
    }
}
/**
 * Get user names map
 */
async function getUserNames(orgId) {
    try {
        const usersSnapshot = await db
            .collection("users")
            .where("organizationId", "==", orgId)
            .get();
        const userNames = {};
        for (const doc of usersSnapshot.docs) {
            const data = doc.data();
            const firstName = data.firstName || "";
            const lastName = data.lastName || "";
            userNames[doc.id] = `${firstName} ${lastName}`.trim();
        }
        return userNames;
    }
    catch (error) {
        functions.logger.error("Error getting user names:", error);
        return {};
    }
}
/**
 * Check if an organization should receive their daily summary at the current UTC hour
 * This supports flexible user-defined times instead of hardcoded scheduling
 */
async function shouldSendDailySummaryNow(orgId, orgData, currentUTCHour) {
    try {
        // Check if daily summary is enabled
        const dailySummarySettings = orgData?.dailySummarySettings;
        if (!dailySummarySettings) {
            functions.logger.debug(`Daily summary disabled for org ${orgId} (no dailySummarySettings)`);
            return false;
        }
        if (dailySummarySettings.enabled === false) {
            functions.logger.debug(`Daily summary disabled for org ${orgId} (enabled=false)`);
            return false;
        }
        // Get the configured time (default to 17:00 if not set)
        const targetHour = dailySummarySettings.hour ?? 17;
        const targetMinute = dailySummarySettings.minute ?? 0;
        // Get organization timezone (default to America/New_York if not set)
        const orgTimezone = orgData.timezone || "America/New_York";
        // Convert the organization's target time to UTC
        const orgLocalTime = luxon_1.DateTime.now().setZone(orgTimezone).set({
            hour: targetHour,
            minute: targetMinute,
            second: 0,
            millisecond: 0
        });
        const targetUTCTime = orgLocalTime.toUTC();
        const targetUTCHour = targetUTCTime.hour;
        const targetUTCMinute = targetUTCTime.minute;
        functions.logger.info(`Checking daily summary time for org ${orgId}: target=${targetHour}:${targetMinute.toString().padStart(2, '0')} ${orgTimezone} = ${targetUTCHour}:${targetUTCMinute.toString().padStart(2, '0')} UTC, current=${currentUTCHour}:00 UTC`);
        // Check if we're at the right UTC hour
        const isTargetHour = currentUTCHour === targetUTCHour;
        // If it's the target hour, also check if we're past the target minute
        if (isTargetHour) {
            const currentUTCMinute = new Date().getUTCMinutes();
            const pastTargetMinute = currentUTCMinute >= targetUTCMinute;
            if (pastTargetMinute) {
                functions.logger.info(`Time match for org ${orgId}: sending daily summary at ${currentUTCHour}:${currentUTCMinute.toString().padStart(2, '0')} UTC`);
                return true;
            }
            else {
                functions.logger.debug(`Waiting for target minute for org ${orgId}: current=${currentUTCMinute}, target=${targetUTCMinute}`);
                return false;
            }
        }
        // Also check if we're in the next hour but the target was late in the previous hour
        // This handles cases where the target minute is late (e.g., 14:55) and we might miss it
        const isPreviousHour = currentUTCHour === (targetUTCHour + 1) % 24;
        if (isPreviousHour && targetUTCMinute >= 45) {
            const currentUTCMinute = new Date().getUTCMinutes();
            if (currentUTCMinute <= 15) { // Within 15 minutes of the next hour
                functions.logger.info(`Late catch for org ${orgId}: sending daily summary at ${currentUTCHour}:${currentUTCMinute.toString().padStart(2, '0')} UTC (target was ${targetUTCHour}:${targetUTCMinute})`);
                return true;
            }
        }
        functions.logger.debug(`Time mismatch for org ${orgId}: current UTC hour ${currentUTCHour}, target UTC hour ${targetUTCHour}`);
        return false;
    }
    catch (error) {
        functions.logger.error(`Error checking daily summary time for org ${orgId}:`, error);
        return false;
    }
}
/**
 * Legacy function - kept for manual triggers and backward compatibility
 * Check if daily summary should be sent for an organization based on their settings
 */
async function shouldSendDailySummary(orgId, orgData) {
    try {
        // Check if daily summary is enabled
        const dailySummarySettings = orgData?.dailySummarySettings;
        if (!dailySummarySettings) {
            functions.logger.info(`Daily summary disabled for org ${orgId} (no dailySummarySettings)`);
            return false;
        }
        if (dailySummarySettings.enabled === false) {
            functions.logger.info(`Daily summary disabled for org ${orgId} (enabled=false)`);
            return false;
        }
        // Get the configured time (default to 12:15 if not set)
        const targetHour = dailySummarySettings.hour ?? 12;
        const targetMinute = dailySummarySettings.minute ?? 15;
        // Get organization timezone (default to America/New_York if not set)
        const orgTimezone = orgData.timezone || "America/New_York";
        // Get current time in organization's timezone
        const orgLocalTime = luxon_1.DateTime.now().setZone(orgTimezone);
        const currentHour = orgLocalTime.hour;
        const currentMinute = orgLocalTime.minute;
        functions.logger.info(`Checking daily summary time for org ${orgId}: target=${targetHour}:${targetMinute.toString().padStart(2, '0')}, current=${currentHour}:${currentMinute.toString().padStart(2, '0')} (${orgTimezone})`);
        // Check if we're within 30 minutes of the target time
        const targetTimeMinutes = targetHour * 60 + targetMinute;
        const currentTimeMinutes = currentHour * 60 + currentMinute;
        const timeDifferenceMinutes = Math.abs(currentTimeMinutes - targetTimeMinutes);
        // Allow sending within 30 minutes before or after the target time
        const shouldSend = timeDifferenceMinutes <= 30;
        if (shouldSend) {
            functions.logger.info(`Time match for org ${orgId}: sending daily summary`);
        }
        else {
            functions.logger.info(`Time mismatch for org ${orgId}: difference is ${timeDifferenceMinutes} minutes`);
        }
        return shouldSend;
    }
    catch (error) {
        functions.logger.error(`Error checking daily summary time for org ${orgId}:`, error);
        return false;
    }
}
/**
 * Get organization timezones from locations
 */
async function getOrganizationTimezones(orgId) {
    try {
        const locationsSnapshot = await db
            .collection("organizations")
            .doc(orgId)
            .collection("locations")
            .get();
        const timezones = new Set();
        for (const doc of locationsSnapshot.docs) {
            const data = doc.data();
            const timezone = data.timezone;
            if (timezone) {
                timezones.add(timezone);
            }
        }
        // Default to UTC if no timezones found
        return timezones.size > 0 ? Array.from(timezones) : ["UTC"];
    }
    catch (error) {
        functions.logger.error("Error getting organization timezones:", error);
        return ["UTC"];
    }
}
/**
 * Send SendGrid emails to admin users for daily summary
 */
async function sendDailySummaryEmails(orgId, orgData, summaryData, date, adminUsers, enhancedSections) {
    try {
        // Get organization name
        const organizationName = orgData.organizationName || orgData.name || orgData.businessName || 'Your Organization';
        // Check if SendGrid is configured (dotenv env)
        const sendgridApiKey = process.env.SENDGRID_API_KEY || process.env.SENDGRID_KEY;
        if (!sendgridApiKey) {
            functions.logger.warn('SendGrid API key not configured (SENDGRID_API_KEY) - skipping email sending');
            return;
        }
        // SendGrid configuration
        const templateId = 'd-000519b45ca84c0882d31d2cb7965948';
        const fromEmail = process.env.SENDGRID_FROM_EMAIL || 'noreply@em5998.planwithhands.com';
        const fromName = process.env.SENDGRID_FROM_NAME || 'Hands App';
        const overallPercentage = summaryData.overallPercentage || 0;
        const completedTasks = summaryData.completedTasks || 0;
        const tasksScheduledForToday = summaryData.tasksScheduledForToday || summaryData.totalTasks || 0; // Fallback for backward compatibility
        const carryForwardTasks = summaryData.carryForwardTasks || 0;
        const summaryPeriod = summaryData.summaryPeriod || 'calendar-day';
        // Debug logging for email template data
        functions.logger.info(`Email template data debug: overallPercentage=${overallPercentage} (type: ${typeof overallPercentage}), completedTasks=${completedTasks}, tasksScheduledForToday=${tasksScheduledForToday}, carryForwardTasks=${carryForwardTasks}`);
        // Send email to each admin user using @sendgrid/mail for better error objects and consistency
        try {
            const sgMail = require('@sendgrid/mail');
            sgMail.setApiKey(sendgridApiKey);
            for (const admin of adminUsers) {
                if (!admin.email) {
                    functions.logger.warn(`Admin user ${admin.userId} has no email address`);
                    continue;
                }
                const subject = generateEmailSubject(organizationName, date, overallPercentage, summaryPeriod);
                // PRIORITY 2 FIX: Use explicit incomplete count from summaryData
                const incompleteTasks = summaryData.incompleteTasks || 0;
                // Build dynamic template data with both normalized (lower_snake_case) and legacy uppercase keys
                const normalizedTemplateData = {
                    organization_name: organizationName,
                    company_name: organizationName, // Alias for flexibility
                    formatted_date: formatDateForDisplay(date),
                    logo_url: 'http://cdn.mcauto-images-production.sendgrid.net/136c04a1809caad9/3116b67a-957a-419b-a46b-8abe59fc0856/1024x1024.png',
                    performance_emoji: getPerformanceEmoji(overallPercentage),
                    performance_message: getPerformanceMessage(overallPercentage, tasksScheduledForToday),
                    overall_percentage: overallPercentage.toFixed(0),
                    completed_tasks: completedTasks.toString(),
                    total_tasks: tasksScheduledForToday.toString(),
                    incomplete_tasks: incompleteTasks.toString(), // NEW: Explicit incomplete count
                    summary_period: summaryPeriod === 'business-day' ? ' (Business Day)' : '',
                    missed_tasks_count: summaryData.missedTaskEntries?.length || 0,
                    photo_bypassed_count: summaryData.photoBypassed?.length || 0,
                    notes_count: summaryData.notesEntries?.length || 0,
                    notable_items: generateNotableItemsForEmail(summaryData),
                    action_items: generateActionItemsForEmail(overallPercentage, summaryData),
                };
                // Also include the original uppercase keys to maximize compatibility with existing templates
                const templatePayload = Object.assign({}, normalizedTemplateData, {
                    ORGANIZATION_NAME: organizationName,
                    COMPANY_NAME: organizationName, // Alias for flexibility
                    FORMATTED_DATE: formatDateForDisplay(date),
                    LOGO_URL: 'http://cdn.mcauto-images-production.sendgrid.net/136c04a1809caad9/3116b67a-957a-419b-a46b-8abe59fc0856/1024x1024.png',
                    PERFORMANCE_EMOJI: getPerformanceEmoji(overallPercentage),
                    PERFORMANCE_MESSAGE: getPerformanceMessage(overallPercentage, tasksScheduledForToday),
                    OVERALL_PERCENTAGE: overallPercentage.toFixed(0),
                    COMPLETED_TASKS: completedTasks.toString(),
                    TOTAL_TASKS: tasksScheduledForToday.toString(),
                    INCOMPLETE_TASKS: incompleteTasks.toString(), // NEW: Explicit incomplete count
                    SUMMARY_PERIOD: summaryPeriod === 'business-day' ? ' (Business Day)' : '',
                    MISSED_TASKS_COUNT: summaryData.missedTaskEntries?.length || 0,
                    PHOTO_BYPASSED_COUNT: summaryData.photoBypassed?.length || 0,
                    NOTES_COUNT: summaryData.notesEntries?.length || 0,
                    NOTABLE_ITEMS: generateNotableItemsForEmail(summaryData),
                    ACTION_ITEMS: generateActionItemsForEmail(overallPercentage, summaryData),
                });
                // Add enhanced sections to both normalized and uppercase keys
                if (enhancedSections) {
                    templatePayload.overall_delta_html = enhancedSections.overallDeltaHtml;
                    templatePayload.missed_tasks_html = enhancedSections.missedTasksHtml;
                    templatePayload.staff_notes_html = enhancedSections.staffNotesHtml;
                    templatePayload.photo_compliance_html = enhancedSections.photoComplianceHtml;
                    templatePayload.key_metrics_html = enhancedSections.keyMetricsHtml;
                    templatePayload.location_breakdown_html = enhancedSections.locationBreakdownHtml;
                    templatePayload.OVERALL_DELTA_HTML = enhancedSections.overallDeltaHtml;
                    templatePayload.MISSED_TASKS_HTML = enhancedSections.missedTasksHtml;
                    templatePayload.STAFF_NOTES_HTML = enhancedSections.staffNotesHtml;
                    templatePayload.PHOTO_COMPLIANCE_HTML = enhancedSections.photoComplianceHtml;
                    templatePayload.KEY_METRICS_HTML = enhancedSections.keyMetricsHtml;
                    templatePayload.LOCATION_BREAKDOWN_HTML = enhancedSections.locationBreakdownHtml;
                }
                const msg = {
                    to: admin.email,
                    from: { email: fromEmail, name: fromName },
                    templateId: templateId,
                    subject: subject,
                    dynamicTemplateData: templatePayload,
                    categories: ['daily_summary'],
                    customArgs: {
                        email_type: 'daily_summary',
                        organization: organizationName,
                        date: formatDate(date),
                        summary_period: summaryPeriod,
                    },
                };
                // Log the template id and keys being sent (avoid logging large HTML blobs)
                functions.logger.info(`Sending daily summary email`, {
                    to: admin.email,
                    templateId: templateId,
                    dataKeys: Object.keys(templatePayload),
                });
                try {
                    const response = await sgMail.send(msg);
                    functions.logger.info(`SendGrid send response for ${admin.email}:`, Array.isArray(response) ? response[0].statusCode : response);
                }
                catch (sendErr) {
                    functions.logger.error(`SendGrid send error for ${admin.email}:`, sendErr?.message || sendErr);
                    if (sendErr && sendErr.response && sendErr.response.body) {
                        functions.logger.error('SendGrid response body:', sendErr.response.body);
                    }
                }
            }
        }
        catch (outerErr) {
            functions.logger.error('Error preparing SendGrid client or sending emails:', outerErr);
        }
    }
    catch (error) {
        functions.logger.error('Error in sendDailySummaryEmails:', error);
    }
}
/**
 * Helper functions for email generation
 */
function getPerformanceEmoji(percentage) {
    if (percentage >= 95)
        return '🎉';
    if (percentage >= 85)
        return '✅';
    if (percentage >= 70)
        return '👍';
    if (percentage >= 50)
        return '⚠️';
    return '🚨';
}
function getPerformanceMessage(percentage, totalTasks) {
    if (totalTasks === 0)
        return 'No tasks scheduled for this day.';
    if (percentage >= 95)
        return 'Outstanding work! Nearly perfect completion rate.';
    if (percentage >= 85)
        return 'Great job! Strong performance across all areas.';
    if (percentage >= 70)
        return 'Good progress! A few items need attention.';
    if (percentage >= 50)
        return 'Mixed results. Several areas need follow-up.';
    return 'Action needed! Many tasks require immediate attention.';
}
function generateEmailSubject(organizationName, date, percentage, summaryPeriod) {
    const formattedDate = formatDateForSubject(date);
    const emoji = getPerformanceEmoji(percentage);
    const periodText = summaryPeriod === 'business-day' ? ' (Business Day)' : '';
    return `${emoji} Daily Summary${periodText}: ${organizationName} - ${formattedDate} (${percentage.toFixed(0)}% Complete)`;
}
function generateNotableItemsForEmail(summaryData) {
    const items = [];
    const totalTasks = summaryData.totalTasks || 0;
    const completedTasks = summaryData.completedTasks || 0;
    // FIX: Use explicit incomplete count from summaryData instead of calculation
    const incompleteTasks = summaryData.incompleteTasks || 0;
    if (incompleteTasks > 0) {
        items.push(`❌ ${incompleteTasks} tasks not completed`);
        // Show breakdown if we have detailed info
        const missedWithReasons = summaryData.missedTaskEntries?.filter((t) => t.hasReason).length || 0;
        if (missedWithReasons > 0) {
            items.push(`📝 ${missedWithReasons} with explanations provided`);
        }
    }
    if (summaryData.photoBypassed?.length > 0) {
        items.push(`📷 ${summaryData.photoBypassed.length} photo requirements missed`);
    }
    if (summaryData.notesEntries?.length > 0) {
        items.push(`📝 ${summaryData.notesEntries.length} staff notes recorded`);
    }
    // ONLY say "all tasks completed" if actually 100% or no tasks exist
    if (totalTasks === 0) {
        return 'No tasks scheduled for this period';
    }
    else if (incompleteTasks === 0) {
        return 'All tasks completed successfully! 🎉';
    }
    return items.length > 0 ? items.join('<br>') : 'Task details not available';
}
function generateActionItemsForEmail(percentage, summaryData) {
    const actions = [];
    if (percentage >= 95) {
        actions.push('Keep up the excellent work!');
    }
    else if (percentage >= 85) {
        actions.push('Review and address any missed tasks');
    }
    else if (percentage < 70) {
        actions.push('Schedule team check-in for missed tasks');
        actions.push('Review task completion procedures');
    }
    if (summaryData.photoBypassed?.length > 0) {
        actions.push('Follow up on missing photo requirements');
    }
    actions.push('Check dashboard for complete task details');
    return actions.join('<br>');
}
function formatDateForDisplay(date) {
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${weekdays[date.getDay()]}, ${months[date.getMonth()]} ${date.getDate()}`;
}
function formatDateForSubject(date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${months[date.getMonth()]} ${date.getDate()}`;
}
/**
 * Build enhanced HTML sections for the email: task insights, staff performance, and actionable metrics
 */
function buildEnhancedHtmlSections(summaryData, yesterdayData) {
    try {
        // Overall delta vs yesterday
        const todayPct = summaryData.overallPercentage || 0;
        const yesterdayPct = yesterdayData?.overallPercentage || 0;
        const delta = Math.round(todayPct - yesterdayPct);
        const deltaText = delta === 0 ? 'no change' : `${delta >= 0 ? '+' : ''}${delta}%`;
        const deltaColor = delta >= 0 ? '#8cf68c' : '#ff6b6b';
        const overallDeltaHtml = `<span style="color:${deltaColor}; font-weight:700;">${deltaText} vs yesterday</span>`;
        // Build top missed tasks breakdown
        const missedTasks = summaryData.missedTaskEntries || [];
        const totalTasks = summaryData.totalTasks || 0;
        const completedTasks = summaryData.completedTasks || 0;
        // FIX: Use explicit incomplete count from summaryData
        const incompleteTasks = summaryData.incompleteTasks || 0;
        let missedTasksHtml = '';
        if (incompleteTasks > 0 && missedTasks.length > 0) {
            const topMissed = missedTasks.slice(0, 5); // Top 5 incomplete tasks
            missedTasksHtml = '<div style="margin-top:8px;">';
            topMissed.forEach((task, index) => {
                const reason = task.reason || 'No reason provided';
                const reasonColor = task.hasReason ? '#ff9d7a' : '#bfbfbf';
                missedTasksHtml += `<div style="margin-bottom:8px; padding:8px; background:rgba(255,107,45,0.1); border-left:3px solid #ff6b2d; border-radius:3px;">
          <div style="font-weight:600; color:#fff;">${escapeHtml(task.taskName)}</div>
          <div style="font-size:12px; color:#bfbfbf; margin-top:2px;">${escapeHtml(task.shiftName)} • ${escapeHtml(task.checklistName)}</div>
          <div style="font-size:12px; color:${reasonColor}; margin-top:4px;">Reason: ${escapeHtml(reason)}</div>
        </div>`;
            });
            if (incompleteTasks > 5) {
                missedTasksHtml += `<div style="color:#9b9b9b; font-size:12px; text-align:center; margin-top:8px;">... and ${incompleteTasks - 5} more incomplete tasks</div>`;
            }
            missedTasksHtml += '</div>';
        }
        else if (incompleteTasks > 0 && missedTasks.length === 0) {
            // If incomplete count exists but no task details, show generic message
            missedTasksHtml = `<div style="color:#ffbe08; margin-top:8px;">⚠️ ${incompleteTasks} tasks incomplete - details not recorded</div>`;
        }
        else if (totalTasks === 0) {
            missedTasksHtml = '<div style="color:#9b9b9b; font-style:italic; margin-top:8px;">No tasks scheduled for this period.</div>';
        }
        else {
            // ONLY show success if truly 100% complete
            missedTasksHtml = '<div style="color:#8cf68c; font-style:italic; margin-top:8px;">All tasks completed successfully! 🎉</div>';
        }
        // Build staff notes highlight
        const notes = summaryData.notesEntries || [];
        let staffNotesHtml = '';
        if (notes.length > 0) {
            const topNotes = notes.slice(0, 3); // Top 3 most recent notes
            staffNotesHtml = '<div style="margin-top:8px;">';
            topNotes.forEach((note) => {
                staffNotesHtml += `<div style="margin-bottom:8px; padding:8px; background:rgba(140,246,140,0.1); border-left:3px solid #8cf68c; border-radius:3px;">
          <div style="font-weight:600; color:#fff;">${escapeHtml(note.taskName)}</div>
          <div style="font-size:12px; color:#bfbfbf; margin-top:2px;">by ${escapeHtml(note.userName)} • ${escapeHtml(note.shiftName)}</div>
          <div style="font-size:13px; color:#fff; margin-top:4px; font-style:italic;">"${escapeHtml(note.notes)}"</div>
        </div>`;
            });
            if (notes.length > 3) {
                staffNotesHtml += `<div style="color:#9b9b9b; font-size:12px; text-align:center; margin-top:8px;">... and ${notes.length - 3} more staff notes</div>`;
            }
            staffNotesHtml += '</div>';
        }
        else {
            staffNotesHtml = '<div style="color:#9b9b9b; font-style:italic; margin-top:8px;">No additional notes recorded today.</div>';
        }
        // Build photo compliance section
        const photoBypassed = summaryData.photoBypassed || [];
        let photoComplianceHtml = '';
        if (photoBypassed.length > 0) {
            photoComplianceHtml = `<div style="margin-top:8px; padding:8px; background:rgba(255,190,8,0.1); border-left:3px solid #ffbe08; border-radius:3px;">
        <div style="font-weight:600; color:#ffbe08;">📷 Photo Requirements Missed (${photoBypassed.length})</div>
        <div style="font-size:12px; color:#bfbfbf; margin-top:4px;">Tasks completed without required photos. Follow up with staff on photo compliance.</div>`;
            const topPhotoMissed = photoBypassed.slice(0, 2);
            topPhotoMissed.forEach((item) => {
                photoComplianceHtml += `<div style="font-size:12px; color:#fff; margin-top:6px;">• ${escapeHtml(item.taskName)} (${escapeHtml(item.userName)})</div>`;
            });
            if (photoBypassed.length > 2) {
                photoComplianceHtml += `<div style="font-size:12px; color:#9b9b9b; margin-top:4px;">... and ${photoBypassed.length - 2} more</div>`;
            }
            photoComplianceHtml += '</div>';
        }
        else {
            photoComplianceHtml = '<div style="color:#8cf68c; font-style:italic; margin-top:8px;">All photo requirements met! 📸</div>';
        }
        // Build key metrics summary table
        const keyMetricsHtml = `<table style="width:100%; border-collapse:collapse; margin-top:8px;">
      <tr style="border-bottom:1px solid rgba(255,255,255,0.1);">
        <td style="padding:8px 0; color:#ff6b2d; font-weight:600;">Completion Rate</td>
        <td style="padding:8px 0; text-align:right; color:#fff; font-weight:700;">${todayPct.toFixed(1)}%</td>
      </tr>
      <tr style="border-bottom:1px solid rgba(255,255,255,0.1);">
        <td style="padding:8px 0; color:#ff6b2d; font-weight:600;">Tasks Completed</td>
        <td style="padding:8px 0; text-align:right; color:#8cf68c; font-weight:700;">${summaryData.completedTasks || 0} of ${summaryData.tasksScheduledForToday || 0}</td>
      </tr>
      <tr style="border-bottom:1px solid rgba(255,255,255,0.1);">
        <td style="padding:8px 0; color:#ff6b2d; font-weight:600;">Tasks Incomplete</td>
        <td style="padding:8px 0; text-align:right; color:#ff6b6b; font-weight:700;">${incompleteTasks}</td>
      </tr>
      <tr style="border-bottom:1px solid rgba(255,255,255,0.1);">
        <td style="padding:8px 0; color:#ff6b2d; font-weight:600;">Staff Notes</td>
        <td style="padding:8px 0; text-align:right; color:#8cf68c; font-weight:700;">${notes.length}</td>
      </tr>
      <tr>
        <td style="padding:8px 0; color:#ff6b2d; font-weight:600;">vs Yesterday</td>
        <td style="padding:8px 0; text-align:right;">${overallDeltaHtml}</td>
      </tr>
    </table>`;
        // Build location breakdown HTML
        const locationBreakdown = summaryData.locationBreakdown || [];
        let locationBreakdownHtml = '';
        if (locationBreakdown.length > 0) {
            locationBreakdownHtml = '<table style="width:100%; border-collapse:collapse; margin-top:8px;">';
            locationBreakdownHtml += '<tr style="border-bottom:2px solid rgba(255,255,255,0.2);"><td colspan="2" style="padding:8px 0; color:#ff6b2d; font-weight:700; font-size:14px;">📍 Performance by Location (Today\'s Tasks Only)</td></tr>';
            for (const loc of locationBreakdown) {
                const percentage = loc.completionPercentage || 0;
                const emoji = percentage >= 90 ? '✅' : percentage >= 70 ? '⚠️' : '❌';
                const color = percentage >= 90 ? '#8cf68c' : percentage >= 70 ? '#ffbe08' : '#ff6b6b';
                locationBreakdownHtml += `<tr style="border-bottom:1px solid rgba(255,255,255,0.1);">
          <td style="padding:8px 0; color:#fff;">${emoji} ${escapeHtml(loc.locationName)}</td>
          <td style="padding:8px 0; text-align:right;">
            <span style="color:${color}; font-weight:700;">${percentage.toFixed(0)}%</span>
            <span style="color:#9b9b9b; font-size:12px; margin-left:8px;">(${loc.completedRegular}/${loc.totalRegular})</span>
          </td>
        </tr>`;
            }
            locationBreakdownHtml += '</table>';
        }
        else {
            locationBreakdownHtml = '<div style="color:#9b9b9b; font-style:italic; margin-top:8px;">No location data available.</div>';
        }
        return {
            overallDeltaHtml,
            missedTasksHtml,
            staffNotesHtml,
            photoComplianceHtml,
            keyMetricsHtml,
            locationBreakdownHtml
        };
    }
    catch (error) {
        functions.logger.error('Error building enhanced HTML sections:', error);
        return null;
    }
}
function escapeHtml(s) {
    return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
/**
 * Send notification to admins using the new outbox system
 */
async function sendNotificationToAdmins(orgId, title, message, adminUsers) {
    try {
        const adminUserIds = Array.from(new Set((adminUsers || [])
            .map((u) => u?.userId)
            .filter((id) => typeof id === "string" && id.length > 0)));
        if (adminUserIds.length === 0) {
            functions.logger.warn(`No admin user IDs provided for daily summary notification in org ${orgId}`);
            return;
        }
        // Create ONE notification in the outbox; fan-out + push are handled by onNotificationOutboxCreated.
        const notificationRef = db
            .collection("organizations")
            .doc(orgId)
            .collection("notificationOutbox")
            .doc();
        await notificationRef.set({
            title,
            message,
            type: "daily_summary",
            targetType: "user_ids",
            userIds: adminUserIds,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
        });
        functions.logger.info(`Daily summary outbox notification created for ${adminUserIds.length} admin(s) in org ${orgId}`);
    }
    catch (error) {
        functions.logger.error("Error sending notifications to admins:", error);
        throw error;
    }
}
/**
 * Build notification content from summary data
 */
function buildNotificationContent(summaryData, date) {
    const { notesEntries, missedTaskEntries, photoBypassed, completedTasks, overallPercentage, summaryPeriod, tasksScheduledForToday, locationBreakdown } = summaryData;
    // Add period indicator to title
    const periodText = summaryPeriod === 'business-day' ? ' (Business Day)' : '';
    let content = `📊 Daily Summary${periodText}\n\n`;
    // Overall performance with emoji
    const performanceEmoji = overallPercentage >= 95 ? '🎉' : overallPercentage >= 85 ? '✅' : overallPercentage >= 70 ? '👍' : '⚠️';
    content += `${performanceEmoji} Overall Progress: ${Math.round(overallPercentage)}% (${completedTasks}/${tasksScheduledForToday} tasks completed)\n\n`;
    // Performance message
    if (overallPercentage >= 95) {
        content += `Outstanding work! Nearly perfect completion rate.\n\n`;
    }
    else if (overallPercentage >= 85) {
        content += `Great job! Strong performance across all areas.\n\n`;
    }
    else if (overallPercentage >= 70) {
        content += `Good progress! A few items need attention.\n\n`;
    }
    else {
        content += `Action needed! Several tasks require follow-up.\n\n`;
    }
    // Location breakdown (only regular tasks, excluding carry-forward)
    if (locationBreakdown && locationBreakdown.length > 0) {
        content += `📍 Performance by Location:\n`;
        for (const loc of locationBreakdown) {
            const emoji = loc.completionPercentage >= 90 ? '✅' : loc.completionPercentage >= 70 ? '⚠️' : '❌';
            content += `${emoji} ${loc.locationName}: ${Math.round(loc.completionPercentage)}% (${loc.completedRegular}/${loc.totalRegular})\n`;
        }
        content += `\n`;
    }
    // Missed tasks section with more detail
    if (missedTaskEntries.length > 0) {
        content += `❌ Missed Tasks (${missedTaskEntries.length}):\n`;
        missedTaskEntries.slice(0, 5).forEach((entry) => {
            const reason = entry.reason || 'No reason provided';
            const shift = entry.shiftName ? ` - ${entry.shiftName}` : '';
            content += `• ${entry.taskName}${shift}\n  Reason: ${reason}\n`;
        });
        if (missedTaskEntries.length > 5) {
            content += `• ... and ${missedTaskEntries.length - 5} more\n`;
        }
        content += `\n`;
    }
    // Photo bypassed section
    if (photoBypassed.length > 0) {
        content += `📷 Missing Photos (${photoBypassed.length}):\n`;
        photoBypassed.slice(0, 3).forEach((entry) => {
            const shift = entry.shiftName ? ` - ${entry.shiftName}` : '';
            content += `• ${entry.taskName}${shift}\n  by ${entry.userName}\n`;
        });
        if (photoBypassed.length > 3) {
            content += `• ... and ${photoBypassed.length - 3} more\n`;
        }
        content += `\n`;
    }
    // Staff notes section with more context
    if (notesEntries.length > 0) {
        content += `📝 Staff Notes (${notesEntries.length}):\n`;
        notesEntries.slice(0, 3).forEach((entry) => {
            const shift = entry.shiftName ? ` - ${entry.shiftName}` : '';
            content += `• ${entry.taskName}${shift}\n  "${entry.notes}" - ${entry.userName}\n`;
        });
        if (notesEntries.length > 3) {
            content += `• ... and ${notesEntries.length - 3} more\n`;
        }
        content += `\n`;
    }
    // Summary of key metrics
    const incompleteTasks = missedTaskEntries.length;
    if (incompleteTasks === 0 && tasksScheduledForToday > 0) {
        content += `✨ All tasks completed successfully!\n\n`;
    }
    else if (incompleteTasks > 10) {
        content += `⚠️ Significant attention needed: ${incompleteTasks} tasks incomplete\n\n`;
    }
    content += `📱 View full details in the app`;
    return content;
}
/**
 * Check if daily summary has been sent for a specific date
 */
async function hasDailySummaryBeenSent(orgId, dateStr) {
    try {
        const doc = await db
            .collection("organizations")
            .doc(orgId)
            .collection("daily_summary_logs")
            .doc(dateStr)
            .get();
        return doc.exists;
    }
    catch (error) {
        functions.logger.error("Error checking if daily summary was sent:", error);
        return false;
    }
}
/**
 * Mark daily summary as sent
 */
async function markDailySummaryAsSent(orgId, dateStr) {
    try {
        const logRef = db
            .collection("organizations")
            .doc(orgId)
            .collection("daily_summary_logs")
            .doc(dateStr);
        const logData = {
            date: dateStr,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            organizationId: orgId
        };
        await firestoreTTLHelper_1.FirestoreTTLHelper.setWithTTL(logRef, logData);
        functions.logger.info(`Marked daily summary as sent for ${orgId} on ${dateStr}`);
    }
    catch (error) {
        functions.logger.error("Error marking daily summary as sent:", error);
    }
}
/**
 * Format date as YYYY-MM-DD
 */
function formatDate(date) {
    return date.getFullYear() + '-' +
        String(date.getMonth() + 1).padStart(2, '0') + '-' +
        String(date.getDate()).padStart(2, '0');
}
/**
 * Format date for readable display
 */
function formatDateReadable(date) {
    return date.toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    });
}
