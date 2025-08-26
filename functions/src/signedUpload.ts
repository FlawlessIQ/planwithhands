import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Callable function that returns a V4 signed URL for uploading a file directly to GCS.
// Expects data: { path: string, contentType?: string }
export const getSignedUploadUrl = functions.https.onCall(async (data, context) => {
  try {
    const { path, contentType } = data || {};
    if (!path || typeof path !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Missing path');
    }

    const bucket = admin.storage().bucket();
    const file = bucket.file(path);

    const options: any = {
      version: 'v4',
      action: 'write',
      expires: Date.now() + 15 * 60 * 1000, // 15 minutes
    };
    if (contentType) options.contentType = contentType;

    const [url] = await file.getSignedUrl(options);

    return { uploadUrl: url, path };
  } catch (e: any) {
    console.error('Error generating signed upload URL', e);
    throw new functions.https.HttpsError('internal', e.message || String(e));
  }
});
