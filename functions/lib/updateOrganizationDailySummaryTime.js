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
exports.updateOrganizationDailySummaryTime = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("@google-cloud/firestore");
const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
/**
 * Updates the organization's daily summary time
 * This is called after validation passes
 */
exports.updateOrganizationDailySummaryTime = functions.https.onCall(async (data, context) => {
    const { organizationId, hour, minute, enabled, summaryPeriod } = data;
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
    // Update organization settings with lastChangeAt tracking
    await db.collection('organizations').doc(organizationId).update({
        'dailySummarySettings': {
            hour,
            minute,
            enabled,
            summaryPeriod,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
            lastChangeAt: firestore_1.FieldValue.serverTimestamp(), // Track when last changed for rate limiting
        },
    });
    console.log(`Daily summary time updated for org ${organizationId}: ${hour}:${String(minute).padStart(2, '0')}`);
    return { success: true };
});
