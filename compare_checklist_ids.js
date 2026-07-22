// Compare yesterday's checklist IDs with today's expected IDs
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands'
  });
}

const db = admin.firestore();
db.settings({
  databaseId: 'planwithhands'
});

async function main() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const locationId = 'sYhcOTkX1VkeoPjtPuwZ';
  
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = `${yesterday.getFullYear()}-${String(yesterday.getMonth() + 1).padStart(2, '0')}-${String(yesterday.getDate()).padStart(2, '0')}`;
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

  console.log('🔍 Comparing Checklist IDs');
  console.log('═'.repeat(80));

  // Get yesterday's checklists
  const yesterdaySnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', yesterdayStr)
    .get();

  // Get today's checklists
  const todaySnap = await db
    .collection('organizations')
    .doc(orgId)
    .collection('locations')
    .doc(locationId)
    .collection('daily_checklists')
    .where('date', '==', todayStr)
    .get();

  const todayChecklistIds = new Set(todaySnap.docs.map(d => d.id));

  console.log(`\nYesterday: ${yesterdaySnap.size} checklists`);
  console.log(`Today: ${todaySnap.size} checklists\n`);

  for (const yDoc of yesterdaySnap.docs) {
    const yData = yDoc.data();
    const templateName = yData.templateName;
    const shiftId = yData.shiftId;
    const templateId = yData.checklistTemplateId;

    // Expected today's ID (what carry-forward creates)
    const expectedTodayId = `${orgId}_${locationId}_${shiftId}_${templateId}_${todayStr}`;

    const exists = todayChecklistIds.has(expectedTodayId);

    console.log(`${exists ? '✅' : '❌'} ${templateName}`);
    console.log(`   Yesterday ID: ${yDoc.id.slice(-30)}`);
    console.log(`   Expected today ID: ${expectedTodayId.slice(-30)}`);
    
    if (!exists) {
      console.log(`   ⚠️  TODAY'S CHECKLIST DOESN'T EXIST!`);
      // Check if there's a similar one
      const similar = todaySnap.docs.find(d => 
        d.data().templateName === templateName && 
        d.data().shiftId === shiftId
      );
      if (similar) {
        console.log(`   Found similar: ${similar.id.slice(-30)}`);
        console.log(`   Difference: IDs don't match exactly`);
      } else {
        console.log(`   No today checklist found for this shift/template combo!`);
      }
    }
    console.log();
  }

  console.log('═'.repeat(80));

  process.exit(0);
}

main().catch(error => {
  console.error('Error:', error);
  process.exit(1);
});
