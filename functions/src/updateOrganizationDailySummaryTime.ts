import * as functions from 'firebase-functions';
import { Firestore, FieldValue } from '@google-cloud/firestore';

const FIRESTORE_DATABASE_ID = 'planwithhands';
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

interface UpdateTimeRequest {
  organizationId: string;
  hour: number;
  minute: number;
  enabled: boolean;
  summaryPeriod: string;
}

/**
 * Updates the organization's daily summary time
 * This is called after validation passes
 */
export const updateOrganizationDailySummaryTime = functions.https.onCall(async (data: UpdateTimeRequest, context) => {
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
        updatedAt: FieldValue.serverTimestamp(),
        lastChangeAt: FieldValue.serverTimestamp(), // Track when last changed for rate limiting
      },
    });

    console.log(`Daily summary time updated for org ${organizationId}: ${hour}:${String(minute).padStart(2, '0')}`);

    return { success: true };
  }
);
