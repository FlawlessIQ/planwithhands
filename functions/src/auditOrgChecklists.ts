import * as functions from "firebase-functions";
import {Firestore} from "@google-cloud/firestore";

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

/**
 * Audits (and optionally fixes) daily_checklists under organizations/{orgId}/locations/* for a date.
 * Criteria: checklistTemplateId must belong to the checklist's location (template.locationIds includes locationId).
 * Body: { orgId: string, date: string (YYYY-MM-DD), applyFix?: boolean }
 */
export const auditOrgChecklists = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const {orgId, date, applyFix = false} = req.body || {};
    if (!orgId || !date) {
      res.status(400).json({error: "orgId and date (YYYY-MM-DD) are required"});
      return;
    }

    // Load locations
    const orgRef = db.collection("organizations").doc(orgId);
    const locSnap = await orgRef.collection("locations").get();
    const locations = locSnap.docs.map((d) => ({id: d.id, data: d.data() || {}}));

    // Load templates map with locationIds
    const tmplSnap = await orgRef.collection("checklist_templates").get();
    const templateLocs = new Map<string, Set<string>>();
    for (const t of tmplSnap.docs) {
      const td = t.data() || {};
      const ids = Array.isArray(td.locationIds) ? td.locationIds.map((x: any) => String(x)) : [];
      templateLocs.set(t.id, new Set(ids));
    }

    const issues: any[] = [];
    const deletes: FirebaseFirestore.DocumentReference[] = [];

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
        if (!templateId) continue; // some schemas store template set on tasks

        const allowed = templateLocs.get(templateId);
        if (allowed && allowed.size > 0 && !allowed.has(locationId)) {
          issues.push({id: doc.id, locationId, templateId});
          if (applyFix) deletes.push(doc.ref);
        }
      }
    }

    // Apply deletion if requested
    if (applyFix && deletes.length > 0) {
      const batch = db.batch();
      for (const ref of deletes) batch.delete(ref);
      await batch.commit();
    }

    res.json({orgId, date, issues: issues.length, deleted: applyFix ? deletes.length : 0, details: issues.slice(0, 50)});
  } catch (err: any) {
    functions.logger.error("auditOrgChecklists error", err?.message || err);
    res.status(500).json({error: err?.message || String(err)});
  }
});
