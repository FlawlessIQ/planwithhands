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
exports.diagnoseRuntimeEnv = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("@google-cloud/firestore");
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
exports.diagnoseRuntimeEnv = functions.https.onCall(async (_data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    // Optional: only admins can call
    const userDoc = await db.collection("users").doc(context.auth.uid).get();
    const userData = userDoc.data();
    if (!userDoc.exists || (userData?.userRole ?? 0) < 2) {
        throw new functions.https.HttpsError("permission-denied", "Admin access required");
    }
    return {
        firestoreDatabaseId: FIRESTORE_DATABASE_ID,
        hasSendgridApiKey: !!(process.env.SENDGRID_API_KEY || process.env.SENDGRID_KEY),
        hasSendgridFromEmail: !!process.env.SENDGRID_FROM_EMAIL,
        hasSendgridFromName: !!process.env.SENDGRID_FROM_NAME,
        effectiveSendgridFromEmail: process.env.SENDGRID_FROM_EMAIL || "noreply@planwithhands.com",
        effectiveSendgridFromName: process.env.SENDGRID_FROM_NAME || "Hands App",
        hasAppBaseUrl: !!process.env.APP_BASE_URL,
        hasStripeSecretKey: !!process.env.STRIPE_SECRET_KEY,
        hasGooglePlacesApiKey: !!process.env.GOOGLE_PLACES_API_KEY,
    };
});
