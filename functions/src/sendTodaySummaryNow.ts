import * as functions from "firebase-functions";
import {DateTime} from "luxon";
import {Firestore} from "@google-cloud/firestore";
import {
  formatDate,
  generateAndSendDailySummary,
  hasDailySummaryBeenSent,
  markDailySummaryAsSent,
} from "./scheduledDailySummary";

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

interface SendNowRequest {
  organizationId: string;
  summaryDate?: string; // Optional: specific date to send (defaults to yesterday)
}

interface SendNowResponse {
  success: boolean;
  message: string;
  alreadySentToday?: boolean;
  recipientCount?: number;
}

/**
 * Immediately sends today's daily summary for an organization
 * Checks if already sent to prevent duplicates
 * Returns a user-friendly message for the UI
 */
export const sendTodaySummaryNow = functions.https.onCall(async (data: SendNowRequest, context) => {
    const { organizationId, summaryDate } = data;

    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Verify user has admin access to this organization
    const userDoc = await db.collection('users').doc(context.auth.uid).get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data();
    if (userData?.organizationId !== organizationId || userData?.userRole !== 2) {
      throw new functions.https.HttpsError('permission-denied', 'Only organization admins can trigger daily summaries');
    }

    // Get organization data
    const orgDoc = await db.collection('organizations').doc(organizationId).get();

    if (!orgDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Organization not found');
    }

    const orgData = orgDoc.data();
    const orgName = orgData?.name || 'Unknown Organization';

    const timezone = orgData?.timezone || "America/New_York";

    // Determine which date we're sending for (defaults to yesterday in org timezone)
    const targetDateISO = summaryDate || (() => {
      const yesterday = DateTime.now().setZone(timezone).minus({days: 1});
      return yesterday.toFormat("yyyy-LL-dd");
    })();

    // Use midday in org timezone to avoid edge cases around midnight/UTC offsets.
    const dateInOrgTZ = DateTime.fromISO(targetDateISO, {zone: timezone}).set({
      hour: 12,
      minute: 0,
      second: 0,
      millisecond: 0,
    });
    const targetDate = dateInOrgTZ.toJSDate();
    const dateStr = formatDate(targetDate);

    console.log(
      `Manual immediate send request for org ${organizationId} (${orgName}) for date ${dateStr} (${timezone}) by user ${context.auth.uid}`
    );

    // Check if summary already sent for this date (same location as scheduler)
    const alreadySent = await hasDailySummaryBeenSent(organizationId, dateStr);
    if (alreadySent) {
      return {
        success: false,
        alreadySentToday: true,
        message: `Daily summary for ${dateStr} was already sent.\n\nIf you need to resend, please contact support.`,
      };
    }

    const sent = await generateAndSendDailySummary(organizationId, targetDate, orgData);
    if (!sent) {
      return {
        success: true,
        message: `Daily summary skipped for ${dateStr} (no activity or no recipients).`,
      };
    }

    await markDailySummaryAsSent(organizationId, dateStr);

    return {
      success: true,
      message: `✅ Daily summary sent for ${dateStr}!\n\nOrganization: ${orgName}`,
    };
  }
);
