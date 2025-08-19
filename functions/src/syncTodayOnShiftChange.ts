import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {dateStringUTC, deterministicTaskId} from "./idHelpers";

const MAX_BATCH_WRITES = Number(process.env.MAX_BATCH_WRITES || 400);

export const syncTodayOnShiftChange = functions
    .region(process.env.FUNCTION_REGION || "us-central1")
    .firestore.document("organizations/{orgId}/locations/{locId}/shifts/{shiftId}")
    .onUpdate(async (change, context) => {
      const orgId = context.params.orgId as string;
      const locId = context.params.locId as string;
      const shiftId = context.params.shiftId as string;

      const beforeData = (change.before.data() || {}) as FirebaseFirestore.DocumentData;
      const afterData = (change.after.data() || {}) as FirebaseFirestore.DocumentData;

      const beforeTemplateIds: string[] = Array.isArray(beforeData.checklistTemplateIds) ?
      (beforeData.checklistTemplateIds as string[]) :
      [];
      const afterTemplateIds: string[] = Array.isArray(afterData.checklistTemplateIds) ?
      (afterData.checklistTemplateIds as string[]) :
      [];

      const beforeStart = beforeData.startTime || null;
      const beforeEnd = beforeData.endTime || null;
      const afterStart = afterData.startTime || null;
      const afterEnd = afterData.endTime || null;

      // If templates and shift times unchanged, no-op
      const templatesEqual = JSON.stringify(beforeTemplateIds) === JSON.stringify(afterTemplateIds);
      const timesEqual = JSON.stringify({beforeStart, beforeEnd}) === JSON.stringify({afterStart, afterEnd});

      if (templatesEqual && timesEqual) {
        console.log("[syncTodayOnShiftChange] no relevant changes for shift", shiftId);
        return null;
      }

      const dateString = dateStringUTC(new Date());
      console.log("[syncTodayOnShiftChange] shift changed, syncing today checks for", dateString, "shift", shiftId);

      const db = admin.firestore();
      const dailyChecklistsColl = db.collection(`organizations/${orgId}/locations/${locId}/daily_checklists`);

      // Find today's checklist(s) for this shift
      const checklistQuery = dailyChecklistsColl
          .where("shiftId", "==", shiftId)
          .where("dateString", "==", dateString);

      const checklistSnap = await checklistQuery.get();
      const checklists = checklistSnap.docs || [];

      // If none exist, we'll create one checklist and populate tasks from templates
      const templatesToProcess = afterTemplateIds;

      let totalInserted = 0;
      let totalChecklistsCreated = 0;

      const commitBatch = async (batch: FirebaseFirestore.WriteBatch) => {
        if (!batch) return;
        try {
          await batch.commit();
        } catch (err) {
          console.error("[syncTodayOnShiftChange] batch commit failed", err);
          throw err;
        }
      };

      let batch = db.batch();
      let currentBatchWrites = 0;

      // Helper to ensure tasks from a template are present on a checklist
      const ensureTemplateTasksOnChecklist = async (
          checklistRef: FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>,
          checklistId: string,
          templateId: string,
      ) => {
      // get existing task ids via listDocuments to avoid reads
        let existingTaskIds = new Set<string>();
        try {
          const taskDocRefs = await checklistRef.collection("tasks").listDocuments();
          existingTaskIds = new Set(taskDocRefs.map((r) => r.id));
        } catch (err) {
          console.warn("[syncTodayOnShiftChange] listDocuments failed, falling back to get():", err);
          const tasksSnap = await checklistRef.collection("tasks").get();
          existingTaskIds = new Set(tasksSnap.docs.map((d) => d.id));
        }

        // fetch template doc
        const templateRef = db.doc(`organizations/${orgId}/checklist_templates/${templateId}`);
        const templateSnap = await templateRef.get();
        if (!templateSnap.exists) {
          console.warn("[syncTodayOnShiftChange] template not found", templateId);
          return 0;
        }

        const templateData = templateSnap.data() || {};
        const templateTasks: any[] = Array.isArray(templateData.tasks) ? templateData.tasks : [];

        let inserted = 0;
        const midnightIso = `${dateString}T00:00:00Z`;

        for (const t of templateTasks) {
          const templateTaskId = (t && (t.id || t.taskId || t.templateTaskId || "")).toString();
          if (!templateTaskId) continue;

          const taskId = deterministicTaskId(templateTaskId, checklistId, dateString);
          if (existingTaskIds.has(taskId)) continue; // preserve existing

          const taskName = (t && (t.taskName || t.title || t.name || "")).toString();
          const photoRequired = Boolean(t && t.photoRequired);
          const dueDate = admin.firestore.Timestamp.fromDate(new Date(midnightIso));

          const taskDocRef = checklistRef.collection("tasks").doc(taskId);
          const docData: FirebaseFirestore.DocumentData = {
            taskId,
            templateTaskId,
            taskName,
            completed: false,
            photoRequired,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            // TTL: expire tasks after 30 days
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)),
            dueDate,
            isCarryForward: false,
            organizationId: orgId,
            locationId: locId,
            checklistId,
            shiftId,
            templateId,
            dateString,
          };

          batch.set(taskDocRef, docData, {merge: true});
          currentBatchWrites += 1;
          inserted += 1;
          totalInserted += 1;

          if (currentBatchWrites >= MAX_BATCH_WRITES) {
            await commitBatch(batch);
            batch = db.batch();
            currentBatchWrites = 0;
          }
        }

        return inserted;
      };

      if (checklists.length === 0) {
      // create a new checklist for the shift
        const newChecklistRef = dailyChecklistsColl.doc();
        const checklistId = newChecklistRef.id;
        const checklistDoc: FirebaseFirestore.DocumentData = {
          checklistId,
          organizationId: orgId,
          locationId: locId,
          shiftId,
          dateString,
          checklistTemplateIds: templatesToProcess,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          // TTL for ephemeral checklist parents
          expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)),
        };

        batch.set(newChecklistRef, checklistDoc, {merge: true});
        currentBatchWrites += 1;
        totalChecklistsCreated += 1;

        // add tasks from all templates
        for (const templateId of templatesToProcess) {
          await ensureTemplateTasksOnChecklist(newChecklistRef, checklistId, templateId);
        }
      } else {
      // ensure each existing checklist has tasks from all templates
        for (const checklistDoc of checklists) {
          const checklistRef = checklistDoc.ref;
          const checklistId = checklistRef.id;
          for (const templateId of templatesToProcess) {
            await ensureTemplateTasksOnChecklist(checklistRef, checklistId, templateId);
          }
        }
      }

      // commit remaining
      if (currentBatchWrites > 0) {
        await commitBatch(batch);
      }

      console.log("[syncTodayOnShiftChange] completed. created=", totalChecklistsCreated, "inserted=", totalInserted);
      return {created: totalChecklistsCreated, inserted: totalInserted};
    });
