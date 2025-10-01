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
exports.enforceDailyChecklistOwnership = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("@google-cloud/firestore");
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
/**
 * Enforce that a newly created daily_checklist belongs to the location via template.locationIds.
 * If the checklist's template does not include the location, the document is deleted.
 */
exports.enforceDailyChecklistOwnership = functions.firestore
    .document("organizations/{orgId}/locations/{locId}/daily_checklists/{checklistId}")
    .onCreate(async (snap, context) => {
    const orgId = context.params.orgId;
    const locId = context.params.locId;
    const data = (snap.data() || {});
    try {
        // Determine template id(s)
        const single = (data.checklistTemplateId || data.templateId || "").toString();
        const multi = Array.isArray(data.checklistTemplateIds) ? data.checklistTemplateIds : [];
        const candidates = [];
        if (single)
            candidates.push(single);
        for (const t of multi)
            if (typeof t === "string" && t)
                candidates.push(t);
        if (candidates.length === 0) {
            // No template association; nothing to enforce
            return null;
        }
        // Load templates and check ownership
        const tmplRefs = candidates.map((tid) => db.doc(`organizations/${orgId}/checklist_templates/${tid}`));
        const tmplSnaps = await Promise.all(tmplRefs.map((r) => r.get()));
        // If any associated template explicitly declares locationIds and excludes locId, consider it a violation
        let violation = false;
        for (let i = 0; i < tmplSnaps.length; i++) {
            const s = tmplSnaps[i];
            if (!s.exists)
                continue;
            const tdata = s.data() || {};
            const ids = Array.isArray(tdata.locationIds) ? tdata.locationIds.map((x) => String(x)) : [];
            if (ids.length > 0 && !ids.includes(locId)) {
                violation = true;
                break;
            }
        }
        if (violation) {
            functions.logger.warn(`[enforceDailyChecklistOwnership] Deleting checklist ${snap.id} at ${orgId}/${locId} due to template/location mismatch`);
            await snap.ref.delete();
        }
    }
    catch (err) {
        functions.logger.error("enforceDailyChecklistOwnership error", err);
    }
    return null;
});
