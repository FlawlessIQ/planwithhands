const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const orgId = process.argv[2] || '3qjYzHagWmfbnMieJ1aj';

async function find() {
  try {
    console.log('Searching collectionGroup daily_checklists for org', orgId);
    const q = db.collectionGroup('daily_checklists').where('organizationId', '==', orgId).limit(100);
    const snap = await q.get();
    console.log('Found', snap.size, 'daily_checklists in collectionGroup for org');
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      console.log('---');
      console.log('docPath:', doc.ref.path);
      console.log('id:', doc.id);
      console.log('date:', d.date);
      console.log('shiftId:', d.shiftId);
      console.log('templateName:', d.templateName || d.templateNames || null);
      console.log('checklistTemplateIds:', JSON.stringify(d.checklistTemplateIds || []));
    }
  } catch (e) {
    console.error('Error:', e);
  }
  process.exit(0);
}

find();
