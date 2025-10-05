const { Firestore } = require('@google-cloud/firestore');

// Use the Firestore client bound to the planwithhands database (multi-db project)
const db = new Firestore({ databaseId: 'planwithhands' });

const orgId = process.argv[2] || '3qjYzHagWmfbnMieJ1aj';
const LIMIT = 500;

async function find() {
  try {
    console.log('Using Firestore client with databaseId:', db._settings && db._settings.databaseId);
    console.log('Searching collectionGroup daily_checklists for org', orgId);
    const q = db.collectionGroup('daily_checklists').where('organizationId', '==', orgId).limit(LIMIT);
    const snap = await q.get();
    console.log('Found', snap.size, 'daily_checklists in collectionGroup for org (limited to', LIMIT, ')');
    const missing = [];
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      const hasTemplateName = d.templateName && d.templateName.toString().trim().length > 0;
      const hasTemplateIds = Array.isArray(d.checklistTemplateIds) && d.checklistTemplateIds.length > 0;
      if (!hasTemplateName || !hasTemplateIds) {
        missing.push({ path: doc.ref.path, id: doc.id, date: d.date, templateName: d.templateName || null, checklistTemplateIds: d.checklistTemplateIds || [] });
      }
    }
    if (missing.length === 0) {
      console.log('✅ No daily_checklists missing templateName or checklistTemplateIds for org', orgId);
    } else {
      console.log('❌ Found', missing.length, 'daily_checklists missing templateName or template IDs:');
      missing.forEach(m => {
        console.log('---');
        console.log('path:', m.path);
        console.log('id:', m.id);
        console.log('date:', m.date);
        console.log('templateName:', m.templateName);
        console.log('checklistTemplateIds:', JSON.stringify(m.checklistTemplateIds));
      });
    }
  } catch (err) {
    console.error('Error querying collectionGroup on planwithhands DB:', err);
  }
  process.exit(0);
}

find();
