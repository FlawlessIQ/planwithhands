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
exports.sendTodaySummaryNow = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("@google-cloud/firestore");
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
/**
 * Immediately sends today's daily summary for an organization
 * Checks if already sent to prevent duplicates
 * Returns a user-friendly message for the UI
 */
exports.sendTodaySummaryNow = functions.https.onCall(async (data, context) => {
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
});
