import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Firestore} from "@google-cloud/firestore";

const REGION = process.env.FUNCTION_REGION || "us-central1";
const MAX_BATCH_WRITES = Number(process.env.MAX_BATCH_WRITES || 400);

// Ensure we use the correct Firestore database
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

export const cleanupDeletedTemplate = functions
    .region(REGION)
    .firestore.database('planwithhands').document("organizations/{orgId}/checklist_templates/{templateId}")
    .onDelete(async (snapshot, context) => {
      const orgId = context.params.orgId as string;
      const templateId = context.params.templateId as string;
      const templateData = snapshot.data();
      const templateName = templateData?.name || templateId;

      console.log("[cleanupDeletedTemplate] Template deleted:", templateName, "ID:", templateId);
      
      try {
        // Get all locations for this organization
        const orgRef = db.collection("organizations").doc(orgId);
        const locationsSnap = await orgRef.collection("locations").get();
        
        if (locationsSnap.empty) {
          console.log("[cleanupDeletedTemplate] No locations found for organization", orgId);
          return null;
        }
        
        let totalDeleted = 0;
        
        for (const locationDoc of locationsSnap.docs) {
          const locationId = locationDoc.id;
          console.log("[cleanupDeletedTemplate] Checking location", locationId);
          
          // Find daily_checklists that reference the deleted template
          const checklistQuery = orgRef
              .collection("locations")
              .doc(locationId)
              .collection("daily_checklists")
              .where("checklistTemplateId", "==", templateId);
              
          try {
            const checklistSnap = await checklistQuery.get();
            
            if (!checklistSnap.empty) {
              console.log(`[cleanupDeletedTemplate] Found ${checklistSnap.size} orphaned daily_checklists in location ${locationId}`);
              
              const batch = db.batch();
              let batchCount = 0;
              
              for (const doc of checklistSnap.docs) {
                const docData = doc.data();
                console.log(`[cleanupDeletedTemplate] Deleting orphaned daily_checklist: ${doc.id} (date: ${docData.date})`);
                
                // Also delete the tasks subcollection
                const tasksSnap = await doc.ref.collection("tasks").get();
                for (const taskDoc of tasksSnap.docs) {
                  batch.delete(taskDoc.ref);
                  batchCount++;
                }
                
                // Delete the daily_checklist document
                batch.delete(doc.ref);
                batchCount++;
                
                if (batchCount >= MAX_BATCH_WRITES) {
                  await batch.commit();
                  console.log("[cleanupDeletedTemplate] Committed batch of", batchCount, "deletions in location", locationId);
                  totalDeleted += batchCount;
                  batchCount = 0;
                }
              }
              
              if (batchCount > 0) {
                await batch.commit();
                console.log("[cleanupDeletedTemplate] Committed final batch of", batchCount, "deletions in location", locationId);
                totalDeleted += batchCount;
              }
            }
          } catch (error) {
            console.error(`[cleanupDeletedTemplate] Error cleaning location ${locationId}:`, error);
          }
        }
        
        if (totalDeleted > 0) {
          console.log("[cleanupDeletedTemplate] Successfully deleted", totalDeleted, "orphaned documents for template", templateName);
        } else {
          console.log("[cleanupDeletedTemplate] No orphaned daily_checklists found for template", templateName);
        }
        
      } catch (error) {
        console.error("[cleanupDeletedTemplate] Error during cleanup:", error);
      }
      
      return null;
    });