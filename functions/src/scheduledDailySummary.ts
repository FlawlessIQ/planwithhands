import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {DateTime} from "luxon";
import {FirestoreTTLHelper} from "./firestoreTTLHelper";
import {Firestore} from "@google-cloud/firestore";

// Ensure we use the correct Firestore database
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Scheduled function that runs daily to generate and send daily summaries to administrators
 * Runs at 21:00 UTC daily (9 PM UTC)
 */
export const scheduledDailySummary = functions.pubsub
  .schedule("0 21 * * *") // Daily at 9 PM UTC
  .timeZone("UTC")
  .onRun(async () => {
    functions.logger.info("Starting scheduled daily summary generation");

    let summariesSent = 0;
    let errors = 0;

    try {
      // Get all active organizations
      const orgsSnapshot = await db.collection("organizations").get();
      
      for (const orgDoc of orgsSnapshot.docs) {
        const orgId = orgDoc.id;
        const orgData = orgDoc.data();
        
        try {
          functions.logger.info(`Processing daily summary for organization: ${orgId}`);
          
          // Check if summary already sent today
          const today = new Date();
          const dateStr = formatDate(today);
          const alreadySent = await hasDailySummaryBeenSent(orgId, dateStr);
          
          if (alreadySent) {
            functions.logger.info(`Daily summary already sent for ${orgId} on ${dateStr}`);
            continue;
          }

          // Determine local time zones from organization locations
          const timezones = await getOrganizationTimezones(orgId);
          
          // Check if it's appropriate time to send summary in any timezone
          const shouldSend = timezones.some(tz => {
            const localTime = DateTime.now().setZone(tz);
            const hour = localTime.hour;
            // Send between 8 PM and 11 PM local time
            return hour >= 20 && hour <= 23;
          });

          if (!shouldSend) {
            functions.logger.info(`Not appropriate time for daily summary in org ${orgId}`);
            continue;
          }

          // Generate and send daily summary
          await generateAndSendDailySummary(orgId, today, orgData);
          
          // Mark as sent
          await markDailySummaryAsSent(orgId, dateStr);
          
          summariesSent++;
          functions.logger.info(`Daily summary sent successfully for organization: ${orgId}`);
          
        } catch (error) {
          errors++;
          functions.logger.error(`Error processing daily summary for org ${orgId}:`, error);
        }
      }

      functions.logger.info(`Daily summary job completed: ${summariesSent} sent, ${errors} errors`);
      
    } catch (error) {
      functions.logger.error("Error in scheduled daily summary:", error);
    }

    return null;
  });

/**
 * Manually trigger daily summary for a specific organization
 * Can be called via HTTP or from the app
 */
export const triggerDailySummary = functions.https.onCall(async (data, context) => {
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
    
    await generateAndSendDailySummary(orgId, date, orgData);
    
    functions.logger.info(`Manual daily summary triggered for org ${orgId}`);
    return { success: true, message: "Daily summary sent successfully" };
    
  } catch (error) {
    functions.logger.error(`Error in manual daily summary trigger for org ${orgId}:`, error);
    throw new functions.https.HttpsError("internal", "Failed to generate daily summary");
  }
});

/**
 * Generate and send daily summary for an organization
 */
async function generateAndSendDailySummary(orgId: string, date: Date, orgData: any) {
  const dateStr = formatDate(date);
  functions.logger.info(`Generating daily summary for org ${orgId}, date: ${dateStr}`);

  // Collect summary data
  const summaryData = await collectDailySummaryData(orgId, date);
  
  // Check if there's meaningful content
  const hasContent = summaryData.totalTasks > 0 || 
                    summaryData.notesEntries.length > 0 ||
                    summaryData.missedTaskEntries.length > 0 ||
                    summaryData.photoBypassed.length > 0;

  if (!hasContent) {
    functions.logger.info(`No meaningful activity for ${orgId} on ${dateStr} - skipping summary`);
    return;
  }

  // Get admin users
  const adminUsers = await getAdminUsers(orgId);
  
  if (adminUsers.length === 0) {
    functions.logger.warn(`No admin users found for organization ${orgId}`);
    return;
  }

  // Generate notification content
  const title = `Daily Summary - ${formatDateReadable(date)}`;
  const message = buildNotificationContent(summaryData, date);

  // Send notification using the new outbox system
  await sendNotificationToAdmins(orgId, title, message, adminUsers);

  functions.logger.info(`Daily summary sent to ${adminUsers.length} admin(s) for org ${orgId}`);
}

/**
 * Collect comprehensive daily summary data
 */
async function collectDailySummaryData(orgId: string, date: Date): Promise<any> {
  const dateStr = formatDate(date);
  const notesEntries: any[] = [];
  const missedTaskEntries: any[] = [];
  const photoBypassed: any[] = [];
  let totalTasks = 0;
  let completedTasks = 0;

  try {
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

      // Query daily checklists for this location on the target date
      const checklistsSnapshot = await db
        .collection("organizations")
        .doc(orgId)
        .collection("locations")
        .doc(locationId)
        .collection("daily_checklists")
        .where("date", "==", dateStr)
        .get();

      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const shiftId = checklistData.shiftId || "unknown";
        const shiftName = shiftNames[shiftId] || "Unknown Shift";
        const templateName = checklistData.templateName || "Unknown Checklist";

        // Process tasks from subcollection
        const tasksSnapshot = await checklistDoc.ref.collection("tasks").get();
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
          if (isCompleted) {
            completedTasks++;
          }
        }

        // Also process legacy tasks array
        const tasks = checklistData.tasks || [];
        for (const taskData of tasks) {
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
          if (isCompleted) {
            completedTasks++;
          }
        }
      }
    }

    const overallPercentage = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0;

    return {
      notesEntries,
      missedTaskEntries,
      photoBypassed,
      totalTasks,
      completedTasks,
      overallPercentage
    };

  } catch (error) {
    functions.logger.error("Error collecting daily summary data:", error);
    return {
      notesEntries: [],
      missedTaskEntries: [],
      photoBypassed: [],
      totalTasks: 0,
      completedTasks: 0,
      overallPercentage: 0
    };
  }
}

/**
 * Process a single task for summary data collection
 */
async function processTaskForSummary(params: {
  taskData: any;
  shiftName: string;
  templateName: string;
  locationName: string;
  userNames: Record<string, string>;
  notesEntries: any[];
  missedTaskEntries: any[];
  photoBypassed: any[];
}) {
  const { taskData, shiftName, templateName, locationName, userNames, notesEntries, missedTaskEntries, photoBypassed } = params;
  
  const taskName = taskData.taskName || taskData.description || taskData.title || taskData.name || "Unknown Task";
  const isCompleted = taskData.completed || taskData.isCompleted || false;
  const photoRequired = taskData.photoRequired || false;
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

  // Check for not completed reasons
  const reason = taskData.reason || taskData.notCompletedReason;
  if (!isCompleted && reason && reason.trim()) {
    missedTaskEntries.push({
      taskName,
      shiftName,
      checklistName: templateName,
      locationName,
      reason
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
async function getAdminUsers(orgId: string): Promise<any[]> {
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
  } catch (error) {
    functions.logger.error("Error getting admin users:", error);
    return [];
  }
}

/**
 * Get shift names map
 */
async function getShiftNames(orgId: string): Promise<Record<string, string>> {
  try {
    const shiftsSnapshot = await db
      .collection("organizations")
      .doc(orgId)
      .collection("shifts")
      .get();

    const shiftNames: Record<string, string> = {};
    for (const doc of shiftsSnapshot.docs) {
      const data = doc.data();
      shiftNames[doc.id] = data.shiftName || "Unknown Shift";
    }

    return shiftNames;
  } catch (error) {
    functions.logger.error("Error getting shift names:", error);
    return {};
  }
}

/**
 * Get user names map
 */
async function getUserNames(orgId: string): Promise<Record<string, string>> {
  try {
    const usersSnapshot = await db
      .collection("users")
      .where("organizationId", "==", orgId)
      .get();

    const userNames: Record<string, string> = {};
    for (const doc of usersSnapshot.docs) {
      const data = doc.data();
      const firstName = data.firstName || "";
      const lastName = data.lastName || "";
      userNames[doc.id] = `${firstName} ${lastName}`.trim();
    }

    return userNames;
  } catch (error) {
    functions.logger.error("Error getting user names:", error);
    return {};
  }
}

/**
 * Get organization timezones from locations
 */
async function getOrganizationTimezones(orgId: string): Promise<string[]> {
  try {
    const locationsSnapshot = await db
      .collection("organizations")
      .doc(orgId)
      .collection("locations")
      .get();

    const timezones = new Set<string>();
    for (const doc of locationsSnapshot.docs) {
      const data = doc.data();
      const timezone = data.timezone;
      if (timezone) {
        timezones.add(timezone);
      }
    }

    // Default to UTC if no timezones found
    return timezones.size > 0 ? Array.from(timezones) : ["UTC"];
  } catch (error) {
    functions.logger.error("Error getting organization timezones:", error);
    return ["UTC"];
  }
}

/**
 * Send notification to admins using the new outbox system
 */
async function sendNotificationToAdmins(orgId: string, title: string, message: string, adminUsers: any[]) {
  try {
    // Create notification in the outbox for fan-out to individual user inboxes
    const notificationRef = db
      .collection("organizations")
      .doc(orgId)
      .collection("notificationOutbox")
      .doc();

    const notificationData = {
      title,
      message,
      type: "daily_summary",
      targetType: "all_users", // This will be filtered to admin users only
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      // Add TTL
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
    };

    await notificationRef.set(notificationData);

    // Also create individual user notifications for immediate delivery
    const batch = db.batch();
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    for (const admin of adminUsers) {
      const userNotificationRef = db
        .collection("userNotifications")
        .doc(admin.userId)
        .collection("notifications")
        .doc();

      batch.set(userNotificationRef, {
        userId: admin.userId,
        orgId,
        type: "daily_summary",
        title,
        message,
        readBy: [],
        archivedBy: [],
        createdAt: timestamp,
        targetType: "user",
        targetId: admin.userId,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        outboxId: notificationRef.id,
      });
    }

    await batch.commit();
    functions.logger.info(`Daily summary notifications created for ${adminUsers.length} admin users`);

  } catch (error) {
    functions.logger.error("Error sending notifications to admins:", error);
    throw error;
  }
}

/**
 * Build notification content from summary data
 */
function buildNotificationContent(summaryData: any, date: Date): string {
  const { notesEntries, missedTaskEntries, photoBypassed, totalTasks, completedTasks, overallPercentage } = summaryData;
  
  let content = `📊 Daily Summary\n\n`;
  content += `Overall Progress: ${Math.round(overallPercentage)}% (${completedTasks}/${totalTasks} tasks completed)\n\n`;

  // Performance message
  if (overallPercentage >= 95) {
    content += `🎉 Outstanding work! Nearly perfect completion rate.\n\n`;
  } else if (overallPercentage >= 85) {
    content += `✅ Great job! Strong performance across all areas.\n\n`;
  } else if (overallPercentage >= 70) {
    content += `👍 Good progress! A few items need attention.\n\n`;
  } else {
    content += `⚠️ Action needed! Several tasks require follow-up.\n\n`;
  }

  // Key highlights
  if (missedTaskEntries.length > 0) {
    content += `❌ Missed Tasks (${missedTaskEntries.length}):\n`;
    missedTaskEntries.slice(0, 3).forEach((entry: any) => {
      content += `• ${entry.taskName} - ${entry.reason}\n`;
    });
    if (missedTaskEntries.length > 3) {
      content += `• ... and ${missedTaskEntries.length - 3} more\n`;
    }
    content += `\n`;
  }

  if (photoBypassed.length > 0) {
    content += `📷 Missing Photos (${photoBypassed.length}):\n`;
    photoBypassed.slice(0, 2).forEach((entry: any) => {
      content += `• ${entry.taskName} by ${entry.userName}\n`;
    });
    if (photoBypassed.length > 2) {
      content += `• ... and ${photoBypassed.length - 2} more\n`;
    }
    content += `\n`;
  }

  if (notesEntries.length > 0) {
    content += `📝 Important Notes (${notesEntries.length}):\n`;
    notesEntries.slice(0, 2).forEach((entry: any) => {
      content += `• ${entry.taskName}: "${entry.notes}" - ${entry.userName}\n`;
    });
    if (notesEntries.length > 2) {
      content += `• ... and ${notesEntries.length - 2} more notes\n`;
    }
    content += `\n`;
  }

  content += `📱 View full details in the app`;

  return content;
}

/**
 * Check if daily summary has been sent for a specific date
 */
async function hasDailySummaryBeenSent(orgId: string, dateStr: string): Promise<boolean> {
  try {
    const doc = await db
      .collection("organizations")
      .doc(orgId)
      .collection("daily_summary_logs")
      .doc(dateStr)
      .get();

    return doc.exists;
  } catch (error) {
    functions.logger.error("Error checking if daily summary was sent:", error);
    return false;
  }
}

/**
 * Mark daily summary as sent
 */
async function markDailySummaryAsSent(orgId: string, dateStr: string) {
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

    await FirestoreTTLHelper.setWithTTL(logRef, logData);
    functions.logger.info(`Marked daily summary as sent for ${orgId} on ${dateStr}`);

  } catch (error) {
    functions.logger.error("Error marking daily summary as sent:", error);
  }
}

/**
 * Format date as YYYY-MM-DD
 */
function formatDate(date: Date): string {
  return date.getFullYear() + '-' +
         String(date.getMonth() + 1).padStart(2, '0') + '-' +
         String(date.getDate()).padStart(2, '0');
}

/**
 * Format date for readable display
 */
function formatDateReadable(date: Date): string {
  return date.toLocaleDateString('en-US', { 
    weekday: 'long', 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  });
}