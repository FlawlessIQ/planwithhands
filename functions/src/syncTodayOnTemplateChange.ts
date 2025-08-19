import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {dateStringUTC, deterministicTaskId} from "./idHelpers";

const MAX_BATCH_WRITES = Number(process.env.MAX_BATCH_WRITES || 400);

export const syncTodayOnTemplateChange = functions
    .region(process.env.FUNCTION_REGION || "us-central1")
    .firestore.document("organizations/{orgId}/checklist_templates/{templateId}")
    .onWrite(async (change, context) => {
      const orgId = context.params.orgId as string;
      const templateId = context.params.templateId as string;

      const beforeData = change.before.exists ?
      (change.before.data() as FirebaseFirestore.DocumentData) :
      ({} as FirebaseFirestore.DocumentData);

      const afterData = change.after.exists ?
      (change.after.data() as FirebaseFirestore.DocumentData) :
      ({} as FirebaseFirestore.DocumentData);

      const beforeTasks = Array.isArray(beforeData.tasks) ?
      (beforeData.tasks as any[]) :
      [];

      const afterTasks = Array.isArray(afterData.tasks) ?
      (afterData.tasks as any[]) :
      [];

      try {
        const beforeJson = JSON.stringify(beforeTasks || []);
        const afterJson = JSON.stringify(afterTasks || []);

        if (beforeJson === afterJson) {
          console.log(
              "[syncTodayOnTemplateChange] template",
              templateId,
              "tasks unchanged — exiting",
          );
          return null;
        }
      } catch (err) {
        console.warn(
            "[syncTodayOnTemplateChange] error serializing tasks, continuing",
            err,
        );
      }

      const dateString = dateStringUTC(new Date());
      console.log(
          "[syncTodayOnTemplateChange] template",
          templateId,
          "changed; syncing tasks for date",
          dateString,
          "(org", orgId + ")",
      );

      const db = admin.firestore();

      const checklistQuery = db
          .collectionGroup("daily_checklists")
          .where("organizationId", "==", orgId)
          .where("templateId", "==", templateId)
          .where("dateString", "==", dateString);

      const checklistSnap = await checklistQuery.get();
      const checklists = checklistSnap.docs || [];

      console.log(
          "[syncTodayOnTemplateChange] found",
          checklists.length,
          "daily_checklists to scan",
      );

      let totalInserted = 0;

      const commitBatch = async (batch: FirebaseFirestore.WriteBatch) => {
        if (!batch) return;
        try {
          await batch.commit();
        } catch (err) {
          console.error("[syncTodayOnTemplateChange] batch commit failed", err);
          throw err;
        }
      };

      let batch = db.batch();
      let currentBatchWrites = 0;

      for (const checklistDoc of checklists) {
        try {
          const checklistRef = checklistDoc.ref as FirebaseFirestore.DocumentReference<FirebaseFirestore.DocumentData>;
          const checklistId = checklistRef.id as string;
          const checklistData = checklistDoc.data() || {};

          const locationId = checklistRef.parent && checklistRef.parent.parent ?
          checklistRef.parent.parent.id :
          (checklistData.locationId || null);

          const shiftId = checklistData.shiftId || null;

          // get existing task ids via listDocuments to avoid reads
          let existingTaskIds = new Set<string>();
          try {
            const taskDocRefs = await checklistRef.collection("tasks").listDocuments();
            existingTaskIds = new Set(taskDocRefs.map((r) => r.id));
          } catch (err) {
            console.warn(
                "[syncTodayOnTemplateChange] listDocuments failed for",
                checklistRef.path,
                "falling back to get():",
                err,
            );
            const tasksSnap = await checklistRef.collection("tasks").get();
            existingTaskIds = new Set(tasksSnap.docs.map((d) => d.id));
          }

          const midnightIso = `${dateString}T00:00:00Z`;

          for (const t of afterTasks) {
            const templateTaskId = (t && (t.id || t.taskId || t.templateTaskId || "")).toString();
            if (!templateTaskId) {
              console.warn("[syncTodayOnTemplateChange] skipping template task missing id in template", templateId);
              continue;
            }

            const taskName = (t && (t.taskName || t.title || t.name || "")).toString();
            const photoRequired = Boolean(t && t.photoRequired);
            const dueDate = admin.firestore.Timestamp.fromDate(new Date(midnightIso));

            const taskId = deterministicTaskId(templateTaskId, checklistId, dateString);
            if (existingTaskIds.has(taskId)) continue; // skip existing

            const taskDocRef = checklistRef.collection("tasks").doc(taskId);
            const docData: FirebaseFirestore.DocumentData = {
              taskId,
              templateTaskId,
              taskName,
              completed: false,
              photoRequired,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              dueDate,
              isCarryForward: false,
              organizationId: orgId,
              locationId,
              checklistId,
              shiftId,
              templateId,
              dateString,
            };

            batch.set(taskDocRef, docData, {merge: true});
            currentBatchWrites += 1;
            totalInserted += 1;

            if (currentBatchWrites >= MAX_BATCH_WRITES) {
              await commitBatch(batch);
              batch = db.batch();
              currentBatchWrites = 0;
            }
          }
        } catch (err) {
          console.error("[syncTodayOnTemplateChange] error processing checklist", checklistDoc.ref.path, err);
        }
      }

      // commit remaining
      if (currentBatchWrites > 0) {
        await commitBatch(batch);
      }

      console.log(
          "[syncTodayOnTemplateChange] completed. checklists scanned=",
          checklists.length,
          ", new tasks inserted=",
          totalInserted,
      );

      return {scanned: checklists.length, inserted: totalInserted};
    });
