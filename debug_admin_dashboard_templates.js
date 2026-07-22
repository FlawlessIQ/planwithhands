const { initializeApp } = require('firebase/app');
const { getFirestore, connectFirestoreEmulator, collection, doc, getDocs, getDoc } = require('firebase/firestore');

const firebaseConfig = {
    apiKey: "AIzaSyCiHLr9eYhGkrhHgIdwflC6MoKH7JQfMAs",
    authDomain: "planwithhands.firebaseapp.com",
    databaseURL: "https://planwithhands-default-rtdb.firebaseio.com",
    projectId: "planwithhands",
    storageBucket: "planwithhands.appspot.com",
    messagingSenderId: "1012717094976",
    appId: "1:1012717094976:web:9b1b8e0bab7c67d1c5fcf2",
    measurementId: "G-3WMS9PLSQE"
};

async function debugAdminDashboardTemplates() {
    const app = initializeApp(firebaseConfig);
    const db = getFirestore(app, 'planwithhands');
    
    const orgId = '3qjYzHagWmfbnMieJ1aj';
    
    console.log('\n=== DEBUGGING ADMIN DASHBOARD TEMPLATE ISSUES ===');
    
    // 1. Get all templates first
    console.log('\n1. Available Templates:');
    const templatesRef = collection(db, 'organizations', orgId, 'checklist_templates');
    const templatesSnapshot = await getDocs(templatesRef);
    const templateMap = {};
    
    templatesSnapshot.forEach(doc => {
        const data = doc.data();
        templateMap[doc.id] = data.name || 'NO_NAME';
        console.log(`   ${doc.id}: "${data.name || 'NO_NAME'}"`);
    });
    
    // 2. Get all shifts and their associated checklists
    console.log('\n2. Checking Shifts and Their Template References:');
    const shiftsRef = collection(db, 'organizations', orgId, 'shifts');
    const shiftsSnapshot = await getDocs(shiftsRef);
    
    for (const shiftDoc of shiftsSnapshot.docs) {
        const shiftData = shiftDoc.data();
        console.log(`\n   Shift: "${shiftData.name}" (${shiftDoc.id})`);
        console.log(`   Time: ${shiftData.startTime} - ${shiftData.endTime}`);
        
        // Check shift's checklists array
        if (shiftData.checklists && shiftData.checklists.length > 0) {
            console.log('   Template References in Shift:');
            shiftData.checklists.forEach(templateId => {
                const templateName = templateMap[templateId] || '❌ UNKNOWN TEMPLATE';
                const status = templateMap[templateId] ? '✅' : '❌';
                console.log(`     ${status} ${templateId}: "${templateName}"`);
            });
        } else {
            console.log('   ⚠️  No checklists array or empty');
        }
    }
    
    // 3. Check daily_checklists that might be referenced by admin dashboard
    console.log('\n3. Checking Recent Daily Checklists for Unknown Templates:');
    const locationsRef = collection(db, 'organizations', orgId, 'locations');
    const locationsSnapshot = await getDocs(locationsRef);
    
    for (const locationDoc of locationsSnapshot.docs) {
        const locationId = locationDoc.id;
        console.log(`\n   Location: ${locationId}`);
        
        const dailyChecklistsRef = collection(db, 'organizations', orgId, 'locations', locationId, 'daily_checklists');
        const dailyChecklistsSnapshot = await getDocs(dailyChecklistsRef);
        
        let unknownCount = 0;
        const unknownTemplateIds = new Set();
        
        dailyChecklistsSnapshot.forEach(doc => {
            const data = doc.data();
            if (data.templateId && !templateMap[data.templateId]) {
                unknownCount++;
                unknownTemplateIds.add(data.templateId);
            }
        });
        
        if (unknownCount > 0) {
            console.log(`   ❌ Found ${unknownCount} daily_checklists with unknown template IDs:`);
            unknownTemplateIds.forEach(templateId => {
                console.log(`     - ${templateId} (referenced but template doesn't exist)`);
            });
        } else {
            console.log(`   ✅ All daily_checklists have valid template IDs`);
        }
    }
    
    // 4. Summary
    console.log('\n=== SUMMARY ===');
    console.log(`Total templates available: ${Object.keys(templateMap).length}`);
    console.log('Templates:', Object.entries(templateMap).map(([id, name]) => `"${name}"`).join(', '));
}

debugAdminDashboardTemplates().catch(console.error);