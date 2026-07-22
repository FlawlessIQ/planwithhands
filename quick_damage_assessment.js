const admin = require('firebase-admin');

// Initialize Firebase Admin using default credentials
if (!admin.apps.length) {
  admin.initializeApp();
}

// Use the planwithhands database
const planWithHandsDb = new admin.firestore.Firestore({ databaseId: 'planwithhands' });

async function quickDamageAssessment() {
  console.log('🚨 QUICK DAMAGE ASSESSMENT - MEMORY EFFICIENT');
  console.log('==============================================\n');

  try {
    // Get all organizations
    const orgsSnapshot = await planWithHandsDb.collection('organizations').get();
    console.log(`📊 Found ${orgsSnapshot.size} organizations\n`);

    // Check each organization with memory-efficient counting
    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const orgData = orgDoc.data();
      const orgName = orgData.organizationName || orgId;
      
      console.log(`🏢 Organization: ${orgName}`);
      
      // Count notifications without loading them all
      const notificationsRef = planWithHandsDb
        .collection('organizations')
        .doc(orgId)
        .collection('notifications');
      
      // Get total count (this is more memory efficient)
      const countQuery = await notificationsRef.count().get();
      const totalCount = countQuery.data().count;
      
      console.log(`   📋 Total notifications: ${totalCount}`);
      
      if (totalCount > 0) {
        // Get first few and last few to see pattern
        const firstBatch = await notificationsRef
          .orderBy('createdAt', 'asc')
          .limit(3)
          .get();
        
        const lastBatch = await notificationsRef
          .orderBy('createdAt', 'desc')
          .limit(3)
          .get();
        
        console.log(`   📅 First notification: ${firstBatch.docs[0]?.data().createdAt?.toDate()}`);
        console.log(`   📅 Last notification: ${lastBatch.docs[0]?.data().createdAt?.toDate()}`);
        
        // Check for duplicates by looking at recent ones
        if (totalCount > 100) {
          console.log(`   🚨 HIGH VOLUME DETECTED! This org has ${totalCount} notifications`);
          
          // Sample a few recent ones to check for duplication pattern
          const sampleDocs = lastBatch.docs.slice(0, 3);
          console.log(`   📝 Recent notification samples:`);
          sampleDocs.forEach((doc, index) => {
            const data = doc.data();
            console.log(`      ${index + 1}. "${data.title}" - ${data.createdAt?.toDate()?.toLocaleString()}`);
          });
        }
      }
      
      console.log(''); // Empty line for readability
      
      // If this org has an extreme number, this is likely the problem org
      if (totalCount > 10000) {
        console.log(`🔥 CRITICAL: Organization "${orgName}" has ${totalCount} notifications!`);
        console.log('This is likely where the infinite loop caused maximum damage.');
        
        // Get a time-based sample to understand the damage timeline
        const oneDayAgo = new Date(Date.now() - (24 * 60 * 60 * 1000));
        const recentQuery = await notificationsRef
          .where('createdAt', '>', oneDayAgo)
          .count()
          .get();
        
        const recentCount = recentQuery.data().count;
        console.log(`   📈 Notifications in last 24h: ${recentCount}`);
        
        if (recentCount > 1000) {
          console.log('   ⚠️  This confirms recent mass duplication!');
        }
      }
    }

    console.log('\n🎯 DAMAGE SUMMARY');
    console.log('==================');
    console.log('Assessment complete. Based on memory constraints and high volumes detected,');
    console.log('it appears the infinite loop created a massive number of duplicate notifications.');
    console.log('\nNext steps:');
    console.log('1. Identify the most affected organization(s)');
    console.log('2. Create a cleanup script to remove duplicates');
    console.log('3. Preserve any legitimate notifications');

  } catch (error) {
    console.error('Error during assessment:', error);
    throw error;
  }
}

// Run the quick assessment
quickDamageAssessment()
  .then(() => {
    console.log('\n✅ Quick assessment complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Assessment failed:', error);
    process.exit(1);
  });
