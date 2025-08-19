const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

const MAX_BATCH_WRITES = Number(process.env.MAX_BATCH_WRITES || 400);

/**
 * Return today's date string in UTC (YYYY-MM-DD).
 * @return {string}
 */
function getTodayDateString() {
  return new Date().toISOString().slice(0, 10);
}

/**
 * Deterministically compute a task id from templateTaskId, checklistId and dateString.
 * Uses SHA-1 and returns the first 16 hex characters.
 * @param {string} templateTaskId
 * @param {string} checklistId
 * @param {string} dateString
 * @return {string}
 */
function deterministicTaskId(templateTaskId, checklistId, dateString) {
  const digest = crypto.createHash("sha1").update(`${templateTaskId}|${checklistId}|${dateString}`).digest("hex");
  return digest.substring(0, 16);
}

exports.syncTodayTasksOnTemplateChange = functions
    .region(process.env.FUNCTION_REGION || "us-central1")
    .firestore.document("organizations/{orgId}/checklist_templates/{templateId}")
    .onWrite(async (change, context) => {
      const orgId = context.params.orgId;
      const templateId = context.params.templateId;

      const beforeData = change.before.exists ? change.before.data() : {};
      const afterData = change.after.exists ? change.after.data() : {};

      const beforeTasks = Array.isArray(beforeData.tasks) ? beforeData.tasks : [];
      const afterTasks = Array.isArray(afterData.tasks) ? afterData.tasks : [];

      // Quick exit if tasks didn't change
      try {
        if (JSON.stringify(beforeTasks || []) === JSON.stringify(afterTasks || [])) {
          console.log(`[syncTodayTasksOnTemplateChange] template ${templateId} tasks unchanged — exiting`);
          return null;
        }
      } catch (err) {
        console.warn("[syncTodayTasksOnTemplateChange] error serializing tasks, continuing", err);
      }

      const dateString = getTodayDateString();
      console.log(`[syncTodayTasksOnTemplateChange] template ${templateId} changed; syncing tasks for date ${dateString} (org ${orgId})`);

      const db = admin.firestore();

      const checklistQuery = db
          .collectionGroup("daily_checklists")
          .where("organizationId", "==", orgId)
          .where("templateId", "==", templateId)
          .where("dateString", "==", dateString);

      const checklistSnap = await checklistQuery.get();
      const checklists = checklistSnap.docs || [];
      console.log(`[syncTodayTasksOnTemplateChange] found ${checklists.length} daily_checklists to scan`);

      let totalInserted = 0;
      const commitBatch = async (batch) => {
        if (!batch) return;
        try {
          await batch.commit();
        } catch (err) {
          console.error("[syncTodayTasksOnTemplateChange] batch commit failed", err);
          throw err;
        }
      };

      let batch = db.batch();
      let currentBatchWrites = 0;

      for (const checklistDoc of checklists) {
        try {
          const checklistRef = checklistDoc.ref;
          const checklistId = checklistRef.id;
          const checklistData = checklistDoc.data() || {};
          const locationId = (checklistRef.parent && checklistRef.parent.parent) ? checklistRef.parent.parent.id : (checklistData.locationId || null);
          const shiftId = checklistData.shiftId || null;

          // get existing task ids via listDocuments to avoid reads
          let existingTaskIds = new Set();
          try {
            const taskDocRefs = await checklistRef.collection("tasks").listDocuments();
            existingTaskIds = new Set(taskDocRefs.map((r) => r.id));
          } catch (err) {
            console.warn(`[syncTodayTasksOnTemplateChange] listDocuments failed for ${checklistRef.path}, falling back to get():`, err);
            const tasksSnap = await checklistRef.collection("tasks").get();
            existingTaskIds = new Set(tasksSnap.docs.map((d) => d.id));
          }

          for (const t of afterTasks) {
            const templateTaskId = (t && (t.id || t.taskId || t.templateTaskId || "")).toString();
            if (!templateTaskId) {
              console.warn(`[syncTodayTasksOnTemplateChange] skipping template task missing id in template ${templateId}`);
              continue;
            }

            const taskName = (t && (t.taskName || t.title || t.name || "")).toString();
            const photoRequired = Boolean(t && t.photoRequired);
            const dueDate = admin.firestore.Timestamp.fromDate(new Date(`${dateString}T00:00:00Z`));

            const taskId = deterministicTaskId(templateTaskId, checklistId, dateString);
            if (existingTaskIds.has(taskId)) continue; // skip existing

            const taskDocRef = checklistRef.collection("tasks").doc(taskId);
            const docData = {
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
          console.error(`[syncTodayTasksOnTemplateChange] error processing checklist ${checklistDoc.ref.path}:`, err);
        }
      }

      // commit remaining
      if (currentBatchWrites > 0) {
        await commitBatch(batch);
      }

      console.log(`[syncTodayTasksOnTemplateChange] completed. checklists scanned=${checklists.length}, new tasks inserted=${totalInserted}`);
      return {scanned: checklists.length, inserted: totalInserted};
    });
