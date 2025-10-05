const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials
admin.initializeApp({
  databaseURL: 'https://planwithhands-default-rtdb.europe-west1.firebasedatabase.app'
});

const db = admin.firestore();
const orgId = '3qjYzHagWmfbnMieJ1aj';

async function debugOrganization() {
  console.log('🔍 Debugging Organization:', orgId);
  console.log('=' .repeat(80));
  
  try {
    // 1. Check if organization exists
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (!orgDoc.exists) {
      console.log('❌ Organization does not exist');
      return;
    }
    
    const orgData = orgDoc.data();
    console.log('✅ Organization found:', {
      name: orgData.name,
      timezone: orgData.timezone,
      created: orgData.created,
      updated: orgData.updated
    });
    
    // 2. Check locations
    console.log('\n📍 Locations:');
    const locationsSnapshot = await db.collection('organizations').doc(orgId)
      .collection('locations').get();
    
    console.log(`Found ${locationsSnapshot.size} locations:`);
    for (const locDoc of locationsSnapshot.docs) {
      const locData = locDoc.data();
      console.log(`  - ${locDoc.id}: ${locData.name || 'Unnamed'}`);
    }
    
    // 3. Check shifts
    console.log('\n⏰ Shifts:');
    const shiftsSnapshot = await db.collection('organizations').doc(orgId)
      .collection('shifts').get();
    
    console.log(`Found ${shiftsSnapshot.size} shifts:`);
    for (const shiftDoc of shiftsSnapshot.docs) {
      const shiftData = shiftDoc.data();
      console.log(`  - ${shiftDoc.id}: ${shiftData.name || 'Unnamed'} (${shiftData.startTime || 'No start'} - ${shiftData.endTime || 'No end'})`);
    }
    
    // 4. Check job types
    console.log('\n💼 Job Types:');
    const jobTypesSnapshot = await db.collection('organizations').doc(orgId)
      .collection('job_types').get();
    
    console.log(`Found ${jobTypesSnapshot.size} job types:`);
    for (const jobDoc of jobTypesSnapshot.docs) {
      const jobData = jobDoc.data();
      console.log(`  - ${jobDoc.id}: ${jobData.name || 'Unnamed'}`);
    }
    
    // 5. Check templates
    console.log('\n📋 Templates:');
    const templatesSnapshot = await db.collection('organizations').doc(orgId)
      .collection('checklist_templates').get();
    
    console.log(`Found ${templatesSnapshot.size} templates:`);
    for (const templateDoc of templatesSnapshot.docs) {
      const templateData = templateDoc.data();
      console.log(`  - ${templateDoc.id}: ${templateData.name || 'Unnamed'} (Active: ${templateData.isActive})`);
      
      // Check template tasks
      const tasksSnapshot = await templateDoc.ref.collection('tasks').get();
      console.log(`    Tasks: ${tasksSnapshot.size}`);
    }
    
    // 6. Check daily checklists
    console.log('\n📅 Daily Checklists (Last 7 days):');
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    
    const checklistsSnapshot = await db.collection('organizations').doc(orgId)
      .collection('daily_checklists')
      .where('date', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
      .orderBy('date', 'desc')
      .get();
    
    console.log(`Found ${checklistsSnapshot.size} daily checklists in last 7 days:`);
    
    const checklistsByLocation = {};
    for (const checklistDoc of checklistsSnapshot.docs) {
      const checklistData = checklistDoc.data();
      const locationId = checklistData.locationId;
      
      if (!checklistsByLocation[locationId]) {
        checklistsByLocation[locationId] = [];
      }
      checklistsByLocation[locationId].push({
        id: checklistDoc.id,
        date: checklistData.date?.toDate(),
        shift: checklistData.shift,
        jobType: checklistData.jobType,
        createdBy: checklistData.createdBy
      });
    }
    
    for (const [locationId, checklists] of Object.entries(checklistsByLocation)) {
      console.log(`  Location ${locationId}: ${checklists.length} checklists`);
      checklists.slice(0, 3).forEach(checklist => {
        console.log(`    - ${checklist.date?.toISOString().split('T')[0]} | ${checklist.shift} | ${checklist.jobType}`);
      });
    }
    
    // 7. Check for missed tasks
    console.log('\n❌ Checking for missed tasks:');
    let totalMissedTasks = 0;
    
    for (const checklistDoc of checklistsSnapshot.docs) {
      const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
      
      for (const taskDoc of tasksSnapshot.docs) {
        const taskData = taskDoc.data();
        if (!taskData.completed) {
          totalMissedTasks++;
        }
      }
    }
    
    console.log(`Total missed tasks in last 7 days: ${totalMissedTasks}`);
    
    // 8. Check users
    console.log('\n👥 Users:');
    const usersSnapshot = await db.collection('organizations').doc(orgId)
      .collection('users').get();
    
    console.log(`Found ${usersSnapshot.size} users:`);
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      console.log(`  - ${userDoc.id}: ${userData.displayName || 'No name'} (${userData.role || 'No role'})`);
    }
    
    console.log('\n' + '=' .repeat(80));
    console.log('🔍 Debug completed for organization:', orgId);
    
  } catch (error) {
    console.error('❌ Error debugging organization:', error);
  }
  
  process.exit(0);
}

debugOrganization();