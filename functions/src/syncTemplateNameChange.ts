import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {dateStringUTC} from "./idHelpers";
import {Firestore} from "@google-cloud/firestore";

const REGION = process.env.FUNCTION_REGION || "us-central1";
const MAX_BATCH_WRITES = Number(process.env.MAX_BATCH_WRITES || 400);

// Ensure we use the correct Firestore database
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

export const syncTemplateNameChange = functions
    .region(REGION)
    .firestore.database('planwithhands').document("organizations/{orgId}/checklist_templates/{templateId}")
    .onWrite(async (change, context) => {
      const orgId = context.params.orgId as string;
      const templateId = context.params.templateId as string;
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

      const today = dateStringUTC(new Date());
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
              batch.update(doc.ref, {templateName: afterName});
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
        } catch (error) {
          console.error(`[syncTemplateNameChange] Error updating location ${locationId}:`, error);
        }
      }
      
      if (totalUpdated > 0) {
        console.log("[syncTemplateNameChange] Successfully updated", totalUpdated, "daily_checklists total");
      } else {
        console.log("[syncTemplateNameChange] No daily_checklists found for template", templateId, "on date", today);
      }
      return null;
    });