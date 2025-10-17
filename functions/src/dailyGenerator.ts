import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {DateTime} from "luxon";
import * as crypto from "crypto";
import {FirestoreTTLHelper} from "./firestoreTTLHelper";
import {Firestore} from "@google-cloud/firestore";

// Ensure we use the correct Firestore database (multi-db projects)
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";

// Use a Firestore instance explicitly bound to the target database
const db = new Firestore({databaseId: FIRESTORE_DATABASE_ID});

type ValidTemplate = {
  id: string;
  name: string;
};

/**
 * Returns a Firestore Timestamp representing now + `days` days.
 * @param {number} days number of days to add
 * @return {admin.firestore.Timestamp}
 */
export function daysFromNow(days: number): admin.firestore.Timestamp {
  const now = Date.now();
  return admin.firestore.Timestamp.fromMillis(now + days * 24 * 60 * 60 * 1000);
}

/**
 * Deterministic checklist id for org/location/shift/template/date.
 * CRITICAL FIX: Now includes templateId to ensure each template gets its own checklist
 * @param {string} orgId organization id
 * @param {string} locationId location id
 * @param {string} shiftId shift id
 * @param {string} templateId template id
 * @param {string} dateString ISO date string (YYYY-MM-DD)
 * @return {string}
 */
export function checklistIdFor(orgId: string, locationId: string, shiftId: string, templateId: string, dateString: string): string {
  return `${orgId}_${locationId}_${shiftId}_${templateId}_${dateString}`;
}

async function fetchShiftsForLocation(
  orgRef: FirebaseFirestore.DocumentReference,
  locationId: string,
): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const orgShiftsSnap = await orgRef.collection("shifts").get();
  let candidateDocs: FirebaseFirestore.QueryDocumentSnapshot[] = orgShiftsSnap.docs;

  if (candidateDocs.length === 0) {
    const topShiftsSnap = await db.collection("shifts").get();
    candidateDocs = topShiftsSnap.docs;
  }

  return candidateDocs.filter((d) => {
    const data = d.data() || {};
    const locIds = data.locationIds || data.locationId || [];
    if (Array.isArray(locIds)) return locIds.includes(locationId);
    return locIds === locationId;
  });
}

async function fetchValidTemplates(
  orgRef: FirebaseFirestore.DocumentReference,
  locationId: string,
  templateIds: string[],
  logPrefix: string,
): Promise<ValidTemplate[]> {
  const validTemplates: ValidTemplate[] = [];

  for (const templateId of templateIds) {
    try {
      const tRef = orgRef.collection("checklist_templates").doc(templateId);
      const tSnap = await tRef.get();
      if (!tSnap.exists) {
        functions.logger.warn(`${logPrefix} Skip non-existent template ${templateId}`);
        continue;
      }

      const tData = tSnap.data() || {};
      const templateName = (tData.name || "").toString().trim();
      if (!templateName || templateName.toLowerCase() === "unknown template") {
        functions.logger.warn(`${logPrefix} Skip template ${templateId} with invalid name: "${templateName}"`);
        continue;
      }

      const locIds = Array.isArray(tData.locationIds) ? (tData.locationIds as string[]) : [];
      if (locIds.length > 0 && !locIds.includes(locationId)) {
        functions.logger.warn(`${logPrefix} Skip template ${templateId} for location ${locationId} (belongs to ${JSON.stringify(locIds)})`);
        continue;
      }

      validTemplates.push({id: templateId, name: templateName});
    } catch (err) {
      functions.logger.warn(`${logPrefix} Error validating template ${templateId}:`, err);
    }
  }

  return validTemplates;
}

interface SeedTemplateTasksParams {
  batch: FirebaseFirestore.WriteBatch;
  orgRef: FirebaseFirestore.DocumentReference;
  checklistRef: FirebaseFirestore.DocumentReference;
  template: ValidTemplate;
  shiftId: string;
  orgId: string;
  locationId: string;
  checklistId: string;
  dateString: string;
  nowTs: admin.firestore.Timestamp;
}

async function seedTemplateTasks(params: SeedTemplateTasksParams): Promise<number> {
  const {batch, orgRef, checklistRef, template, shiftId, orgId, locationId, checklistId, dateString, nowTs} = params;

  let created = 0;
  try {
    const tRef = orgRef.collection("checklist_templates").doc(template.id);
    const tmplTasksSnap = await tRef.collection("tasks").orderBy("order").get();
    let order = 0;
    for (const taskDoc of tmplTasksSnap.docs) {
      const t = taskDoc.data() || {};
      const taskId = `${template.id}_${taskDoc.id}`;
      const taskRef = checklistRef.collection("tasks").doc(taskId);
      const taskData = {
        taskId,
        taskName: t.name || t.title || t.description || "Task",
        createdAt: nowTs,
        createdBy: "generator",
        completed: false,
        isCarryForward: false,
        isCarryForwardEligible: t.isCarryForwardEligible === true || t.photoRequired === true,
        templateTaskId: taskDoc.id,
        templateId: template.id,
        templateName: template.name,
        organizationId: orgId,
        locationId,
        shiftId,
        checklistId,
        checklistTemplateId: template.id,
        checklistName: template.name,
        dateString,
        order: typeof t.order === "number" ? t.order : order,
      } as Record<string, any>;

      const taskSnap = await taskRef.get();
      if (!taskSnap.exists) {
        FirestoreTTLHelper.batchSetWithTTL(batch, taskRef, taskData);
        created++;
      } else {
        batch.set(taskRef, {
          templateName: template.name,
          checklistName: template.name,
          templateId: template.id,
          checklistTemplateId: template.id,
        }, {merge: true});
      }
      order++;
    }
  } catch (err) {
    functions.logger.warn("template read error", err);
  }

  return created;
}

interface CarryForwardParams {
  batch: FirebaseFirestore.WriteBatch;
  orgRef: FirebaseFirestore.DocumentReference;
  checklistRef: FirebaseFirestore.DocumentReference;
  template: ValidTemplate;
  shiftId: string;
  orgId: string;
  locationId: string;
  checklistId: string;
  currentDateString: string;
  yesterdayString: string | null;
  nowTs: admin.firestore.Timestamp;
  totalTemplatesForShift: number;
}

async function carryForwardTasks(params: CarryForwardParams): Promise<number> {
  const {
    batch,
    orgRef,
    checklistRef,
    template,
    shiftId,
    orgId,
    locationId,
    checklistId,
    currentDateString,
    yesterdayString,
    nowTs,
    totalTemplatesForShift,
  } = params;

  if (!yesterdayString) {
    return 0;
  }

  const candidateIds: string[] = [];
  const primaryId = checklistIdFor(orgId, locationId, shiftId, template.id, yesterdayString);
  candidateIds.push(primaryId);

  let carried = 0;
  const processedOrigins = new Set<string>();
  const processedTaskNames = new Set<string>(); // Prevent duplicate task names from being carried forward

  for (const candidateId of candidateIds) {
    const yRef = orgRef
      .collection("locations").doc(locationId)
      .collection("daily_checklists").doc(candidateId);

    const yTasksSnap = await yRef.collection("tasks").get();
    if (yTasksSnap.empty) {
      continue;
    }

    for (const ytask of yTasksSnap.docs) {
      const ydata = ytask.data() || {};
      const isCompleted = ydata.completed === true || ydata.isComplete === true;
      // Skip already-completed tasks
      if (isCompleted) {
        continue;
      }

      // IMPORTANT: don't carry-forward tasks that are themselves carry-forwards.
      // Allow only original tasks from yesterday to be carried into today. This
      // prevents chaining where a carried task from an earlier run is carried
      // forward again and again, creating duplicate carry-forwards.
      if (ydata.isCarryForward === true) {
        continue;
      }

      // CRITICAL FIX: Skip tasks that are already carry-forwards to prevent cascading duplicates
      // Only carry forward original tasks from templates, not previously carried-forward tasks
      if (ydata.isCarryForward === true) {
        continue;
      }

      const matchesTemplate = (ydata.checklistTemplateId && ydata.checklistTemplateId === template.id) ||
        (ydata.templateId && ydata.templateId === template.id);
      if (!matchesTemplate) {
        continue;
      }

      const originalTaskId = ydata.taskId || ytask.id;
      const originKey = `${candidateId}/${originalTaskId}`;
      if (processedOrigins.has(originKey)) {
        continue;
      }
      processedOrigins.add(originKey);

      const taskName = ydata.taskName || ydata.name || ydata.title || "Task";
      
      // CRITICAL FIX: Prevent duplicate carry-forwards with the same task name
      if (processedTaskNames.has(taskName)) {
        continue;
      }
      processedTaskNames.add(taskName);
      
      const cfDigest = crypto.createHash("sha1").update(`cf|${candidateId}|${originalTaskId}|${checklistId}`).digest("hex");
      const cfId = cfDigest.substring(0, 16);
      const newTaskRef = checklistRef.collection("tasks").doc(cfId);

      // Safety: if the deterministic carry-forward doc already exists, skip creating it.
      // This guards against race conditions and duplicate writes across multiple runs.
      try {
        const existing = await newTaskRef.get();
        if (existing.exists) {
          // Already present (possibly created by a previous run) - don't duplicate
          continue;
        }
      } catch (err) {
        // If a read fails, log and proceed to attempt creation (we don't want to
        // silently stop producing carry-forwards). The higher-level logic/tests
        // will catch anomalies.
        // eslint-disable-next-line no-console
        console.warn(`carryForwardTasks: could not check existing carry-forward doc ${cfId}`, err);
      }
      const newTask = {
        taskId: cfId,
        taskName,
        createdAt: nowTs,
        createdBy: "generator",
        completed: false,
        isCarryForward: true,
        isCarryForwardEligible: ydata.isCarryForwardEligible === true,
        originalDate: yesterdayString,
        originalChecklistId: candidateId,
        originalTaskId,
        carryForwardedFrom: `${candidateId}/${originalTaskId}`,
        organizationId: orgId,
        locationId,
        shiftId,
        checklistId,
        checklistTemplateId: template.id,
        templateName: template.name,
        dateString: currentDateString,
        order: typeof ydata.order === "number" ? ydata.order : 100000,
      } as Record<string, any>;
      FirestoreTTLHelper.batchSetWithTTL(batch, newTaskRef, newTask);
      carried++;
    }
  }

  return carried;
}

async function createChecklistForTemplate(params: {
  orgRef: FirebaseFirestore.DocumentReference;
  locationId: string;
  orgId: string;
  dateString: string;
  yesterdayString: string | null;
  shiftId: string;
  template: ValidTemplate;
  stats: {
    createdChecklists: number;
    carriedTasks: number;
    skipped: number;
  };
  logPrefix: string;
  totalTemplatesForShift: number;
}): Promise<void> {
  const {orgRef, locationId, orgId, dateString, yesterdayString, shiftId, template, stats, logPrefix, totalTemplatesForShift} = params;

  const checklistId = checklistIdFor(orgId, locationId, shiftId, template.id, dateString);
  const checklistRef = orgRef
    .collection("locations").doc(locationId)
    .collection("daily_checklists").doc(checklistId);

  const existingChecklist = await checklistRef.get();
  
  // CRITICAL FIX: Check if template tasks exist, not just if checklist exists
  // The carry-forward function may create the checklist document before we run,
  // but we still need to seed template tasks
  let shouldSeedTasks = false;
  
  if (existingChecklist.exists) {
    // Check if template tasks already exist
    const templateTasksSnap = await checklistRef.collection("tasks")
      .where("isCarryForward", "==", false)
      .limit(1)
      .get();
    
    if (templateTasksSnap.empty) {
      // Checklist exists but has no template tasks - we need to seed them
      functions.logger.info(`${logPrefix} Checklist ${checklistId} exists but has no template tasks, seeding...`);
      shouldSeedTasks = true;
    } else {
      // Template tasks already exist, skip
      stats.skipped++;
      return;
    }
  }

  const batch = db.batch();
  const nowTs = admin.firestore.Timestamp.now();
  const expiresAt = daysFromNow(30);

  // Create or update checklist document
  if (!existingChecklist.exists) {
    const checklistData = {
      id: checklistId,
      organizationId: orgId,
      locationId,
      shiftId,
      checklistTemplateId: template.id,
      templateId: template.id,
      templateName: template.name,
      date: dateString,
      createdAt: nowTs,
      createdBy: "generator",
      expiresAt,
    } as Record<string, any>;
    FirestoreTTLHelper.batchSetWithTTL(batch, checklistRef, checklistData);
  } else {
    // Update existing checklist to ensure it has correct metadata
    batch.set(checklistRef, {
      templateName: template.name,
      checklistTemplateId: template.id,
      templateId: template.id,
      updatedAt: nowTs,
    }, {merge: true});
  }

  await seedTemplateTasks({
    batch,
    orgRef,
    checklistRef,
    template,
    shiftId,
    orgId,
    locationId,
    checklistId,
    dateString,
    nowTs,
  });

  const carried = await carryForwardTasks({
    batch,
    orgRef,
    checklistRef,
    template,
    shiftId,
    orgId,
    locationId,
    checklistId,
    currentDateString: dateString,
    yesterdayString,
    nowTs,
    totalTemplatesForShift,
  });

  try {
    await batch.commit();
    stats.createdChecklists++;
    stats.carriedTasks += carried;
  } catch (err) {
    stats.skipped++;
    functions.logger.error(`${logPrefix} Failed to commit checklist ${checklistId}`, err);
  }
}

/**
 * Scheduled generator that runs hourly and creates daily checklists/tasks.
 */
export const scheduledDailyGenerator = functions.pubsub
  .schedule("every 1 hours")
  .timeZone("UTC")
  .onRun(async () => {
    const log = (obj: unknown) => functions.logger.info(JSON.stringify(obj));

    const stats = {
      createdChecklists: 0,
      carriedTasks: 0,
      skipped: 0,
      errors: 0,
    };

    try {
      const orgsSnap = await db.collection("organizations").get();
      for (const orgDoc of orgsSnap.docs) {
        const orgId = orgDoc.id;
        const orgData = orgDoc.data() || {};
        const orgRef = db.collection("organizations").doc(orgId);

        const locationsSnap = await orgRef.collection("locations").get();
        for (const locDoc of locationsSnap.docs) {
          const locationId = locDoc.id;
          const locationData = locDoc.data() || {};
          const timezone = locationData.timezone || orgData.timezone;
          if (!timezone) {
            functions.logger.warn(`Skipping location ${locationId} in org ${orgId}: no timezone`);
            continue;
          }

          const localNow = DateTime.now().setZone(timezone);
          const dateString = localNow.toISODate();
          const yesterdayString = localNow.minus({days: 1}).toISODate();
          if (!dateString || !yesterdayString) {
            functions.logger.warn(`Skipping location ${locationId} in org ${orgId}: could not compute local date`);
            continue;
          }

          const shifts = await fetchShiftsForLocation(orgRef, locationId);

          for (const shiftDoc of shifts) {
            const shiftId = shiftDoc.id;
            try {
              const shiftData = shiftDoc.data() || {};
              const templateIds: string[] = Array.isArray(shiftData.checklistTemplateIds) ? shiftData.checklistTemplateIds : [];
              const validTemplates = await fetchValidTemplates(orgRef, locationId, templateIds, "[dailyGenerator]");

              if (validTemplates.length === 0) {
                functions.logger.warn(`[dailyGenerator] Skip checklist creation - no valid templates for shift ${shiftId} at location ${locationId}`);
                stats.skipped++;
                continue;
              }

              for (const template of validTemplates) {
                await createChecklistForTemplate({
                  orgRef,
                  locationId,
                  orgId,
                  dateString,
                  yesterdayString,
                  shiftId,
                  template,
                  stats,
                  logPrefix: "[dailyGenerator]",
                  totalTemplatesForShift: validTemplates.length,
                });
              }
            } catch (err) {
              stats.errors++;
              functions.logger.error(`[dailyGenerator] Shift processing error for ${shiftId}`, err);
            }
          }
        }
      }
    } catch (err) {
      stats.errors++;
      functions.logger.error("scheduledDailyGenerator error", err);
    }

    log({
      createdChecklists: stats.createdChecklists,
      carriedTasks: stats.carriedTasks,
      skipped: stats.skipped,
      errors: stats.errors,
      ts: new Date().toISOString(),
    });
    return null;
  });

/**
 * Generate checklists/tasks for a single organization/date - used by tests.
 * @param {string} orgId organization id
 * @param {string} dateString ISO date string (YYYY-MM-DD)
 */
export async function generateForOrgDate(
  orgId: string,
  dateString: string,
): Promise<{createdChecklists: number; carriedTasks: number; skipped: number;}> {
  const stats = {
    createdChecklists: 0,
    carriedTasks: 0,
    skipped: 0,
  };

  const orgRef = db.collection("organizations").doc(orgId);
  const locationsSnap = await orgRef.collection("locations").get();
  const yesterdayString = DateTime.fromISO(dateString).minus({days: 1}).toISODate();

  for (const locDoc of locationsSnap.docs) {
    const locationId = locDoc.id;

    const shifts = await fetchShiftsForLocation(orgRef, locationId);

    for (const shiftDoc of shifts) {
      const shiftId = shiftDoc.id;
      const shiftData = shiftDoc.data() || {};
      const templateIds: string[] = Array.isArray(shiftData.checklistTemplateIds) ? shiftData.checklistTemplateIds : [];
      const validTemplates = await fetchValidTemplates(orgRef, locationId, templateIds, "[generateForOrgDate]");

      if (validTemplates.length === 0) {
        functions.logger.warn(`[generateForOrgDate] Skip checklist creation - no valid templates for shift ${shiftId} at location ${locationId}`);
        stats.skipped++;
        continue;
      }

      for (const template of validTemplates) {
        const checklistId = checklistIdFor(orgId, locationId, shiftId, template.id, dateString);
        const checklistRef = orgRef
          .collection("locations").doc(locationId)
          .collection("daily_checklists").doc(checklistId);

        const batch = db.batch();
        const nowTs = admin.firestore.Timestamp.now();
        const expiresAt = daysFromNow(30);
        const checklistData = {
          id: checklistId,
          organizationId: orgId,
          locationId,
          shiftId,
          checklistTemplateId: template.id,
          templateId: template.id,
          templateName: template.name,
          date: dateString,
          createdAt: nowTs,
          createdBy: "generator",
          expiresAt,
        } as Record<string, any>;

        FirestoreTTLHelper.batchSetWithTTL(batch, checklistRef, checklistData);

        await seedTemplateTasks({
          batch,
          orgRef,
          checklistRef,
          template,
          shiftId,
          orgId,
          locationId,
          checklistId,
          dateString,
          nowTs,
        });

        const carried = await carryForwardTasks({
          batch,
          orgRef,
          checklistRef,
          template,
          shiftId,
          orgId,
          locationId,
          checklistId,
          currentDateString: dateString,
          yesterdayString,
          nowTs,
          totalTemplatesForShift: validTemplates.length,
        });

        await batch.commit();
        stats.createdChecklists++;
        stats.carriedTasks += carried;
      }
    }
  }

  return stats;
}
