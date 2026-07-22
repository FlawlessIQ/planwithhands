const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    // no explicit databaseURL — use default credentials
  });
}

const db = admin.firestore();
const targetDate = process.argv[2] || '2025-10-03';

async function runPreview() {
  console.log('PREVIEW SCAN: daily_checklists missing templateName or checklistTemplateIds');
  console.log('Date:', targetDate);
  console.log('Scanning all organizations...');

  const orgsSnap = await db.collection('organizations').get();
  console.log('Found orgs:', orgsSnap.size);

  const report = [];

  for (const orgDoc of orgsSnap.docs) {
    const orgId = orgDoc.id;
    const locSnap = await db.collection('organizations').doc(orgId).collection('locations').get();
    if (locSnap.empty) continue;

    for (const loc of locSnap.docs) {
      const locId = loc.id;
      // Query daily_checklists for targetDate under this location
      const q = db.collection('organizations').doc(orgId).collection('locations').doc(locId)
        .collection('daily_checklists').where('date', '==', targetDate);
      const snaps = await q.get();
      for (const doc of snaps.docs) {
        const data = doc.data() || {};
        const hasTemplateName = data.templateName && data.templateName.toString().trim().length > 0;
        const hasTemplateIds = Array.isArray(data.checklistTemplateIds) && data.checklistTemplateIds.length > 0;
        if (!hasTemplateName || !hasTemplateIds) {
          report.push({ orgId, locId, path: doc.ref.path, id: doc.id, date: data.date, templateName: data.templateName || null, checklistTemplateIds: data.checklistTemplateIds || [] });
        }
      }
    }
  }

  if (report.length === 0) {
    console.log('✅ No problematic checklists found for', targetDate);
  } else {
    console.log('❌ Found', report.length, 'problematic checklists:');
    report.forEach(r => {
      console.log('---');
      console.log('org:', r.orgId);
      console.log('loc:', r.locId);
      console.log('path:', r.path);
      console.log('id:', r.id);
      console.log('date:', r.date);
      console.log('templateName:', r.templateName);
      console.log('checklistTemplateIds:', JSON.stringify(r.checklistTemplateIds));
    });
  }

  process.exit(0);
}

runPreview();
