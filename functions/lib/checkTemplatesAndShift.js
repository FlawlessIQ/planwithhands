"use strict";
// Check templates via Cloud Function
// Run with: curl -X POST https://us-central1-planwithhands.cloudfunctions.net/checkTemplatesAndShift \
//   -H "Content-Type: application/json" \
//   -d '{"orgId":"FErQ4pkcrCovJ7T6L13M","locationId":"fW45ffBBPar5EaNodDYq","shiftId":"VY0xGrIzvHSaqX1AXkcY"}'
const functions = require('firebase-functions');
const admin = require('firebase-admin');
exports.checkTemplatesAndShift = functions.https.onRequest(async (req, res) => {
    try {
        const { orgId, locationId, shiftId } = req.body;
        if (!orgId || !locationId || !shiftId) {
            return res.status(400).json({ error: 'Missing required parameters' });
        }
        const db = admin.firestore();
        const result = {
            orgId,
            locationId,
            shiftId,
            templates: [],
            shift: null,
            validTemplatesForLocation: []
        };
        // Check the shift configuration
        const shiftDoc = await db
            .collection('organizations')
            .doc(orgId)
            .collection('shifts')
            .doc(shiftId)
            .get();
        if (shiftDoc.exists) {
            const shiftData = shiftDoc.data();
            result.shift = {
                name: shiftData.shiftName,
                templateIds: shiftData.checklistTemplateIds || [],
                locationIds: shiftData.locationIds || shiftData.locationId || [],
                repeatsDaily: shiftData.repeatsDaily,
                activeDays: shiftData.activeDays || shiftData.days || []
            };
            // Check each template ID from the shift
            const templateIds = shiftData.checklistTemplateIds || [];
            for (const templateId of templateIds) {
                const templateDoc = await db
                    .collection('organizations')
                    .doc(orgId)
                    .collection('checklist_templates')
                    .doc(templateId)
                    .get();
                if (templateDoc.exists) {
                    const data = templateDoc.data();
                    result.templates.push({
                        id: templateId,
                        name: data.name || '(NO NAME)',
                        locationIds: data.locationIds || data.locationId || [],
                        active: data.active,
                        deleted: data.deleted || false
                    });
                }
                else {
                    result.templates.push({
                        id: templateId,
                        exists: false,
                        error: 'TEMPLATE NOT FOUND'
                    });
                }
            }
        }
        else {
            result.shift = { error: 'SHIFT NOT FOUND' };
        }
        // Get all valid templates for this location
        const allTemplates = await db
            .collection('organizations')
            .doc(orgId)
            .collection('checklist_templates')
            .get();
        for (const doc of allTemplates.docs) {
            const data = doc.data();
            const locIds = Array.isArray(data.locationIds)
                ? data.locationIds
                : (data.locationId ? [data.locationId] : []);
            if (locIds.includes(locationId) && data.name && !data.deleted) {
                result.validTemplatesForLocation.push({
                    id: doc.id,
                    name: data.name,
                    active: data.active
                });
            }
        }
        return res.json(result);
    }
    catch (error) {
        console.error('Error checking templates:', error);
        return res.status(500).json({ error: error.message });
    }
});
