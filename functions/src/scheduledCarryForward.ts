/**
 * Scheduled Cloud Function to carry forward missed tasks
 * Runs daily at 2 AM to carry forward yesterday's incomplete tasks to today
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Firestore} from "@google-cloud/firestore";

// Ensure we use the correct Firestore database
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Carry forward missed tasks for a single location
 */
async function carryForwardForLocation(
  organizationId: string,
  locationId: string,
  yesterdayStr: string,
  todayStr: string,
): Promise<number> {
  functions.logger.info(`Processing location ${locationId}`);

  const yesterdayChecklists = await db
    .collection("organizations")
    .doc(organizationId)
    .collection("locations")
    .doc(locationId)
    .collection("daily_checklists")
    .where("date", "==", yesterdayStr)
    .get();

  functions.logger.info(`Found ${yesterdayChecklists.size} yesterday's checklists`);

  let tasksCarriedForward = 0;

  for (const checklistDoc of yesterdayChecklists.docs) {
    const checklistData = checklistDoc.data();
    const {shiftId, checklistTemplateId, templateName, jobTypes, jobType} = checklistData;

    if (!shiftId || !checklistTemplateId) {
      functions.logger.warn(`Skipping checklist ${checklistDoc.id}: missing shiftId or templateId`);
      continue;
    }

    // Verify shift is still scheduled for today (not deleted/changed)
    try {
      const shiftDoc = await db
        .collection("organizations")
        .doc(organizationId)
        .collection("shifts")
        .doc(shiftId)
        .get();

      if (!shiftDoc.exists) {
        functions.logger.warn(`Shift ${shiftId} no longer exists, skipping`);
        continue;
      }
    } catch (error) {
      functions.logger.error(`Error checking shift ${shiftId}:`, error);
      continue;
    }

    // Get tasks from subcollection
    const tasksSnapshot = await checklistDoc.ref.collection("tasks").get();

    const incompleteTasks: any[] = [];
    for (const taskDoc of tasksSnapshot.docs) {
      const taskData = taskDoc.data();
      const isCompleted = taskData.completed === true || taskData.isCompleted === true;
      const alreadyAttempted = taskData.carryForwardAttempted === true;

      if (!isCompleted && !alreadyAttempted) {
        incompleteTasks.push({
          id: taskDoc.id,
          ...taskData,
        });
      }
    }

    if (incompleteTasks.length === 0) {
      continue;
    }

    functions.logger.info(`${templateName}: ${incompleteTasks.length} tasks to carry forward`);

    // Mark tasks as attempted in yesterday's checklist
    const batch = db.batch();
    for (const task of incompleteTasks) {
      const taskRef = checklistDoc.ref.collection("tasks").doc(task.id);
      batch.update(taskRef, {carryForwardAttempted: true});
    }
    await batch.commit();

    // Generate today's checklist ID
    const todayChecklistId = `${organizationId}_${locationId}_${shiftId}_${checklistTemplateId}_${todayStr}`;

    const todayChecklistRef = db
      .collection("organizations")
      .doc(organizationId)
      .collection("locations")
      .doc(locationId)
      .collection("daily_checklists")
      .doc(todayChecklistId);

    // Ensure today's checklist exists
    await todayChecklistRef.set(
      {
        id: todayChecklistId,
        checklistTemplateId,
        shiftId,
        locationId,
        organizationId,
        date: todayStr,
        templateName,
        // CRITICAL: Preserve jobTypes so staff users can see tasks
        jobTypes: jobTypes || jobType,
        isCompleted: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    const tasksColl = todayChecklistRef.collection("tasks");

    // Get existing carry-forward tasks to avoid duplicates
    // Note: We only check for CF tasks, not regular tasks
    // Regular tasks with same names are OK - they're today's recurring tasks
    const existingCFTasks = await tasksColl
      .where("isCarryForward", "==", true)
      .get();

    const existingOriginalIds = new Set<string>();
    existingCFTasks.forEach((doc) => {
      const data = doc.data();
      if (data.originalTaskId) {
        existingOriginalIds.add(data.originalTaskId);
      }
    });

    // Create carry-forward tasks
    const cfBatch = db.batch();
    let batchCount = 0;

    for (const task of incompleteTasks) {
      const originalTaskId = task.taskId || task.id;

      // Preserve original lineage for tasks that were already carry-forward.
      // Without this, backlog tasks get their originalDate overwritten each day and
      // show up as "Missed Yesterday" indefinitely.
      const preservedOriginalTaskId = task.originalTaskId || originalTaskId;
      const preservedOriginalChecklistId = task.originalChecklistId || checklistDoc.id;
      const preservedOriginalDate = task.originalDate || yesterdayStr;

      // Skip if already carried forward
      if (existingOriginalIds.has(originalTaskId)) {
        functions.logger.info(`  Skipping duplicate CF task: ${task.taskName}`);
        continue;
      }

      const cfTaskId = `cf_${originalTaskId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      const taskRef = tasksColl.doc(cfTaskId);

      const cfTaskData: any = {
        taskId: cfTaskId,
        taskName: task.taskName || task.name || task.description || "Unknown Task",
        completed: false,
        isCompleted: false,
        isCarryForward: true,
        originalTaskId: preservedOriginalTaskId,
        originalDate: preservedOriginalDate,
        originalChecklistId: preservedOriginalChecklistId,
        organizationId,
        locationId,
        dateString: todayStr,
        shiftId,
        checklistId: todayChecklistId,
        dailyChecklistId: todayChecklistId,
        checklistTemplateId,
        checklistName: templateName,
        templateName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Only add optional fields if they exist
      if (task.description !== undefined) {
        cfTaskData.description = task.description;
      }
      if (task.order !== undefined) {
        cfTaskData.order = task.order;
      }

      cfBatch.set(taskRef, cfTaskData);
      batchCount++;
      tasksCarriedForward++;

      // Commit batch every 450 operations (Firestore limit is 500)
      if (batchCount >= 450) {
        await cfBatch.commit();
        batchCount = 0;
      }
    }

    // Commit remaining tasks
    if (batchCount > 0) {
      await cfBatch.commit();
    }

    functions.logger.info(`  Created ${incompleteTasks.length} carry-forward tasks`);
  }

  return tasksCarriedForward;
}

/**
 * Scheduled function to carry forward missed tasks
 * Runs daily at 2 AM Pacific Time
 */
export const dailyCarryForwardMissedTasks = functions
  .runWith({
    memory: "512MB",
    timeoutSeconds: 540, // 9 minutes
  })
  .pubsub.schedule("0 2 * * *") // 2 AM every day
  .timeZone("America/Los_Angeles")
  .onRun(async (context) => {
    functions.logger.info("=== Daily Carry-Forward Starting ===");

    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    const yesterdayStr = `${yesterday.getFullYear()}-${String(
      yesterday.getMonth() + 1,
    ).padStart(2, "0")}-${String(yesterday.getDate()).padStart(2, "0")}`;
    const todayStr = `${today.getFullYear()}-${String(
      today.getMonth() + 1,
    ).padStart(2, "0")}-${String(today.getDate()).padStart(2, "0")}`;

    functions.logger.info(`Yesterday: ${yesterdayStr}, Today: ${todayStr}`);

    try {
      // Get all organizations
      const orgsSnapshot = await db.collection("organizations").get();
      functions.logger.info(`Processing ${orgsSnapshot.size} organizations`);

      let totalTasksCarriedForward = 0;

      for (const orgDoc of orgsSnapshot.docs) {
        const orgId = orgDoc.id;
        functions.logger.info(`Processing organization: ${orgId}`);

        // Get all locations for this organization
        const locationsSnapshot = await db
          .collection("organizations")
          .doc(orgId)
          .collection("locations")
          .get();

        functions.logger.info(`  Found ${locationsSnapshot.size} locations`);

        for (const locDoc of locationsSnapshot.docs) {
          try {
            const count = await carryForwardForLocation(
              orgId,
              locDoc.id,
              yesterdayStr,
              todayStr,
            );
            totalTasksCarriedForward += count;
          } catch (error) {
            functions.logger.error(`Error processing location ${locDoc.id}:`, error);
            // Continue with other locations
          }
        }
      }

      functions.logger.info(
        `=== Daily Carry-Forward Complete: ${totalTasksCarriedForward} tasks carried forward ===`,
      );

      return {
        success: true,
        totalTasksCarriedForward,
        date: todayStr,
      };
    } catch (error) {
      functions.logger.error("Fatal error in daily carry-forward:", error);
      throw error;
    }
  });
