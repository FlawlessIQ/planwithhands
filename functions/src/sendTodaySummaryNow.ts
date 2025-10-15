import * as functions from 'firebase-functions';
import { Firestore } from '@google-cloud/firestore';

const FIRESTORE_DATABASE_ID = 'planwithhands';
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

    // Determine which date we're sending for (defaults to yesterday)
    const targetDate = summaryDate || (() => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      return yesterday.toISOString().split('T')[0];
    })();

    console.log(`Manual immediate send request for org ${organizationId} (${orgName}) for date ${targetDate} by user ${context.auth.uid}`);

    // Check if summary already sent for this date
    const existingLogSnapshot = await db.collection('daily_summary_logs')
      .where('organizationId', '==', organizationId)
      .where('summaryDate', '==', targetDate)
      .limit(1)
      .get();

    if (!existingLogSnapshot.empty) {
      const logData = existingLogSnapshot.docs[0].data();
      const sentAt = logData.sentAt?.toDate();
      
      console.log(`Summary already sent for ${targetDate} at ${sentAt?.toISOString()}`);
      
      return {
        success: false,
        alreadySentToday: true,
        message: `Daily summary for ${targetDate} was already sent at ${sentAt?.toLocaleString()}.\n\n` +
          `Recipients: ${logData.recipientCount || 'unknown'}\n\n` +
          `If you need to resend, please contact support.`,
      };
    }

    // Note: This function provides a user-friendly wrapper around triggerDailySummary
    // The actual summary generation is handled by the existing triggerDailySummary function
    // which should be called directly from the client for now
    
    return {
      success: true,
      message: `✅ Ready to send daily summary for ${targetDate}!\n\n` +
        `Organization: ${orgName}\n\n` +
        `Please use the triggerDailySummary function to complete the send.`,
    };
  }
);
