/// <reference types="mocha" />
import {checklistIdFor, daysFromNow, generateForOrgDate} from "../src/dailyGenerator";
import {expect} from "chai";
import * as admin from "firebase-admin";
import {Firestore} from "@google-cloud/firestore";

// Note: these tests assume the emulator is available via FIRESTORE_EMULATOR_HOST or
// will use the default in-memory project when admin.initializeApp is called without credentials.
if (!admin.apps.length) {
  admin.initializeApp();
}

function testDb(): Firestore {
  return new Firestore({
    projectId: process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT || "demo-test",
    databaseId: process.env.FIRESTORE_DATABASE_ID || "planwithhands",
  });
}

describe("dailyGenerator helpers", () => {
  it("generates deterministic checklist id", () => {
    const id = checklistIdFor("org1", "loc1", "shiftA", "tmpl-1", "2025-08-19");
    expect(id).to.equal("org1_loc1_shiftA_tmpl-1_2025-08-19");
  });

  it("daysFromNow produces a timestamp ~30 days in future", () => {
    const ts = daysFromNow(30);
    const now = Date.now();
    const diff = ts.toMillis() - now;
    expect(diff).to.be.greaterThan(29 * 24 * 3600 * 1000);
    expect(diff).to.be.lessThan(31 * 24 * 3600 * 1000);
  });

  // Integration-style idempotency + carry-forward tests using the emulator
  it("idempotency: running generator twice does not create duplicate checklists or tasks", async () => {
    const db = testDb();
    const orgId = "test-org-id";
    const locId = "loc-1";
    const shiftId = "shift-1";
    const templateId = "tmpl-1";
    const date = "2025-08-19";

    // Create minimal org/location/shift/template data
    await db.collection("organizations").doc(orgId).set({});
    await db.collection("organizations").doc(orgId).collection("locations").doc(locId).set({});
    await db.collection("organizations").doc(orgId).collection("shifts").doc(shiftId).set({
      shiftName: "Test Shift",
      checklistTemplateIds: [templateId],
      locationIds: [locId],
    });
    await db.collection("organizations").doc(orgId).collection("checklist_templates").doc(templateId).set({
      name: "T",
    });
    // add a template task
    await db.collection("organizations").doc(orgId).collection("checklist_templates").doc(templateId).collection("tasks").doc("t1").set({
      name: "Do thing",
      order: 0,
    });

    // Run generator twice
    await generateForOrgDate(orgId, date);
    await generateForOrgDate(orgId, date);

    // Assert only one checklist doc exists for location/date/template
    const qs = await db
        .collection("organizations")
        .doc(orgId)
        .collection("locations")
        .doc(locId)
        .collection("daily_checklists")
        .where("date", "==", date)
        .get();
    expect(qs.docs.length).to.equal(1);

    // Assert only one task doc seeded
    const checklistId = qs.docs[0].id;
    const tasks = await db
        .collection("organizations")
        .doc(orgId)
        .collection("locations")
        .doc(locId)
        .collection("daily_checklists")
        .doc(checklistId)
        .collection("tasks")
        .get();
    expect(tasks.docs.length).to.equal(1);
  }).timeout(10000);

  it("carry-forward: moves incomplete yesterday tasks into today with isCarryForward and expiresAt ~30d", async () => {
    const db = testDb();
    const orgId = "cf-org";
    const locId = "loc-cf";
    const shiftId = "shift-cf";
    const templateId = "tmpl-cf";
    const yesterday = "2025-08-18";
    const today = "2025-08-19";

    // Setup org/location/shift/template
    await db.collection("organizations").doc(orgId).set({});
    await db.collection("organizations").doc(orgId).collection("locations").doc(locId).set({});
    await db.collection("organizations").doc(orgId).collection("shifts").doc(shiftId).set({
      shiftName: "Shift CF",
      checklistTemplateIds: [templateId],
      locationIds: [locId],
    });
    await db.collection("organizations").doc(orgId).collection("checklist_templates").doc(templateId).set({
      name: "CF Template",
    });
    // create yesterday checklist with an incomplete task in parent array
    const yesterdayChecklistId = checklistIdFor(orgId, locId, shiftId, templateId, yesterday);
    await db
        .collection("organizations")
        .doc(orgId)
        .collection("locations")
        .doc(locId)
        .collection("daily_checklists")
        .doc(yesterdayChecklistId)
        .set({
          id: yesterdayChecklistId,
          date: yesterday,
          checklistTemplateId: templateId,
          shiftId: shiftId,
        });
    await db
        .collection("organizations")
        .doc(orgId)
        .collection("locations")
        .doc(locId)
        .collection("daily_checklists")
        .doc(yesterdayChecklistId)
        .collection("tasks")
        .doc("old-1")
        .set({
          taskId: "old-1",
          taskName: "Left undone",
          completed: false,
          checklistTemplateId: templateId,
        });

    // Ensure today's checklists exist (generator will carry forward)
    await generateForOrgDate(orgId, today);

    // Query today's carry-forward tasks
    const todayChecklistId = checklistIdFor(orgId, locId, shiftId, templateId, today);
    const tasksSnap = await db
        .collection("organizations")
        .doc(orgId)
        .collection("locations")
        .doc(locId)
        .collection("daily_checklists")
        .doc(todayChecklistId)
        .collection("tasks")
        .where("isCarryForward", "==", true)
        .get();

    expect(tasksSnap.docs.length).to.be.greaterThan(0);
    const cfDoc = tasksSnap.docs[0].data();
    expect(cfDoc.isCarryForward === true || cfDoc["isCarryForward"] === true).to.equal(true);
    expect(cfDoc.expiresAt).to.exist;
    // expiresAt should be a Firestore Timestamp roughly 30 days ahead
    const expiresAt = cfDoc.expiresAt.toMillis ? cfDoc.expiresAt.toMillis() : cfDoc.expiresAt._seconds * 1000;
    const now = Date.now();
    const diff = expiresAt - now;
    expect(diff).to.be.greaterThan(29 * 24 * 3600 * 1000);
  }).timeout(10000);

  it("negative carry-forward: completed yesterday tasks are not carried forward", async () => {
    const db = testDb();
    const orgId = "cf-org-2";
    const locId = "loc-cf-2";
    const shiftId = "shift-cf-2";
    const templateId = "tmpl-cf-2";
    const yesterday = "2025-08-18";
    const today = "2025-08-19";

    await db.collection("organizations").doc(orgId).set({});
    await db.collection("organizations").doc(orgId).collection("locations").doc(locId).set({});
    await db.collection("organizations").doc(orgId).collection("shifts").doc(shiftId).set({
      shiftName: "Shift CF2",
      checklistTemplateIds: [templateId],
      locationIds: [locId],
    });
    await db.collection("organizations").doc(orgId).collection("checklist_templates").doc(templateId).set({name: "CF Template 2"});
    const yesterdayChecklistId = checklistIdFor(orgId, locId, shiftId, templateId, yesterday);
    await db.collection("organizations").doc(orgId).collection("locations").doc(locId).collection("daily_checklists").doc(yesterdayChecklistId).set({
      id: yesterdayChecklistId,
      date: yesterday,
      checklistTemplateId: templateId,
      shiftId: shiftId,
    });
    await db.collection("organizations").doc(orgId).collection("locations").doc(locId).collection("daily_checklists").doc(yesterdayChecklistId).collection("tasks").doc("done-1").set({
      taskId: "done-1",
      taskName: "Done",
      completed: true,
      checklistTemplateId: templateId,
    });

    await generateForOrgDate(orgId, today);

    const todayChecklistId = checklistIdFor(orgId, locId, shiftId, templateId, today);
    const tasksSnap = await db.collection("organizations").doc(orgId).collection("locations").doc(locId).collection("daily_checklists").doc(todayChecklistId).collection("tasks").where("isCarryForward", "==", true).get();
    expect(tasksSnap.docs.length).to.equal(0);
  }).timeout(8000);

  it("multi-template: shift with multiple templates creates one checklist per template", async () => {
    const db = testDb();
    const orgId = "multi-org";
    const locId = "multi-loc";
    const shiftId = "multi-shift";
    const templateA = "tmpl-A";
    const templateB = "tmpl-B";
    const date = "2025-08-19";

    await db.collection("organizations").doc(orgId).set({});
    await db.collection("organizations").doc(orgId).collection("locations").doc(locId).set({});
    await db.collection("organizations").doc(orgId).collection("shifts").doc(shiftId).set({
      shiftName: "Multi Shift",
      checklistTemplateIds: [templateA, templateB],
      locationIds: [locId],
    });
    await db.collection("organizations").doc(orgId).collection("checklist_templates").doc(templateA).set({name: "A"});
    await db.collection("organizations").doc(orgId).collection("checklist_templates").doc(templateB).set({name: "B"});
    await db.collection("organizations").doc(orgId).collection("checklist_templates").doc(templateA).collection("tasks").doc("a1").set({name: "A1", order: 0});
    await db.collection("organizations").doc(orgId).collection("checklist_templates").doc(templateB).collection("tasks").doc("b1").set({name: "B1", order: 0});

    await generateForOrgDate(orgId, date);

    const checklistAId = checklistIdFor(orgId, locId, shiftId, templateA, date);
    const checklistBId = checklistIdFor(orgId, locId, shiftId, templateB, date);
    const checklistARef = db.collection("organizations").doc(orgId).collection("locations").doc(locId).collection("daily_checklists").doc(checklistAId);
    const checklistBRef = db.collection("organizations").doc(orgId).collection("locations").doc(locId).collection("daily_checklists").doc(checklistBId);

    const [checklistASnap, checklistBSnap, tasksASnap, tasksBSnap] = await Promise.all([
      checklistARef.get(),
      checklistBRef.get(),
      checklistARef.collection("tasks").get(),
      checklistBRef.collection("tasks").get(),
    ]);

    expect(checklistASnap.exists).to.equal(true);
    expect(checklistBSnap.exists).to.equal(true);
    expect(tasksASnap.docs.length).to.equal(1);
    expect(tasksBSnap.docs.length).to.equal(1);

    for (const d of [...tasksASnap.docs, ...tasksBSnap.docs]) {
      const data = d.data();
      expect(data.expiresAt).to.exist;
      expect(d.id).to.be.a("string").and.to.have.length.greaterThan(0);
    }
  }).timeout(10000);
});
