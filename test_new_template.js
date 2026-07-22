// Test the improved daily summary template
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

// Use the correct database
const db = admin.firestore();
db.settings({ databaseId: 'planwithhands' });

async function testNewTemplate() {
  console.log('🧪 Testing improved daily summary template...');
  
  try {
    // Test with Hamilton Pork (has good data)
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().split('T')[0];
    
    console.log(`\n📋 Creating test summary for ${yesterdayStr}...`);
    
    // Get admin users
    const adminQuery = await db
      .collection('users')
      .where('organizationId', '==', orgId)
      .where('userRole', 'in', [1, 2])
      .where('isActive', '==', true)
      .limit(1)
      .get();
    
    if (adminQuery.docs.length === 0) {
      console.log('❌ No admin users found');
      return;
    }
    
    const adminData = adminQuery.docs[0].data();
    
    // Create a test notification with the new template
    const notificationRef = db
      .collection('organizations')
      .doc(orgId)
      .collection('notifications')
      .doc();
    
    const testSummary = `🎉 Daily Summary • Tue, Sep 09

Great job! Strong performance across all areas.

📊 87% Complete (26/30 tasks)

📍 By Location:
• Hamilton Pork: 90% (18/20)
• The Hamilton inn: 80% (8/10)

📋 Key Items:
❌ Clean fryer filters (Hamilton Pork)
   Equipment not available
📷 Check inventory levels - photo required but skipped
   Hamilton Pork by Brian Shanahan
📝 Temperature check (The Hamilton inn)
   "Freezer temp slightly high, adjusted" - Aimee Aure

🎯 Next Steps:
• Review and address any missed tasks
• Follow up on missing photos
• Check app for complete task details

📱 View full details in the app`;
    
    const notificationData = {
      title: `Daily Notes Summary - ${yesterday.toLocaleDateString('en-US', { 
        weekday: 'long', 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
      })}`,
      message: testSummary,
      userId: adminQuery.docs[0].id,
      type: 'general',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readBy: [],
      archivedBy: [],
      targetType: 'user',
      targetId: adminQuery.docs[0].id,
      testNotification: true, // Mark as test
      targets: {
        userRole: [1, 2],
        userId: [adminQuery.docs[0].id]
      },
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
    };
    
    await notificationRef.set(notificationData);
    
    console.log('✅ Test notification created successfully!');
    console.log(`   Admin: ${adminData.firstName} ${adminData.lastName}`);
    console.log('   Check the notifications page in the app to see the new format');
    
    console.log('\n📝 New template preview:');
    console.log('─'.repeat(50));
    console.log(testSummary);
    console.log('─'.repeat(50));
    
    console.log('\n🆚 Key improvements:');
    console.log('✨ Shorter, more scannable format');
    console.log('🎯 Performance-based messaging');
    console.log('📱 Mobile-friendly layout');
    console.log('🎯 Actionable next steps');
    console.log('🏆 Positive reinforcement');
    console.log('⚡ Highlights most important items only');
    
  } catch (error) {
    console.error('❌ Error testing template:', error);
  }
  
  process.exit(0);
}

testNewTemplate();
