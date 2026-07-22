/**
 * Debug script to check daily summary calculation for October 14, 2025
 * This will help understand why the numbers don't match
 */

const admin = require("firebase-admin");

// Check if already initialized
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: "plan-with-hands",
  });
}

// Use planwithhands database
const db = admin.firestore();
db.settings({ databaseId: "planwithhands" });

const ORG_ID = "3qjYzHagWmfbnMieJ1aj"; // Conors pub Group
const DATE = "2025-10-14"; // October 14, 2025

async function debugSummaryCalculation() {
  console.log("=== Daily Summary Calculation Debug ===");
  console.log(`Organization: ${ORG_ID}`);
  console.log(`Date: ${DATE}\n`);

  let totalTasks = 0;
  let completedTasks = 0;
  let incompleteTasks = 0;
  let carryForwardTasks = 0;
  let completedCarryForward = 0;
  let incompleteCarryForward = 0;
  let regularTasks = 0;
  let completedRegular = 0;
  let incompleteRegular = 0;

  try {
    // Get all locations
    const locationsSnapshot = await db
      .collection("organizations")
      .doc(ORG_ID)
      .collection("locations")
      .get();

    console.log(`Found ${locationsSnapshot.size} locations\n`);

    for (const locationDoc of locationsSnapshot.docs) {
      const locationId = locationDoc.id;
      const locationName = locationDoc.data().locationName || "Unknown";

      console.log(`\n=== Location: ${locationName} (${locationId}) ===`);

      // Get daily checklists for this date
      const checklistsSnapshot = await db
        .collection("organizations")
        .doc(ORG_ID)
        .collection("locations")
        .doc(locationId)
        .collection("daily_checklists")
        .where("date", "==", DATE)
        .get();

      console.log(`  Found ${checklistsSnapshot.size} checklists`);

      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || "Unknown";
        const shiftName = checklistData.shiftName || "Unknown Shift";

        console.log(`\n  Checklist: ${templateName} (${shiftName})`);

        // Get tasks from subcollection
        const tasksSnapshot = await checklistDoc.ref
          .collection("tasks")
          .get();

        console.log(`    Tasks in subcollection: ${tasksSnapshot.size}`);

        let checklistTotal = 0;
        let checklistCompleted = 0;
        let checklistCF = 0;

        for (const taskDoc of tasksSnapshot.docs) {
          const taskData = taskDoc.data();
          const taskName =
            taskData.taskName || taskData.description || "Unknown Task";
          const isCompleted = taskData.completed || taskData.isCompleted || false;
          const isCarryForward = taskData.isCarryForward || false;

          totalTasks++;
          checklistTotal++;

          if (isCarryForward) {
            carryForwardTasks++;
            checklistCF++;
            if (isCompleted) {
              completedCarryForward++;
            } else {
              incompleteCarryForward++;
            }
          } else {
            regularTasks++;
            if (isCompleted) {
              completedRegular++;
            } else {
              incompleteRegular++;
            }
          }

          if (isCompleted) {
            completedTasks++;
            checklistCompleted++;
          } else {
            incompleteTasks++;
          }

          // Show first few tasks as examples
          if (checklistTotal <= 3 || isCarryForward) {
            console.log(
              `      - ${taskName.substring(0, 40)} ${isCompleted ? "✓" : "✗"} ${isCarryForward ? "[CF]" : ""}`,
            );
          }
        }

        console.log(
          `    Summary: ${checklistCompleted}/${checklistTotal} completed (${checklistCF} carry-forward)`,
        );
      }
    }

    // Build location breakdown like the actual function does
    const locationBreakdown = {};
    
    // Re-query locations for the breakdown
    const locationsForBreakdown = await db
      .collection("organizations")
      .doc(ORG_ID)
      .collection("locations")
      .get();
    
    for (const locationDoc of locationsForBreakdown.docs) {
      const locationId = locationDoc.id;
      const locationName = locationDoc.data().locationName || "Unknown";
      
      let locationRegularTasks = 0;
      let locationCompletedRegular = 0;
      
      const checklistsSnapshot = await db
        .collection("organizations")
        .doc(ORG_ID)
        .collection("locations")
        .doc(locationId)
        .collection("daily_checklists")
        .where("date", "==", DATE)
        .get();
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const tasksSnapshot = await checklistDoc.ref.collection("tasks").get();
        
        for (const taskDoc of tasksSnapshot.docs) {
          const taskData = taskDoc.data();
          const isCompleted = taskData.completed || taskData.isCompleted || false;
          const isCarryForward = taskData.isCarryForward || false;
          
          if (!isCarryForward) {
            locationRegularTasks++;
            if (isCompleted) {
              locationCompletedRegular++;
            }
          }
        }
      }
      
      if (locationRegularTasks > 0) {
        locationBreakdown[locationId] = {
          locationName,
          totalRegular: locationRegularTasks,
          completedRegular: locationCompletedRegular,
          percentage: (locationCompletedRegular / locationRegularTasks * 100)
        };
      }
    }

    console.log("\n\n=== TOTALS ===");
    console.log(`Total Tasks: ${totalTasks}`);
    console.log(`  - Regular Tasks: ${regularTasks}`);
    console.log(`  - Carry-Forward Tasks: ${carryForwardTasks}`);
    console.log(``);
    console.log(`Completed: ${completedTasks}`);
    console.log(`  - Regular Completed: ${completedRegular}`);
    console.log(`  - Carry-Forward Completed: ${completedCarryForward}`);
    console.log(``);
    console.log(`Incomplete: ${incompleteTasks}`);
    console.log(`  - Regular Incomplete: ${incompleteRegular}`);
    console.log(`  - Carry-Forward Incomplete: ${incompleteCarryForward}`);
    console.log(``);

    const tasksScheduledForToday = totalTasks - carryForwardTasks;
    const percentage = tasksScheduledForToday > 0 
      ? (completedTasks / tasksScheduledForToday * 100)
      : 0;

    console.log("\n=== WHAT SHOULD BE SHOWN ===");
    console.log(`Tasks Scheduled For Today: ${tasksScheduledForToday}`);
    console.log(`  (This excludes carry-forward tasks from previous days)`);
    console.log(``);
    console.log(`Notification should show:`);
    console.log(`  "Overall Progress: ${Math.round(percentage)}% (${completedTasks}/${tasksScheduledForToday} tasks completed)"`);
    console.log(``);
    console.log(`But if using totalTasks instead:`);
    const wrongPercentage = totalTasks > 0
      ? (completedTasks / totalTasks * 100)
      : 0;
    console.log(`  "Overall Progress: ${Math.round(wrongPercentage)}% (${completedTasks}/${totalTasks} tasks completed)"`);
    console.log(``);

    console.log("\n=== DIAGNOSIS ===");
    if (carryForwardTasks === 0) {
      console.log(
        "⚠️  NO CARRY-FORWARD TASKS FOUND - this is expected if carry-forward hasn't run yet",
      );
      console.log(
        "   The carry-forward function was just deployed and will run at 2 AM tomorrow",
      );
    } else {
      console.log(
        `✓ Found ${carryForwardTasks} carry-forward tasks as expected`,
      );
    }

    if (completedTasks + incompleteTasks === totalTasks) {
      console.log(
        `✓ Task counts add up correctly: ${completedTasks} + ${incompleteTasks} = ${totalTasks}`,
      );
    } else {
      console.log(
        `✗ ERROR: Task counts don't add up: ${completedTasks} + ${incompleteTasks} ≠ ${totalTasks}`,
      );
    }

    // Check what the notification actually shows by looking at logs
    console.log("\n=== LOCATION BREAKDOWN (What Will Appear in Summary) ===");
    if (Object.keys(locationBreakdown).length === 0) {
      console.log("No locations with regular tasks found");
    } else {
      console.log("📍 Performance by Location:");
      for (const [locId, data] of Object.entries(locationBreakdown)) {
        const emoji = data.percentage >= 90 ? '✅' : data.percentage >= 70 ? '⚠️' : '❌';
        console.log(`${emoji} ${data.locationName}: ${Math.round(data.percentage)}% (${data.completedRegular}/${data.totalRegular})`);
      }
    }
    
    console.log("\n=== CHECKING SENT NOTIFICATION ===");
    const summaryLog = await db
      .collection("organizations")
      .doc(ORG_ID)
      .collection("daily_summary_logs")
      .doc(DATE)
      .get();

    if (summaryLog.exists) {
      console.log(`✓ Summary was sent for ${DATE}`);
      console.log(`  Sent at: ${summaryLog.data().sentAt?.toDate()}`);
    } else {
      console.log(`✗ No summary log found for ${DATE}`);
    }
  } catch (error) {
    console.error("Error:", error);
  }

  process.exit(0);
}

debugSummaryCalculation();
