const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function checkActualSummary() {
  try {
    console.log('=== Checking Actual Summary Content Sent ===\n');

    const ORG_ID = 'FErQ4pkcrCovJ7T6L13M';

    // Get the most recent summary log to see what was actually sent
    const logsSnapshot = await db
      .collection('organizations')
      .doc(ORG_ID)
      .collection('daily_summary_logs')
      .orderBy('sentAt', 'desc')
      .limit(1)
      .get();

    if (logsSnapshot.empty) {
      console.log('No summary logs found');
      return;
    }

    const logDoc = logsSnapshot.docs[0];
    const logData = logDoc.data();
    
    console.log(`Date: ${logDoc.id}`);
    console.log(`Sent At: ${logData.sentAt?.toDate()}`);
    console.log('\nLog Data:', JSON.stringify(logData, null, 2));

    // The log should contain the summary data if we're saving it
    // If not, we need to check what the scheduled function actually computed

    console.log('\n' + '='.repeat(60));
    console.log('IMPORTANT NOTE:');
    console.log('The summary logs only record that a summary was sent,');
    console.log('not the actual content. To see what was sent, we need to:');
    console.log('1. Check the Cloud Functions logs');
    console.log('2. Or look at the actual email received');
    console.log('3. Or trigger a test summary manually');
    console.log('='.repeat(60));

  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

checkActualSummary();
