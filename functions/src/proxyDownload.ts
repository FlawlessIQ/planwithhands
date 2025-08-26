import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Callable function that returns base64-encoded contents of a file in the
// default storage bucket. Expects data: { path: string }
export const proxyDownload = functions.https.onCall(async (data, context) => {
  try {
    const { path } = data || {};
    if (!path || typeof path !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Missing path');
    }

    const bucket = admin.storage().bucket();
    const file = bucket.file(path);

    const [exists] = await file.exists();
    if (!exists) {
      throw new functions.https.HttpsError('not-found', 'File not found');
    }

    const [contents] = await file.download();
    const base64 = contents.toString('base64');
    const [meta] = await file.getMetadata();
    const contentType = meta.contentType || 'application/octet-stream';

    return { base64, contentType };
  } catch (e: any) {
    console.error('Error in proxyDownload', e);
    throw new functions.https.HttpsError('internal', e.message || String(e));
  }
});
