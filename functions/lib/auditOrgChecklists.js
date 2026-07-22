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
exports.auditOrgChecklists = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("@google-cloud/firestore");
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
/**
 * Audits (and optionally fixes) daily_checklists under organizations/{orgId}/locations/* for a date.
 * Criteria: checklistTemplateId must belong to the checklist's location (template.locationIds includes locationId).
 * Body: { orgId: string, date: string (YYYY-MM-DD), applyFix?: boolean }
 */
exports.auditOrgChecklists = functions.https.onRequest(async (req, res) => {
    try {
        if (req.method !== "POST") {
            res.status(405).send("Method Not Allowed");
            return;
        }
        const { orgId, date, applyFix = false } = req.body || {};
        if (!orgId || !date) {
            res.status(400).json({ error: "orgId and date (YYYY-MM-DD) are required" });
            return;
        }
        // Load locations
        const orgRef = db.collection("organizations").doc(orgId);
        const locSnap = await orgRef.collection("locations").get();
        const locations = locSnap.docs.map((d) => ({ id: d.id, data: d.data() || {} }));
        // Load templates map with locationIds
        const tmplSnap = await orgRef.collection("checklist_templates").get();
        const templateLocs = new Map();
        for (const t of tmplSnap.docs) {
            const td = t.data() || {};
            const ids = Array.isArray(td.locationIds) ? td.locationIds.map((x) => String(x)) : [];
            templateLocs.set(t.id, new Set(ids));
        }
        const issues = [];
        const deletes = [];
        // Inspect checklists for each location
        for (const loc of locations) {
            const locationId = loc.id;
            const dlSnap = await orgRef
                .collection("locations").doc(locationId)
                .collection("daily_checklists")
                .where("date", "==", date)
                .get();
            for (const doc of dlSnap.docs) {
                const data = doc.data() || {};
                const templateId = String(data.checklistTemplateId || "");
                if (!templateId)
                    continue; // some schemas store template set on tasks
                const allowed = templateLocs.get(templateId);
                if (allowed && allowed.size > 0 && !allowed.has(locationId)) {
                    issues.push({ id: doc.id, locationId, templateId });
                    if (applyFix)
                        deletes.push(doc.ref);
                }
            }
        }
        // Apply deletion if requested
        if (applyFix && deletes.length > 0) {
            const batch = db.batch();
            for (const ref of deletes)
                batch.delete(ref);
            await batch.commit();
        }
        res.json({ orgId, date, issues: issues.length, deleted: applyFix ? deletes.length : 0, details: issues.slice(0, 50) });
    }
    catch (err) {
        functions.logger.error("auditOrgChecklists error", err?.message || err);
        res.status(500).json({ error: err?.message || String(err) });
    }
});
