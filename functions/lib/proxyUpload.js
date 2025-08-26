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
exports.proxyUpload = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
// Callable function that accepts base64-encoded file bytes and writes
// them to the project's default GCS bucket. Returns a download URL.
// Expects data: { path: string, contentType?: string, base64?: string }
exports.proxyUpload = functions.https.onCall(async (data, context) => {
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
    }
    catch (e) {
        console.error('Error in proxyUpload', e);
        throw new functions.https.HttpsError('internal', e.message || String(e));
    }
});
