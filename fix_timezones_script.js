// Fix missing timezones for organizations and locations
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

// Use the correct database
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function fixTimezones() {
  console.log('🔧 Fixing missing timezones...');
  
  try {
    // Organizations that need timezones fixed (based on our analysis)
    const organizationsToFix = [
      { id: 'vnE0olvi1Tswjtdb19MI', name: 'Flawless Pubs', timezone: 'America/New_York' },
      { id: 'FErQ4pkcrCovJ7T6L13M', name: 'Hamilton Pork', timezone: 'America/New_York' },
      { id: 'NTOwK6UJimTs2bADr3qM', name: 'Hudson Hall', timezone: 'America/New_York' },
      { id: '3zIkmQ4wNhdLTcxjW2Wv', name: 'Test pub', timezone: 'America/New_York' },
      { id: 'UnfSxn25GWnbrrahhGRa', name: 'Test Group', timezone: 'America/New_York' },
      { id: 'aLfnORxgpQvacGNP8q4v', name: 'Giovannis Pizza Italian Restaurant', timezone: 'America/New_York' },
      { id: 'OGddY8aiyi1aGhRLPIwx', name: 'Hudson Hall', timezone: 'America/New_York' }
    ];
    
    for (const org of organizationsToFix) {
      console.log(`\n🏢 Fixing ${org.name} (${org.id})`);
      
      // Update organization timezone
      await db.collection('organizations').doc(org.id).update({
        timezone: org.timezone,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`   ✅ Organization timezone set to ${org.timezone}`);
      
      // Update all locations in this organization
      const locationsQuery = await db
        .collection('organizations')
        .doc(org.id)
        .collection('locations')
        .get();
      
      console.log(`   Found ${locationsQuery.docs.length} locations to update`);
      
      for (const locDoc of locationsQuery.docs) {
        const locData = locDoc.data();
        await locDoc.ref.update({
          timezone: org.timezone,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`     ✅ Location "${locData.locationName || 'Unknown'}" timezone set to ${org.timezone}`);
      }
    }
    
    console.log('\n🎉 All timezones fixed successfully!');
    console.log('\nNext steps:');
    console.log('1. The scheduledDailyGenerator should now process these organizations');
    console.log('2. The DailyBackgroundService should start sending summaries');
    console.log('3. Check logs in a few minutes to verify');
    
  } catch (error) {
    console.error('❌ Error fixing timezones:', error);
  }
  
  process.exit(0);
}

fixTimezones();
