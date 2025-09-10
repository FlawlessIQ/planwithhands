import * as functions from 'firebase-functions';
import { getMessaging } from 'firebase-admin/messaging';

export const sendToToken = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
    }

    const { token, title, body } = data;
    if (!token || !title) {
      throw new functions.https.HttpsError('invalid-argument', 'Token and title required');
    }

    const uid = context.auth.uid;
    console.log(`[sendToToken] Sending test notification for user: ${uid}`);

    try {
      const message = {
        notification: { title, body: body || 'Test notification' },
        data: { testMessage: 'true', sentBy: uid },
        token: token,
      };

      const response = await getMessaging().send(message);
      console.log(`[sendToToken] Success. Message ID: ${response}`);
      
      return { success: true, messageId: response };
    } catch (error) {
      console.error(`[sendToToken] Error:`, error);
      throw new functions.https.HttpsError('internal', `Failed: ${error}`);
    }
  });
