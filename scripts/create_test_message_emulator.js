// Writes a test message to the Firestore emulator (named DB) to trigger onMessageCreated
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';

const { Firestore } = require('@google-cloud/firestore');

const PROJECT_ID = 'plan-with-hands';
const DATABASE_ID = 'planwithhands';

const db = new Firestore({ projectId: PROJECT_ID, databaseId: DATABASE_ID });

(async () => {
  try {
    const ts = Date.now();
    const threadId = `debug_thread_${ts}`;
    const messageId = `debug_message_${ts}`;
    const senderId = 'debug_user_123';

    console.log('FIRESTORE_EMULATOR_HOST =', process.env.FIRESTORE_EMULATOR_HOST);
    console.log('Using project/database:', PROJECT_ID, DATABASE_ID);

    // Seed minimal users/org data to satisfy lookups
    const orgId = 'debug_org_123';
    await db.collection('users').doc(senderId).set({ firstName: 'Debug', lastName: 'User', organizationId: orgId }, { merge: true });
    await db.collection('organizations').doc(orgId).set({ name: 'Debug Org' }, { merge: true });

    // Create thread
    await db.collection('messageThreads').doc(threadId).set({
      id: threadId,
      orgId,
      recipientUserIds: [senderId, 'debug_recipient_456'],
      createdAt: new Date(),
    });
    console.log('✅ Thread created:', threadId);

    // Create a recipient user and an active token doc (legacy + subcollection)
    const token = 'debug_token_ignore_delivery';
    await db.collection('users').doc('debug_recipient_456').set({ firstName: 'Rec', lastName: 'User', organizationId: orgId }, { merge: true });
    await db.collection('users').doc('debug_recipient_456').collection('deviceTokens').doc('t1').set({ fcmToken: token, isActive: true });

    // Write message that should trigger the function
    await db.collection('messageThreads').doc(threadId).collection('messages').doc(messageId).set({
      id: messageId,
      senderId,
      text: 'Hello from emulator trigger test',
      createdAt: new Date(),
    });
    console.log('✅ Message created:', messageId);

    console.log('\nNow check the Functions emulator logs for onMessageCreated handling.');
  } catch (e) {
    console.error('❌ Error creating test data:', e);
    process.exitCode = 1;
  }
})();
