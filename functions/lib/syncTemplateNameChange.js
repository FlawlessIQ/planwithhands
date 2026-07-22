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
exports.syncTemplateNameChange = void 0;
const functions = __importStar(require("firebase-functions"));
const idHelpers_1 = require("./idHelpers");
const firestore_1 = require("@google-cloud/firestore");
const REGION = process.env.FUNCTION_REGION || "us-central1";
const MAX_BATCH_WRITES = Number(process.env.MAX_BATCH_WRITES || 400);
// Ensure we use the correct Firestore database
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new firestore_1.Firestore({ databaseId: FIRESTORE_DATABASE_ID });
exports.syncTemplateNameChange = functions
    .region(REGION)
    .firestore.database('planwithhands').document("organizations/{orgId}/checklist_templates/{templateId}")
    .onWrite(async (change, context) => {
    const orgId = context.params.orgId;
    const templateId = context.params.templateId;
    const beforeData = change.before.exists ? change.before.data() : {};
    const afterData = change.after.exists ? change.after.data() : {};
    const beforeName = (beforeData?.name || "").toString();
    const afterName = (afterData?.name || "").toString();
    if (!afterName) {
        console.log("[syncTemplateNameChange] New name empty/undefined; skipping.");
        return null;
    }
    if (beforeName === afterName) {
        console.log("[syncTemplateNameChange] Name unchanged for template", templateId);
        return null;
    }
    const today = (0, idHelpers_1.dateStringUTC)(new Date());
    console.log("[syncTemplateNameChange] Updating daily_checklists name ->", afterName, "for template", templateId, "date", today);
    console.log("[syncTemplateNameChange] Environment FIRESTORE_DATABASE_ID:", process.env.FIRESTORE_DATABASE_ID);
    // Alternative approach: Update template names across organizations and locations
    // Since collection group queries with complex indexes are problematic,
    // we'll iterate through the organization's locations and update daily_checklists directly
    const orgRef = db.collection("organizations").doc(orgId);
    const locationsSnap = await orgRef.collection("locations").get();
    if (locationsSnap.empty) {
        console.log("[syncTemplateNameChange] No locations found for organization", orgId);
        return null;
    }
    let totalUpdated = 0;
    for (const locationDoc of locationsSnap.docs) {
        const locationId = locationDoc.id;
        console.log("[syncTemplateNameChange] Checking location", locationId);
        // Query daily_checklists for this specific location and template
        const checklistQuery = orgRef
            .collection("locations")
            .doc(locationId)
            .collection("daily_checklists")
            .where("checklistTemplateId", "==", templateId)
            .where("date", "==", today);
        try {
            const checklistSnap = await checklistQuery.get();
            if (!checklistSnap.empty) {
                console.log(`[syncTemplateNameChange] Found ${checklistSnap.size} daily_checklists in location ${locationId}`);
                const batch = db.batch();
                let batchCount = 0;
                for (const doc of checklistSnap.docs) {
                    batch.update(doc.ref, { templateName: afterName });
                    batchCount++;
                    if (batchCount >= MAX_BATCH_WRITES) {
                        await batch.commit();
                        console.log("[syncTemplateNameChange] Committed batch of", batchCount, "updates in location", locationId);
                        totalUpdated += batchCount;
                        batchCount = 0;
                    }
                }
                if (batchCount > 0) {
                    await batch.commit();
                    console.log("[syncTemplateNameChange] Committed final batch of", batchCount, "updates in location", locationId);
                    totalUpdated += batchCount;
                }
            }
        }
        catch (error) {
            console.error(`[syncTemplateNameChange] Error updating location ${locationId}:`, error);
        }
    }
    if (totalUpdated > 0) {
        console.log("[syncTemplateNameChange] Successfully updated", totalUpdated, "daily_checklists total");
    }
    else {
        console.log("[syncTemplateNameChange] No daily_checklists found for template", templateId, "on date", today);
    }
    return null;
});
