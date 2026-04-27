import * as functions from "firebase-functions";
import {Firestore} from "@google-cloud/firestore";

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

export const diagnoseRuntimeEnv = functions.https.onCall(async (_data, context) => {
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
