import * as functions from "firebase-functions";
import {Firestore} from "@google-cloud/firestore";

const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

/**
 * Enforce that a newly created daily_checklist belongs to the location via template.locationIds.
 * If the checklist's template does not include the location, the document is deleted.
 */
export const enforceDailyChecklistOwnership = functions.firestore
  .document("organizations/{orgId}/locations/{locId}/daily_checklists/{checklistId}")
  .onCreate(async (snap, context) => {
    const orgId = context.params.orgId as string;
    const locId = context.params.locId as string;
    const data = (snap.data() || {}) as FirebaseFirestore.DocumentData;

    try {
      // Determine template id(s)
      const single = (data.checklistTemplateId || data.templateId || "").toString();
      const multi: string[] = Array.isArray(data.checklistTemplateIds) ? data.checklistTemplateIds : [];

      const candidates: string[] = [];
      if (single) candidates.push(single);
      for (const t of multi) if (typeof t === "string" && t) candidates.push(t);
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
        if (!s.exists) continue;
        const tdata = s.data() || {};
        const ids = Array.isArray(tdata.locationIds) ? tdata.locationIds.map((x: any) => String(x)) : [];
        if (ids.length > 0 && !ids.includes(locId)) {
          violation = true;
          break;
        }
      }

      if (violation) {
        functions.logger.warn(
          `[enforceDailyChecklistOwnership] Deleting checklist ${snap.id} at ${orgId}/${locId} due to template/location mismatch`,
        );
        await snap.ref.delete();
      }
    } catch (err) {
      functions.logger.error("enforceDailyChecklistOwnership error", err);
    }
    return null;
  });
