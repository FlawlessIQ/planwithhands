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
exports.diagnoseLocationChecklists = void 0;
const functions = __importStar(require("firebase-functions"));
const firestore_1 = require("@google-cloud/firestore");
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
/**
 * Diagnose why checklists may be missing for a location on a date.
 * Body: { orgId: string, locationId: string, date: string (YYYY-MM-DD) }
 * Returns for each shift:
 *  - assignedTemplateIds
 *  - templatesBelongToLocation: {templateId: boolean}
 *  - existingDailyChecklists: [{id, checklistTemplateId, templateName}]
 */
exports.diagnoseLocationChecklists = functions.https.onRequest(async (req, res) => {
    try {
        if (req.method !== "POST") {
            res.status(405).send("Method Not Allowed");
            return;
        }
        const { orgId, locationId, date } = req.body || {};
        if (!orgId || !locationId || !date) {
            res.status(400).json({ error: "orgId, locationId, and date are required" });
            return;
        }
        const orgRef = db.collection("organizations").doc(orgId);
        // Load all templates with locationIds
        const tmplSnap = await orgRef.collection("checklist_templates").get();
        const templateLocs = new Map();
        for (const t of tmplSnap.docs) {
            const td = t.data() || {};
            const ids = Array.isArray(td.locationIds) ? td.locationIds.map((x) => String(x)) : [];
            templateLocs.set(t.id, new Set(ids));
        }
        // Load shifts that include this location
        const shiftsSnap = await orgRef.collection("shifts").where("locationIds", "array-contains", locationId).get();
        const results = [];
        for (const shiftDoc of shiftsSnap.docs) {
            const shift = shiftDoc.data() || {};
            const shiftId = shiftDoc.id;
            const assignedTemplateIds = Array.isArray(shift.checklistTemplateIds)
                ? shift.checklistTemplateIds : [];
            // Determine ownership
            const ownership = {};
            for (const tid of assignedTemplateIds) {
                const locs = templateLocs.get(tid);
                ownership[tid] = !!(locs && locs.size > 0 && locs.has(locationId));
            }
            // Existing daily checklists for this shift/date/location
            const dailySnap = await orgRef
                .collection("locations").doc(locationId)
                .collection("daily_checklists")
                .where("shiftId", "==", shiftId)
                .where("date", "==", date)
                .get();
            const existing = dailySnap.docs.map(d => ({
                id: d.id,
                checklistTemplateId: String(d.get("checklistTemplateId") || ""),
                templateName: d.get("templateName") || null,
            }));
            // Summarize missing by comparing assigned templates vs existing docs
            const existingTemplateIds = new Set(existing.map(e => e.checklistTemplateId).filter(Boolean));
            const missingTemplates = assignedTemplateIds.filter(t => !existingTemplateIds.has(t));
            results.push({
                shiftId,
                shiftName: shift.shiftName || shift.name || shiftId,
                assignedTemplateIds,
                templatesBelongToLocation: ownership,
                existingDailyChecklists: existing,
                missingTemplates,
            });
        }
        res.json({ orgId, locationId, date, results });
    }
    catch (err) {
        functions.logger.error("diagnoseLocationChecklists error", err?.message || err);
        res.status(500).json({ error: err?.message || String(err) });
    }
});
