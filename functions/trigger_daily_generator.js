const admin = require('firebase-admin');

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

const { generateForOrgDate } = require('./lib/dailyGenerator');

async function triggerDailyGeneration() {
  console.log('🚀 Manually triggering daily data generation for September 4, 2025...');
  
  try {
    // Get your organization ID from the database
    const db = admin.firestore();
    const orgsSnapshot = await db.collection('organizations').limit(5).get();
    
    if (orgsSnapshot.empty) {
      console.log('❌ No organizations found');
      return;
    }
    
    const dateString = '2025-09-04'; // Today's date
    
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      console.log(`📋 Generating data for organization: ${orgId}`);
      
      try {
        await generateForOrgDate(orgId, dateString);
        console.log(`✅ Successfully generated data for ${orgId}`);
      } catch (error) {
        console.error(`❌ Error generating data for ${orgId}:`, error.message);
      }
    }
    
    console.log('🎉 Daily generation complete!');
  } catch (error) {
    console.error('💥 Error during daily generation:', error);
  }
  
  process.exit(0);
}

triggerDailyGeneration();
