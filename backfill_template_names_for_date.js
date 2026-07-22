const { Firestore } = require('@google-cloud/firestore');

const db = new Firestore({ databaseId: 'planwithhands' });

const targetDate = process.argv[2] || '2025-10-03';

(async () => {
  console.log('Backfilling templateName/templateNames for daily_checklists on', targetDate);

  const orgsSnap = await db.collection('organizations').get();
  console.log('Org count:', orgsSnap.size);

  let updatedChecklists = 0;
  let skipped = 0;

  for (const orgDoc of orgsSnap.docs) {
    const orgId = orgDoc.id;
    const orgRef = db.collection('organizations').doc(orgId);
    const locationsSnap = await orgRef.collection('locations').get();

    for (const locDoc of locationsSnap.docs) {
      const locId = locDoc.id;
      const checklistsSnap = await orgRef.collection('locations').doc(locId)
        .collection('daily_checklists')
        .where('date', '==', targetDate)
        .get();

      for (const checklist of checklistsSnap.docs) {
        const data = checklist.data() || {};
        const hasTemplateName = typeof data.templateName === 'string' && data.templateName.trim().length > 0;
        const templateIds = Array.isArray(data.checklistTemplateIds) ? data.checklistTemplateIds : [];

        if (hasTemplateName || templateIds.length === 0) {
          skipped++;
          continue;
        }

        const templateNames = [];
        for (const templateId of templateIds) {
          try {
            const tmplSnap = await orgRef.collection('checklist_templates').doc(templateId).get();
            if (tmplSnap.exists) {
              const tmplData = tmplSnap.data() || {};
              const name = (tmplData.name || '').toString().trim();
              if (name) {
                templateNames.push(name);
              }
            }
          } catch (err) {
            console.warn('Error fetching template', templateId, err.message || err);
          }
        }

        if (templateNames.length === 0) {
          console.log('No template names resolved for', checklist.ref.path);
          skipped++;
          continue;
        }

        const payload = {
          templateNames,
          templateName: templateNames.join(', '),
          lastTemplateNameBackfillAt: new Date().toISOString(),
        };

        await checklist.ref.set(payload, { merge: true });
        updatedChecklists++;

        // Update tasks subcollection with templateName/checklistName if missing
        for (const templateId of templateIds) {
          const templateName = templateNames[templateIds.indexOf(templateId)] || templateNames[0];
          const tasksSnap = await checklist.ref.collection('tasks')
            .where('templateId', '==', templateId)
            .get();
          for (const task of tasksSnap.docs) {
            const taskData = task.data() || {};
            const needsUpdate = !taskData.templateName || !taskData.checklistName;
            if (needsUpdate) {
              await task.ref.set({
                templateName: templateName,
                checklistName: templateName,
                checklistTemplateId: templateId,
              }, { merge: true });
            }
          }
        }

        console.log('Updated', checklist.ref.path, '->', payload.templateName);
      }
    }
  }

  console.log('Updated checklists:', updatedChecklists, 'Skipped:', skipped);
})();
