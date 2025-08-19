"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.syncTodayOnShiftChange = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const idHelpers_1 = require("./idHelpers");
const MAX_BATCH_WRITES = Number(process.env.MAX_BATCH_WRITES || 400);
exports.syncTodayOnShiftChange = functions
    .region(process.env.FUNCTION_REGION || 'us-central1')
    .firestore.document('organizations/{orgId}/locations/{locId}/shifts/{shiftId}')
    .onUpdate(async (change, context) => {
    const orgId = context.params.orgId;
    const locId = context.params.locId;
    const shiftId = context.params.shiftId;
    const beforeData = (change.before.data() || {});
    const afterData = (change.after.data() || {});
    const beforeTemplateIds = Array.isArray(beforeData.checklistTemplateIds)
        ? beforeData.checklistTemplateIds
        : [];
    const afterTemplateIds = Array.isArray(afterData.checklistTemplateIds)
        ? afterData.checklistTemplateIds
        : [];
    const beforeStart = beforeData.startTime || null;
    const beforeEnd = beforeData.endTime || null;
    const afterStart = afterData.startTime || null;
    const afterEnd = afterData.endTime || null;
    // If templates and shift times unchanged, no-op
    const templatesEqual = JSON.stringify(beforeTemplateIds) === JSON.stringify(afterTemplateIds);
    const timesEqual = JSON.stringify({ beforeStart, beforeEnd }) === JSON.stringify({ afterStart, afterEnd });
    if (templatesEqual && timesEqual) {
        console.log('[syncTodayOnShiftChange] no relevant changes for shift', shiftId);
        return null;
    }
    const dateString = (0, idHelpers_1.dateStringUTC)(new Date());
    console.log('[syncTodayOnShiftChange] shift changed, syncing today checks for', dateString, 'shift', shiftId);
    const db = admin.firestore();
    const dailyChecklistsColl = db.collection(`organizations/${orgId}/locations/${locId}/daily_checklists`);
    // Find today's checklist(s) for this shift
    const checklistQuery = dailyChecklistsColl
        .where('shiftId', '==', shiftId)
        .where('dateString', '==', dateString);
    const checklistSnap = await checklistQuery.get();
    const checklists = checklistSnap.docs || [];
    // If none exist, we'll create one checklist and populate tasks from templates
    const templatesToProcess = afterTemplateIds;
    let totalInserted = 0;
    let totalChecklistsCreated = 0;
    const commitBatch = async (batch) => {
        if (!batch)
            return;
        try {
            await batch.commit();
        }
        catch (err) {
            console.error('[syncTodayOnShiftChange] batch commit failed', err);
            throw err;
        }
    };
    let batch = db.batch();
    let currentBatchWrites = 0;
    // Helper to ensure tasks from a template are present on a checklist
    const ensureTemplateTasksOnChecklist = async (checklistRef, checklistId, templateId) => {
        // get existing task ids via listDocuments to avoid reads
        let existingTaskIds = new Set();
        try {
            const taskDocRefs = await checklistRef.collection('tasks').listDocuments();
            existingTaskIds = new Set(taskDocRefs.map((r) => r.id));
        }
        catch (err) {
            console.warn('[syncTodayOnShiftChange] listDocuments failed, falling back to get():', err);
            const tasksSnap = await checklistRef.collection('tasks').get();
            existingTaskIds = new Set(tasksSnap.docs.map((d) => d.id));
        }
        // fetch template doc
        const templateRef = db.doc(`organizations/${orgId}/checklist_templates/${templateId}`);
        const templateSnap = await templateRef.get();
        if (!templateSnap.exists) {
            console.warn('[syncTodayOnShiftChange] template not found', templateId);
            return 0;
        }
        const templateData = templateSnap.data() || {};
        const templateTasks = Array.isArray(templateData.tasks) ? templateData.tasks : [];
        let inserted = 0;
        const midnightIso = `${dateString}T00:00:00Z`;
        for (const t of templateTasks) {
            const templateTaskId = (t && (t.id || t.taskId || t.templateTaskId || '')).toString();
            if (!templateTaskId)
                continue;
            const taskId = (0, idHelpers_1.deterministicTaskId)(templateTaskId, checklistId, dateString);
            if (existingTaskIds.has(taskId))
                continue; // preserve existing
            const taskName = (t && (t.taskName || t.title || t.name || '')).toString();
            const photoRequired = Boolean(t && t.photoRequired);
            const dueDate = admin.firestore.Timestamp.fromDate(new Date(midnightIso));
            const taskDocRef = checklistRef.collection('tasks').doc(taskId);
            const docData = {
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
            batch.set(taskDocRef, docData, { merge: true });
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
        const checklistDoc = {
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
        batch.set(newChecklistRef, checklistDoc, { merge: true });
        currentBatchWrites += 1;
        totalChecklistsCreated += 1;
        // add tasks from all templates
        for (const templateId of templatesToProcess) {
            await ensureTemplateTasksOnChecklist(newChecklistRef, checklistId, templateId);
        }
    }
    else {
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
    console.log('[syncTodayOnShiftChange] completed. created=', totalChecklistsCreated, 'inserted=', totalInserted);
    return { created: totalChecklistsCreated, inserted: totalInserted };
});
