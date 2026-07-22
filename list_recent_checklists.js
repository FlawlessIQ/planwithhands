const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials and specific database
const app = admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore(app, 'planwithhands');
const orgId = '3qjYzHagWmfbnMieJ1aj';
const locationId = 'sYhcOTkX1VkeoPjtPuwZ'; // Lakeside BBQ

async function listRecent() {
  try {
    console.log('Listing recent daily_checklists for', orgId, locationId);
    const q = db.collection('organizations').doc(orgId)
      .collection('locations').doc(locationId)
      .collection('daily_checklists')
      .orderBy('createdAt', 'desc')
      .limit(20);

    const snap = await q.get();
    console.log('Found', snap.size, 'checklists');
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      console.log('-----');
      console.log('id:', doc.id);
      console.log('date:', d.date);
      console.log('createdAt:', d.createdAt && d.createdAt.toDate && d.createdAt.toDate());
      console.log('createdBy:', d.createdBy);
      console.log('templateName:', d.templateName || d.templateNames || d.checklistTemplateName || null);
      console.log('checklistTemplateIds:', JSON.stringify(d.checklistTemplateIds || d.templateIds || []));
    }
  } catch (e) {
    console.error('Error listing checklists:', e);
  }
  process.exit(0);
}

listRecent();
