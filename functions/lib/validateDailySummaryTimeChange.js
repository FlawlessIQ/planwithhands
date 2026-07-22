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
exports.validateDailySummaryTimeChange = void 0;
const functions = __importStar(require("firebase-functions"));
const luxon_1 = require("luxon");
const firestore_1 = require("@google-cloud/firestore");
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
/**
 * Validates whether a daily summary time change is allowed
 * Enforces rate limiting (1 change per 24 hours) and provides warnings
 */
exports.validateDailySummaryTimeChange = functions.https.onCall(async (data, context) => {
    const { organizationId, newTime, timezone } = data;
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
        throw new functions.https.HttpsError('permission-denied', 'Only organization admins can change daily summary settings');
    }
    // Get organization data
    const orgDoc = await db.collection('organizations').doc(organizationId).get();
    if (!orgDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Organization not found');
    }
    const orgData = orgDoc.data();
    const orgName = orgData?.name || 'your organization';
    // Validate time format
    const timeRegex = /^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$/;
    if (!timeRegex.test(newTime)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid time format. Use HH:mm (e.g., 08:30)');
    }
    const [newHour, newMinute] = newTime.split(':').map(Number);
    // Check for rate limiting - only allow one change per 24 hours
    const dailySummarySettings = orgData?.dailySummarySettings;
    const lastChangeTime = dailySummarySettings?.lastChangeAt?.toDate();
    if (lastChangeTime) {
        const hoursSinceLastChange = (Date.now() - lastChangeTime.getTime()) / (1000 * 60 * 60);
        console.log(`Time change attempt for org ${organizationId}: Last change was ${hoursSinceLastChange.toFixed(1)} hours ago`);
        if (hoursSinceLastChange < 24) {
            const hoursRemaining = Math.ceil(24 - hoursSinceLastChange);
            return {
                allowed: false,
                message: `⏱️ Rate limit exceeded. Daily summary time can only be changed once per 24 hours.\n\n` +
                    `Last change: ${Math.floor(hoursSinceLastChange)} hours ago\n` +
                    `Try again in: ${hoursRemaining} hour${hoursRemaining === 1 ? '' : 's'}`,
                hoursSinceLastChange: Math.floor(hoursSinceLastChange),
            };
        }
    }
    // Check if the new time has already passed today
    const now = luxon_1.DateTime.now().setZone(timezone);
    const targetTime = luxon_1.DateTime.fromObject({ hour: newHour, minute: newMinute }, { zone: timezone });
    const timePassed = targetTime.hour < now.hour ||
        (targetTime.hour === now.hour && targetTime.minute < now.minute);
    // Calculate when the summary will next be sent
    let nextSendDateTime;
    if (timePassed) {
        // If time has passed, it will send tomorrow
        nextSendDateTime = now.plus({ days: 1 }).set({ hour: newHour, minute: newMinute, second: 0, millisecond: 0 });
    }
    else {
        // Will send later today
        nextSendDateTime = now.set({ hour: newHour, minute: newMinute, second: 0, millisecond: 0 });
    }
    // Convert to UTC to show actual send time (function runs on the hour)
    const utcSendTime = nextSendDateTime.toUTC();
    const sendHour = utcSendTime.hour;
    const nextScheduledRunUTC = utcSendTime.set({
        hour: sendHour === 23 ? 0 : sendHour + 1,
        minute: 0,
        second: 0
    });
    if (sendHour === 23) {
        nextScheduledRunUTC.plus({ days: 1 });
    }
    const formattedNextSend = nextScheduledRunUTC.setZone(timezone).toFormat('cccc, MMMM d \'at\' h:mm a ZZZZ');
    if (timePassed) {
        // Time has already passed today
        return {
            allowed: true,
            requiresConfirmation: true,
            timePassed: true,
            offerImmediateSend: true,
            warning: `⚠️ The time ${newTime} has already passed today.\n\n` +
                `If you proceed, the daily summary for ${orgName} will be sent:\n` +
                `📅 ${formattedNextSend}\n\n` +
                `💡 Would you like to send today's summary immediately instead?`,
            nextSendTime: formattedNextSend,
        };
    }
    // Time is in the future today - show confirmation
    const hoursUntilSend = Math.ceil(nextScheduledRunUTC.diff(now, 'hours').hours);
    return {
        allowed: true,
        requiresConfirmation: true,
        timePassed: false,
        offerImmediateSend: false,
        message: `✅ Daily summary time will be updated to ${newTime}.\n\n` +
            `Next summary will be sent:\n` +
            `📅 ${formattedNextSend}\n` +
            `(in approximately ${hoursUntilSend} hour${hoursUntilSend === 1 ? '' : 's'})`,
        nextSendTime: formattedNextSend,
    };
});
