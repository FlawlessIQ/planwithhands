import * as functions from "firebase-functions";
import {Firestore} from "@google-cloud/firestore";

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

/**
 * Diagnose why checklists may be missing for a location on a date.
 * Body: { orgId: string, locationId: string, date: string (YYYY-MM-DD) }
 * Returns for each shift:
 *  - assignedTemplateIds
 *  - templatesBelongToLocation: {templateId: boolean}
 *  - existingDailyChecklists: [{id, checklistTemplateId, templateName}]
 */
export const diagnoseLocationChecklists = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const {orgId, locationId, date} = req.body || {};
    if (!orgId || !locationId || !date) {
      res.status(400).json({error: "orgId, locationId, and date are required"});
      return;
    }

    const orgRef = db.collection("organizations").doc(orgId);

    // Load all templates with locationIds
    const tmplSnap = await orgRef.collection("checklist_templates").get();
    const templateLocs = new Map<string, Set<string>>();
    for (const t of tmplSnap.docs) {
      const td = t.data() || {};
      const ids = Array.isArray(td.locationIds) ? td.locationIds.map((x: any) => String(x)) : [];
      templateLocs.set(t.id, new Set(ids));
    }

    // Load shifts that include this location
    const shiftsSnap = await orgRef.collection("shifts").where("locationIds", "array-contains", locationId).get();

    const results: any[] = [];

    for (const shiftDoc of shiftsSnap.docs) {
      const shift = shiftDoc.data() || {};
      const shiftId = shiftDoc.id;
      const assignedTemplateIds: string[] = Array.isArray(shift.checklistTemplateIds)
        ? (shift.checklistTemplateIds as string[]) : [];

      // Determine ownership
      const ownership: Record<string, boolean> = {};
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

    res.json({orgId, locationId, date, results});
  } catch (err: any) {
    functions.logger.error("diagnoseLocationChecklists error", err?.message || err);
    res.status(500).json({error: err?.message || String(err)});
  }
});
