// Firebase Admin script to debug messaging issues
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json'); // You'll need this file
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://plan-with-hands.firebaseio.com'
});

const db = admin.firestore();

async function debugMessagingSystem() {
  console.log('🔍 DEBUGGING MESSAGING SYSTEM');
  console.log('==============================\n');

  try {
    // Check recent notifications
    console.log('📬 CHECKING RECENT NOTIFICATIONS:');
    const notificationsSnapshot = await db.collectionGroup('notifications')
      .where('type', '==', 'message')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();

    console.log(`Found ${notificationsSnapshot.docs.length} recent message notifications:\n`);

    const notificationsByMessage = {};
    notificationsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const messageId = data.messageId || 'unknown';
      if (!notificationsByMessage[messageId]) {
        notificationsByMessage[messageId] = [];
      }
      notificationsByMessage[messageId].push({
        id: doc.id,
        userId: data.userId,
        threadId: data.threadId,
        createdAt: data.createdAt?.toDate?.() || 'unknown'
      });
    });

    Object.entries(notificationsByMessage).forEach(([messageId, notifications]) => {
      console.log(`Message ID: ${messageId}`);
      console.log(`  Notifications created: ${notifications.length}`);
      if (notifications.length > 1) {
        console.log(`  ⚠️  DUPLICATE DETECTED! Expected 1 per user, found ${notifications.length}`);
      }
      notifications.forEach(notif => {
        console.log(`    - User: ${notif.userId}, Doc ID: ${notif.id}`);
      });
      console.log('');
    });

    // Check messageLocks collection
    console.log('🔒 CHECKING MESSAGE LOCKS:');
    const locksSnapshot = await db.collection('messageLocks')
      .orderBy('processedAt', 'desc')
      .limit(5)
      .get();

    console.log(`Found ${locksSnapshot.docs.length} message locks:\n`);
    locksSnapshot.docs.forEach(doc => {
      const data = doc.data();
      console.log(`Lock ID: ${doc.id}`);
      console.log(`  Thread: ${data.threadId}, Message: ${data.messageId}`);
      console.log(`  Processed: ${data.processedAt?.toDate?.() || 'unknown'}`);
      console.log('');
    });

    // Check for any messages in messageThreads
    console.log('💬 CHECKING RECENT MESSAGES:');
    const messagesSnapshot = await db.collectionGroup('messages')
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();

    console.log(`Found ${messagesSnapshot.docs.length} recent messages:\n`);
    messagesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      console.log(`Message ID: ${doc.id}`);
      console.log(`  Text: ${data.text}`);
      console.log(`  Sender: ${data.senderId}`);
      console.log(`  Created: ${data.createdAt?.toDate?.() || 'unknown'}`);
      console.log('');
    });

  } catch (error) {
    console.error('Error debugging messaging system:', error);
  }
}

debugMessagingSystem().then(() => {
  console.log('✅ Debug complete');
  process.exit(0);
}).catch(console.error);
