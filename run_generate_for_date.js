const admin = require('firebase-admin');

// Initialize Firebase Admin if not already
if (!admin.apps.length) {
  admin.initializeApp();
}

// Require the compiled generator (uses Firestore with databaseId)
const { generateForOrgDate } = require('./functions/lib/dailyGenerator');
// admin already required above; initialize app if needed
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const arg1 = process.argv[2] || '3qjYzHagWmfbnMieJ1aj';
const dateString = process.argv[3] || '2025-10-02';

(async () => {
  try {
    if (arg1 === 'all') {
      console.log(`Running generator for ALL orgs for date=${dateString}`);
      const orgsSnap = await db.collection('organizations').get();
      for (const orgDoc of orgsSnap.docs) {
        const orgId = orgDoc.id;
        console.log(`-- Generating for org ${orgId}`);
        try {
          await generateForOrgDate(orgId, dateString);
          console.log(`   ✅ ${orgId}`);
        } catch (e) {
          console.error(`   ❌ ${orgId}:`, e && e.message ? e.message : e);
        }
      }
      console.log('All org generation complete.');
    } else {
      const orgId = arg1;
      console.log(`Running generator for org=${orgId} date=${dateString}`);
      await generateForOrgDate(orgId, dateString);
      console.log('Done.');
    }
  } catch (err) {
    console.error('Error running generator:', err);
  }
  process.exit(0);
})();
