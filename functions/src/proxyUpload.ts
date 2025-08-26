import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Callable function that accepts base64-encoded file bytes and writes
// them to the project's default GCS bucket. Returns a download URL.
// Expects data: { path: string, contentType?: string, base64?: string }
export const proxyUpload = functions.https.onCall(async (data, context) => {
  try {
    const { path, contentType, base64 } = data || {};
    if (!path || typeof path !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Missing path');
    }
    if (!base64 || typeof base64 !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Missing base64 payload');
    }

    const bucket = admin.storage().bucket();
    const file = bucket.file(path);

    const buffer = Buffer.from(base64, 'base64');

    await file.save(buffer, {
      contentType: contentType || 'application/octet-stream',
      resumable: false,
    });

    // Optionally set metadata such as cache-control
    await file.setMetadata({
      metadata: {
        uploadedBy: context.auth?.uid || 'anonymous',
      },
    });

    // Generate a V4 signed URL for reading the file so the browser can fetch it
    // without needing bucket CORS changes. Expires in 1 hour.
    const [readUrl] = await file.getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: Date.now() + 60 * 60 * 1000, // 1 hour
    });

    return { downloadUrl: readUrl, path };
  } catch (e: any) {
    console.error('Error in proxyUpload', e);
    throw new functions.https.HttpsError('internal', e.message || String(e));
  }
});
