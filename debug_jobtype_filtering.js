const { initializeApp } = require('firebase/app');
const { getFirestore, collection, getDocs, query, where } = require('firebase/firestore');

// Initialize Firebase (use your config)
const firebaseConfig = {
  // Add your Firebase config here if needed for direct access
  // For now, we'll assume admin SDK is configured
};

const admin = require('firebase-admin');

// Initialize admin SDK if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function debugJobTypeFiltering() {
  console.log('🔍 Debugging Job Type Filtering...\n');

  try {
    // 1. Check ChecklistTemplates - what job types do they have?
    console.log('📋 === CHECKLIST TEMPLATES ===');
    const templatesSnapshot = await db.collection('checklistTemplates').get();
    
    if (!templatesSnapshot.empty) {
      templatesSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`Template ID: ${doc.id}`);
        console.log(`  Name: ${data.name || 'N/A'}`);
        console.log(`  JobTypes: ${JSON.stringify(data.jobTypes || data.jobType || 'NONE')}`);
        console.log(`  Description: ${data.description || 'N/A'}`);
        console.log('---');
      });
    } else {
      console.log('❌ No checklist templates found');
    }

    // 2. Check actual DailyChecklists - what job types do they have?
    console.log('\n📋 === DAILY CHECKLISTS ===');
    const checklistsSnapshot = await db.collectionGroup('dailyChecklists').limit(10).get();
    
    if (!checklistsSnapshot.empty) {
      checklistsSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`Checklist ID: ${doc.id}`);
        console.log(`  Name: ${data.name || 'N/A'}`);
        console.log(`  JobTypes: ${JSON.stringify(data.jobTypes || data.jobType || 'NONE')}`);
        console.log(`  TemplateId: ${data.templateId || 'N/A'}`);
        console.log(`  Date: ${data.date || 'N/A'}`);
        console.log(`  Path: ${doc.ref.path}`);
        console.log('---');
      });
    } else {
      console.log('❌ No daily checklists found');
    }

    // 3. Check Users - what job types do they have?
    console.log('\n👥 === USERS ===');
    const usersSnapshot = await db.collection('users').limit(10).get();
    
    if (!usersSnapshot.empty) {
      usersSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`User ID: ${doc.id}`);
        console.log(`  Name: ${data.firstName || 'N/A'} ${data.lastName || 'N/A'}`);
        console.log(`  Email: ${data.email || data.emailAddress || 'N/A'}`);
        console.log(`  Role: ${data.userRole || 'N/A'}`);
        console.log(`  JobTypes: ${JSON.stringify(data.jobTypes || data.jobType || 'NONE')}`);
        console.log('---');
      });
    } else {
      console.log('❌ No users found');
    }

    // 4. Check specific Kitchen Staff vs Bartender issue
    console.log('\n🔍 === KITCHEN VS BARTENDER ANALYSIS ===');
    
    // Find kitchen staff users
    const kitchenUsersSnapshot = await db.collection('users')
      .where('jobTypes', 'array-contains-any', ['Kitchen Staff', 'kitchen staff', 'Kitchen', 'kitchen'])
      .get();
    
    console.log(`Found ${kitchenUsersSnapshot.size} kitchen staff users:`);
    kitchenUsersSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`  - ${data.firstName} ${data.lastName}: ${JSON.stringify(data.jobTypes || data.jobType)}`);
    });

    // Find bartender templates/checklists
    const bartenderTemplatesSnapshot = await db.collection('checklistTemplates')
      .where('jobTypes', 'array-contains-any', ['Bartender', 'bartender', 'Bar'])
      .get();
    
    console.log(`\nFound ${bartenderTemplatesSnapshot.size} bartender templates:`);
    bartenderTemplatesSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`  - ${data.name}: ${JSON.stringify(data.jobTypes || data.jobType)}`);
    });

  } catch (error) {
    console.error('❌ Error debugging job type filtering:', error);
  }
}

// Run the debug
debugJobTypeFiltering().then(() => {
  console.log('\n✅ Debug complete');
  process.exit(0);
}).catch(console.error);