import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {DateTime} from "luxon";
import * as crypto from "crypto";
import {FirestoreTTLHelper} from "./firestoreTTLHelper";
import {Firestore} from "@google-cloud/firestore";

// Ensure we use the correct Firestore database (multi-db projects)
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";

// Use a Firestore instance explicitly bound to the target database
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

// Helper: add days to a JS Date
/**
 * Returns a Firestore Timestamp representing now + `days` days.
 * @param {number} days number of days to add
 * @return {admin.firestore.Timestamp}
 */
export function daysFromNow(days: number): admin.firestore.Timestamp {
  const now = Date.now();
  return admin.firestore.Timestamp.fromMillis(now + days * 24 * 60 * 60 * 1000);
}

// Deterministic checklist ID
/**
 * Deterministic checklist id for org/location/shift/date.
 * @param {string} orgId
 * @param {string} locationId
 * @param {string} shiftId
 * @param {string} dateString
 * @return {string}
 */
export function checklistIdFor(orgId: string, locationId: string, shiftId: string, dateString: string) {
  return `${orgId}_${locationId}_${shiftId}_${dateString}`;
}

// Main scheduled function: runs hourly
/**
 * Scheduled generator that runs hourly and creates daily checklists/tasks.
 */
export const scheduledDailyGenerator = functions.pubsub
    .schedule("every 1 hours")
    .timeZone("UTC")
    .onRun(async () => {
      const log = (obj: any) => functions.logger.info(JSON.stringify(obj));

      let createdChecklists = 0;
      let carriedTasks = 0;
      let skipped = 0;
      let errors = 0;

      try {
      // Load organizations
        const orgsSnap = await db.collection("organizations").get();
        for (const orgDoc of orgsSnap.docs) {
          const orgId = orgDoc.id;
          const orgData = orgDoc.data() || {};
          const orgRef = db.collection("organizations").doc(orgId);

          // Page locations for this org
          const locationsRef = db.collection("organizations").doc(orgId).collection("locations");
          const locationsSnap = await locationsRef.get();
          for (const locDoc of locationsSnap.docs) {
            const locationId = locDoc.id;
            const locationData = locDoc.data() || {};
            const timezone = locationData.timezone || orgData.timezone;
            if (!timezone) {
              functions.logger.warn(`Skipping location ${locationId} in org ${orgId}: no timezone`);
              continue;
            }

            // Compute local date
            const localNow = DateTime.now().setZone(timezone);
            const dateString = localNow.toISODate(); // YYYY-MM-DD or null
            const yesterdayString = localNow.minus({days: 1}).toISODate();

            // toISODate can return null in some edge cases; skip this location if so
            if (!dateString || !yesterdayString) {
              functions.logger.warn(`Skipping location ${locationId} in org ${orgId}: could not compute local date`);
              continue;
            }

            // Determine shifts - assume a collection under org or global 'shifts' where shift documents include locationIds
            // First try org-scoped shifts
            let shifts: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>[] = [];
            const orgShiftsRef = db.collection("organizations").doc(orgId).collection("shifts");
            const orgShiftsSnap = await orgShiftsRef.get();
            if (!orgShiftsSnap.empty) {
              shifts = orgShiftsSnap.docs.filter((d) => {
                const data = d.data() || {};
                const locIds = data.locationIds || data.locationId || [];
                if (Array.isArray(locIds)) return locIds.includes(locationId);
                return locIds === locationId;
              });
            } else {
            // Fallback to top-level shifts
              const topShiftsSnap = await db.collection("shifts").get();
              shifts = topShiftsSnap.docs.filter((d) => {
                const data = d.data() || {};
                const locIds = data.locationIds || data.locationId || [];
                if (Array.isArray(locIds)) return locIds.includes(locationId);
                return locIds === locationId;
              });
            }

            // For each shift, ensure checklist exists
            for (const shiftDoc of shifts) {
              const shiftId = shiftDoc.id;
              const checklistId = checklistIdFor(orgId, locationId, shiftId, dateString);
              const checklistRef = orgRef
                .collection("locations").doc(locationId)
                .collection("daily_checklists").doc(checklistId);

              const checklistSnap = await checklistRef.get();
              if (checklistSnap.exists) {
                skipped++;
                continue;
              }

              // Create checklist and initial tasks in a batch
              const batch = db.batch();
              const nowTs = admin.firestore.Timestamp.now();
              const expiresAt = daysFromNow(30);

              const checklistData = {
                id: checklistId,
                organizationId: orgId,
                locationId,
                shiftId,
                date: dateString,
                createdAt: nowTs,
                createdBy: "generator",
                expiresAt,
              } as Record<string, any>;

              FirestoreTTLHelper.batchSetWithTTL(batch, checklistRef, checklistData);

              // Optional: create tasks from templates for this shift at this location
              try {
                // Read the shift to find assigned checklistTemplateIds
                const shiftSnap = await orgRef.collection("shifts").doc(shiftId).get();
                const shiftData = shiftSnap.exists ? (shiftSnap.data() || {}) : {};
                const templateIds: string[] = Array.isArray(shiftData.checklistTemplateIds) ? shiftData.checklistTemplateIds : [];

                // For each templateId, verify it belongs to this location before seeding tasks
                for (const templateId of templateIds) {
                  try {
                    const tRef = orgRef.collection("checklist_templates").doc(templateId);
                    const tSnap = await tRef.get();
                    if (!tSnap.exists) continue;
                    const tData = tSnap.data() || {};
                    const locIds = Array.isArray(tData.locationIds) ? (tData.locationIds as string[]) : [];
                    if (locIds.length > 0 && !locIds.includes(locationId)) {
                      functions.logger.warn(`[dailyGenerator] Skip template ${templateId} for location ${locationId} (belongs to ${JSON.stringify(locIds)})`);
                      continue;
                    }

                    // Seed tasks from template's tasks subcollection
                    const tmplTasksSnap = await tRef.collection("tasks").orderBy("order").get();
                    let order = 0;
                    for (const taskDoc of tmplTasksSnap.docs) {
                      const t = taskDoc.data() || {};
                      const taskRef = checklistRef.collection("tasks").doc(`${templateId}_${taskDoc.id}`);
                      const taskData = {
                        title: t.title || t.name || t.description || "Task",
                        order: typeof t.order === "number" ? t.order : order,
                        createdAt: nowTs,
                        createdBy: "generator",
                        isComplete: false,
                        isCarryForwardEligible: t.isCarryForwardEligible === true || t.photoRequired === true,
                        templateId,
                      } as Record<string, any>;
                      FirestoreTTLHelper.batchSetWithTTL(batch, taskRef, taskData);
                      order++;
                    }
                  } catch (err) {
                    functions.logger.warn("template read error", err);
                  }
                }

                // Carry-forward: copy incomplete tasks from yesterday
                const yesterdayChecklistId = checklistIdFor(orgId, locationId, shiftId, yesterdayString);
                const yRef = orgRef
                  .collection("locations").doc(locationId)
                  .collection("daily_checklists").doc(yesterdayChecklistId);
                const yTasksSnap = await yRef.collection("tasks").where("isComplete", "==", false).get();
                for (const ytask of yTasksSnap.docs) {
                  const ydata = ytask.data() || {};
                  const newTaskRef = checklistRef.collection("tasks").doc();
                  const newTask = {
                    ...ydata,
                    createdAt: nowTs,
                    createdBy: "generator",
                    isCarryForward: true,
                    isCarryForwardEligible: ydata.isCarryForwardEligible === true,
                    carryForwardedFrom: `${yesterdayChecklistId}/${ytask.id}`,
                  };
                  // Ensure we don't carry non-eligible tasks
                  FirestoreTTLHelper.batchSetWithTTL(batch, newTaskRef, newTask);
                  carriedTasks++;
                }
              } catch {
                functions.logger.error("Template/carry-forward error");
              }

              // Commit batch (note: batch size assumed small per checklist)
              await batch.commit();
              createdChecklists++;
            }
          }
        }
      } catch {
        errors++;
        functions.logger.error("scheduledDailyGenerator error");
      }

      log({createdChecklists, carriedTasks, skipped, errors, ts: new Date().toISOString()});
      return null;
    });

// Export a helper to generate for a single org and date (used by tests/emulator)
/**
 * Generate checklists/tasks for a single organization/date - used by tests.
 * @param {string} orgId organization id
 * @param {string} dateString ISO date string (YYYY-MM-DD)
 */
export async function generateForOrgDate(orgId: string, dateString: string) {
  const orgRef = db.collection("organizations").doc(orgId);
  const orgSnap = await orgRef.get();
  const orgData = orgSnap.exists ? orgSnap.data() || {} : {};

  const locationsSnap = await orgRef.collection("locations").get();
  for (const locDoc of locationsSnap.docs) {
    const locationId = locDoc.id;
    // Get shifts scoped to this org
    const shiftsSnap = await orgRef.collection("shifts").get();
    const shifts = shiftsSnap.docs.filter((d) => {
      const data = d.data() || {};
      const locIds = data.locationIds || data.locationId || [];
      if (Array.isArray(locIds)) return locIds.includes(locationId);
      return locIds === locationId;
    });

    for (const shiftDoc of shifts) {
      const shiftId = shiftDoc.id;
      const shiftData = shiftDoc.data() || {};
      const templateIds: string[] = Array.isArray(shiftData.checklistTemplateIds) ?
        shiftData.checklistTemplateIds :
        [];

      // Create checklist once per shift/date and seed tasks from all templates, then run carry-forward once
      const checklistId = checklistIdFor(orgId, locationId, shiftId, dateString);
      const checklistRef = orgRef.collection("locations").doc(locationId).collection("daily_checklists").doc(checklistId);
      const nowTs = admin.firestore.Timestamp.now();
      const expiresAt = daysFromNow(30);

      await checklistRef.set({
        id: checklistId,
        checklistTemplateIds: templateIds,
        shiftId,
        locationId,
        organizationId: orgId,
        date: dateString,
        createdAt: nowTs,
        createdBy: "generator",
        expiresAt,
      }, {merge: true});

      // Seed tasks deterministically if none exist
      const tasksColl = checklistRef.collection("tasks");
      const existing = await tasksColl.limit(1).get();
      if (existing.empty) {
        for (const templateId of templateIds) {
          const tmplRef = orgRef.collection("checklist_templates").doc(templateId);
          try {
            const tmplTasksSnap = await tmplRef.collection("tasks").orderBy("order").get();
            for (const t of tmplTasksSnap.docs) {
              const tdata = t.data() || {};
              // Use template doc id prefixed with template id as task id to avoid collisions across templates
              const taskId = `${templateId}_${t.id}`;
              await tasksColl.doc(taskId).set({
                taskId,
                taskName: tdata.name || tdata.title || tdata.description || "Task",
                createdAt: nowTs,
                expiresAt,
                dueDate: tdata.dueDate || null,
                completed: false,
                isCarryForward: false,
                templateTaskId: t.id,
                templateId,
                organizationId: orgId,
                locationId: locationId,
                dateString: dateString,
                shiftId: shiftId,
                checklistId: checklistId,
                checklistTemplateId: templateId,
                order: tdata.order || 0,
              });
            }
          } catch {
            functions.logger.warn("template read error");
          }
        }
      }

      // Carry-forward from yesterday (parent-array and subcollection)
      const yesterdayString = DateTime.fromISO(dateString).minus({days: 1}).toISODate();
      if (!yesterdayString) continue;

      const ySnaps = await orgRef.collection("locations").doc(locationId).collection("daily_checklists").where("date", "==", yesterdayString).get();
      for (const yDoc of ySnaps.docs) {
        const ydata = yDoc.data() || {};
        // Merge parent-array tasks + subcollection tasks for carry-forward detection
        // Start with parent-array tasks if present
        const parentTasks = Array.isArray(ydata.tasks) ? ydata.tasks : [];
        // Also include subcollection tasks
        const subTasksSnap = await yDoc.ref.collection("tasks").get();
        const mergedTasks: any[] = [];
        for (const pt of parentTasks) {
          mergedTasks.push(pt);
        }
        for (const st of subTasksSnap.docs) {
          mergedTasks.push({...st.data(), taskId: st.id});
        }

        let anyChanges = false;
        const updatedParent = parentTasks.map((t: any) => ({...t}));
        const carryForwards: any[] = [];
        for (const taskMap of mergedTasks) {
          const isCompleted = taskMap.completed === true || taskMap.isCompleted === true;
          const carryAttempted = taskMap.carryForwardAttempted === true;
          if (!isCompleted && !carryAttempted) {
            anyChanges = true;
            // mark carryForwardAttempted in parent array if present
            const origId = taskMap.taskId || taskMap.id || null;
            carryForwards.push({originalTaskId: origId, taskName: taskMap.taskName || taskMap.name || "Unknown Task"});
            // update parent array entry if it was from parentTasks
            for (let i = 0; i < updatedParent.length; i++) {
              const entry = updatedParent[i];
              const entryId = entry["taskId"] || entry["id"];
              if (entryId && origId && entryId === origId) {
                updatedParent[i]["carryForwardAttempted"] = true;
              }
            }
          }
        }

        if (anyChanges && carryForwards.length > 0) {
          // update yesterday parent array
          try {
            await yDoc.ref.update({tasks: updatedParent, updatedAt: admin.firestore.Timestamp.now()});
          } catch {
            // ignore
          }

          // insert CF tasks into today's tasks subcollection
          const batch = db.batch();
          let i = 0;
          for (const cf of carryForwards) {
            const originalTaskId = cf.originalTaskId || crypto.randomBytes(8).toString("hex");
            const digest = crypto.createHash("sha1").update(`cf|${yDoc.id}|${originalTaskId}|${checklistId}`).digest("hex");
            const cfId = digest.substring(0, 16);
            const ref = checklistRef.collection("tasks").doc(cfId);
            const cfTaskData = {
              taskId: cfId,
              taskName: cf.taskName,
              createdAt: admin.firestore.Timestamp.now(),
              dueDate: admin.firestore.Timestamp.now(),
              completed: false,
              isCarryForward: true,
              originalDate: ydata.date,
              originalChecklistId: yDoc.id,
              originalTaskId: originalTaskId,
              carriedIntoDate: dateString,
              organizationId: orgId,
              locationId: locationId,
              shiftId: ydata.shiftId || "unknown",
              checklistId: checklistId,
              checklistTemplateId: ydata.checklistTemplateId || "unknown",
              checklistName: "Carry-forward Task",
              templateName: "Carry-forward Task",
              dateString: dateString,
              order: 100000 + i,
            };
            FirestoreTTLHelper.batchSetWithTTL(batch, ref, cfTaskData);
            i++;
          }
          await batch.commit();
        }
      }
    }
  }
}
