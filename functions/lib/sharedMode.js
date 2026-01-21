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
exports.sharedModeVerifyPin = exports.sharedModeSetPin = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("@google-cloud/firestore");
const crypto_1 = require("crypto");
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
if (!admin.apps.length) {
    admin.initializeApp();
}
function normalizePin(pin) {
    return (pin ?? "").toString().trim();
}
function isValidPin(pin) {
    // Keep it flexible; UX can recommend 4–6 digits.
    if (pin.length < 4 || pin.length > 10)
        return false;
    return /^[0-9]+$/.test(pin);
}
function hashPin(pin, saltHex) {
    const salt = Buffer.from(saltHex, "hex");
    const derived = (0, crypto_1.scryptSync)(pin, salt, 32);
    return derived.toString("hex");
}
function safeEqualHex(aHex, bHex) {
    try {
        const a = Buffer.from(aHex, "hex");
        const b = Buffer.from(bHex, "hex");
        if (a.length !== b.length)
            return false;
        return (0, crypto_1.timingSafeEqual)(a, b);
    }
    catch {
        return false;
    }
}
// Stores the PIN hash in a private-per-user doc (not readable by others).
// Public user doc only gets a boolean flag `hasSharedModePin`.
exports.sharedModeSetPin = functions.https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
    }
    const pin = normalizePin(data?.pin);
    if (!isValidPin(pin)) {
        throw new functions.https.HttpsError("invalid-argument", "PIN must be 4–10 digits");
    }
    const saltHex = (0, crypto_1.randomBytes)(16).toString("hex");
    const pinHash = hashPin(pin, saltHex);
    const privateRef = db.collection("users").doc(uid).collection("preferences").doc("sharedMode");
    const userRef = db.collection("users").doc(uid);
    await privateRef.set({
        pinSalt: saltHex,
        pinHash,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    // This boolean is safe to expose for listing eligible users.
    await userRef.set({
        hasSharedModePin: true,
        sharedModePinUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true };
});
exports.sharedModeVerifyPin = functions.https.onCall(async (data, context) => {
    const callerUid = context.auth?.uid;
    if (!callerUid) {
        throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
    }
    const targetUserId = (data?.targetUserId ?? "").toString();
    const orgId = (data?.orgId ?? "").toString();
    const locationId = (data?.locationId ?? "").toString();
    const pin = normalizePin(data?.pin);
    if (!targetUserId || !orgId || !locationId) {
        throw new functions.https.HttpsError("invalid-argument", "Missing targetUserId/orgId/locationId");
    }
    if (!isValidPin(pin)) {
        // Don't reveal pin requirements to attackers; still return ok:false.
        return { ok: false };
    }
    // Basic org + location scoping: only allow verifying PINs for users in the same org + location.
    const targetUserSnap = await db.collection("users").doc(targetUserId).get();
    if (!targetUserSnap.exists)
        return { ok: false };
    const target = targetUserSnap.data();
    if ((target.organizationId ?? "").toString() !== orgId)
        return { ok: false };
    if (target.hasSharedModePin !== true)
        return { ok: false };
    // Location eligibility (supports legacy `locationId` and modern `locationIds`).
    let matchesLocation = false;
    const rawLocs = target.locationIds ?? target.locationId;
    if (Array.isArray(rawLocs)) {
        matchesLocation = rawLocs.map((x) => x?.toString()).includes(locationId);
    }
    else if (rawLocs != null) {
        matchesLocation = rawLocs.toString() === locationId;
    }
    if (!matchesLocation)
        return { ok: false };
    const privateSnap = await db
        .collection("users")
        .doc(targetUserId)
        .collection("preferences")
        .doc("sharedMode")
        .get();
    if (!privateSnap.exists)
        return { ok: false };
    const priv = privateSnap.data();
    const saltHex = (priv.pinSalt ?? "").toString();
    const storedHash = (priv.pinHash ?? "").toString();
    if (!saltHex || !storedHash)
        return { ok: false };
    const computed = hashPin(pin, saltHex);
    const ok = safeEqualHex(storedHash, computed);
    if (!ok)
        return { ok: false };
    const first = (target.firstName ?? "").toString().trim();
    const last = (target.lastName ?? "").toString().trim();
    const displayName = (`${first} ${last}`).trim() || (target.name ?? "").toString() || "Staff";
    const email = (target.emailAddress ?? target.email ?? target.userEmail ?? "").toString() || null;
    return {
        ok: true,
        userId: targetUserId,
        displayName,
        email,
    };
});
