const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

// Create a Firestore instance that uses the planwithhands database
const db = new Firestore({
  projectId: "plan-with-hands",
  databaseId: "planwithhands",
});

async function reviewDailyData() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  
  // Format as YYYY-MM-DD
  const yesterdayStr = yesterday.toISOString().split('T')[0];
  console.log(`📊 Analyzing daily data for organization ${orgId} on ${yesterdayStr}`);
  console.log('=' .repeat(80));

  try {
    // 1. Get Organization Details
    console.log('\n🏢 Organization Details:');
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    if (orgDoc.exists) {
      const orgData = orgDoc.data();
      console.log(`  Name: ${orgData.name || 'Not set'}`);
      console.log(`  Type: ${orgData.type || 'Not set'}`);
      console.log(`  Created: ${orgData.createdAt?.toDate().toLocaleDateString() || 'Unknown'}`);
      console.log(`  Status: ${orgData.isActive ? 'Active' : 'Inactive'}`);
    } else {
      console.log('  ❌ Organization not found!');
      return;
    }

    // 2. Get Organization Locations
    console.log('\n📍 Locations:');
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    console.log(`  Total locations: ${locationsSnapshot.docs.length}`);
    
    const locations = [];
    locationsSnapshot.docs.forEach(doc => {
      const locationData = doc.data();
      locations.push({
        id: doc.id,
        name: locationData.name,
        address: locationData.address
      });
      console.log(`    - ${locationData.name} (${locationData.address || 'No address'})`);
    });

    if (locations.length === 0) {
      console.log('  ❌ No locations found!');
      return;
    }

    // 3. Get Admin Users
    console.log('\n👥 Admin Users:');
    const usersSnapshot = await db.collection('organizations').doc(orgId).collection('users')
      .where('roles', 'array-contains', 'admin').get();
    
    const adminUsers = [];
    usersSnapshot.docs.forEach(doc => {
      const userData = doc.data();
      adminUsers.push({
        id: doc.id,
        email: userData.email,
        name: userData.name
      });
      console.log(`    - ${userData.name} (${userData.email})`);
    });

    console.log(`  Total admin users: ${adminUsers.length}`);

    // 4. Check for yesterday's daily checklists
    console.log(`\n📋 Daily Checklists for ${yesterdayStr}:`);
    
    let totalChecklists = 0;
    let totalTasks = 0;
    let completedTasks = 0;
    let totalNotes = 0;
    let totalPhotos = 0;
    let missedTasks = 0;
    const allChecklistData = [];

    for (const location of locations) {
      console.log(`\n  📍 Location: ${location.name}`);
      
      // Check new structure: dailyChecklists/{date}/locations/{locationId}/checklists
      const dailyChecklistsRef = db.collection('organizations').doc(orgId)
        .collection('dailyChecklists').doc(yesterdayStr)
        .collection('locations').doc(location.id)
        .collection('checklists');
      
      const checklistsSnapshot = await dailyChecklistsRef.get();
      
      if (checklistsSnapshot.empty) {
        // Try legacy structure: locations/{locationId}/dailyChecklists/{date}
        const legacyRef = db.collection('organizations').doc(orgId)
          .collection('locations').doc(location.id)
          .collection('dailyChecklists').doc(yesterdayStr);
        
        const legacyDoc = await legacyRef.get();
        if (legacyDoc.exists) {
          console.log(`    Found legacy checklist structure`);
          const data = legacyDoc.data();
          totalChecklists++;
          
          if (data.tasks) {
            totalTasks += Object.keys(data.tasks).length;
            Object.values(data.tasks).forEach(task => {
              if (task.status === 'completed') completedTasks++;
              if (task.status === 'missed') missedTasks++;
              if (task.notes) totalNotes++;
              if (task.photos && task.photos.length > 0) totalPhotos += task.photos.length;
            });
          }
          
          allChecklistData.push({
            locationName: location.name,
            data: data,
            type: 'legacy'
          });
        } else {
          console.log(`    ❌ No checklist found`);
        }
      } else {
        console.log(`    Found ${checklistsSnapshot.docs.length} checklists in new structure`);
        totalChecklists += checklistsSnapshot.docs.length;
        
        checklistsSnapshot.docs.forEach(doc => {
          const data = doc.data();
          
          if (data.tasks) {
            totalTasks += Object.keys(data.tasks).length;
            Object.values(data.tasks).forEach(task => {
              if (task.status === 'completed') completedTasks++;
              if (task.status === 'missed') missedTasks++;
              if (task.notes) totalNotes++;
              if (task.photos && task.photos.length > 0) totalPhotos += task.photos.length;
            });
          }
          
          allChecklistData.push({
            locationName: location.name,
            data: data,
            type: 'new',
            checklistId: doc.id
          });
        });
      }
    }

    // 5. Summary Statistics
    console.log('\n📊 Summary Statistics:');
    console.log(`  Total checklists: ${totalChecklists}`);
    console.log(`  Total tasks: ${totalTasks}`);
    console.log(`  Completed tasks: ${completedTasks} (${totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0}%)`);
    console.log(`  Missed tasks: ${missedTasks} (${totalTasks > 0 ? Math.round((missedTasks / totalTasks) * 100) : 0}%)`);
    console.log(`  Tasks with notes: ${totalNotes}`);
    console.log(`  Total photos uploaded: ${totalPhotos}`);

    // 6. Detailed Analysis
    console.log('\n🔍 Detailed Analysis:');
    
    if (allChecklistData.length === 0) {
      console.log('  ❌ No checklist data found for yesterday');
      console.log('  🔍 Possible reasons:');
      console.log('    - No work was scheduled for yesterday');
      console.log('    - Data is in a different date format');
      console.log('    - Checklists are stored in a different collection structure');
      return;
    }

    allChecklistData.forEach((checklist, index) => {
      console.log(`\n  📋 Checklist ${index + 1} - ${checklist.locationName} (${checklist.type} structure):`);
      
      if (checklist.data.metadata) {
        console.log(`    Created: ${checklist.data.metadata.createdAt?.toDate().toLocaleString() || 'Unknown'}`);
        console.log(`    Created by: ${checklist.data.metadata.createdBy || 'Unknown'}`);
      }
      
      if (checklist.data.tasks) {
        const tasks = Object.entries(checklist.data.tasks);
        console.log(`    Tasks: ${tasks.length}`);
        
        // Group by status
        const tasksByStatus = {};
        tasks.forEach(([taskId, task]) => {
          const status = task.status || 'unknown';
          if (!tasksByStatus[status]) tasksByStatus[status] = [];
          tasksByStatus[status].push({ id: taskId, ...task });
        });
        
        Object.entries(tasksByStatus).forEach(([status, statusTasks]) => {
          console.log(`      ${status}: ${statusTasks.length}`);
          
          // Show details for missed tasks
          if (status === 'missed' && statusTasks.length > 0) {
            statusTasks.forEach(task => {
              console.log(`        - ${task.title || 'Untitled'}: ${task.missedReason || 'No reason provided'}`);
            });
          }
          
          // Show tasks with notes
          if (status === 'completed') {
            const tasksWithNotes = statusTasks.filter(task => task.notes);
            if (tasksWithNotes.length > 0) {
              console.log(`        Tasks with notes: ${tasksWithNotes.length}`);
              tasksWithNotes.forEach(task => {
                console.log(`          - ${task.title || 'Untitled'}: "${task.notes.substring(0, 50)}${task.notes.length > 50 ? '...' : ''}"`);
              });
            }
          }
        });
      } else {
        console.log(`    ❌ No tasks found in this checklist`);
      }
    });

    // 7. Generate Sample Daily Summary Content
    console.log('\n📝 Sample Daily Summary Content:');
    console.log('=' .repeat(50));
    
    const completionRate = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
    const missedRate = totalTasks > 0 ? Math.round((missedTasks / totalTasks) * 100) : 0;
    
    let summary = `Daily Summary for ${yesterdayStr}\n\n`;
    summary += `📊 Overview:\n`;
    summary += `• ${totalChecklists} location${totalChecklists !== 1 ? 's' : ''} completed checklists\n`;
    summary += `• ${completedTasks}/${totalTasks} tasks completed (${completionRate}%)\n`;
    
    if (missedTasks > 0) {
      summary += `• ${missedTasks} tasks missed (${missedRate}%)\n`;
    }
    
    if (totalNotes > 0) {
      summary += `• ${totalNotes} tasks included additional notes\n`;
    }
    
    if (totalPhotos > 0) {
      summary += `• ${totalPhotos} photos uploaded for verification\n`;
    }
    
    // Add performance insights
    summary += `\n🎯 Performance Insights:\n`;
    if (completionRate >= 90) {
      summary += `• Excellent completion rate! Team exceeded expectations.\n`;
    } else if (completionRate >= 75) {
      summary += `• Good completion rate, minor room for improvement.\n`;
    } else if (completionRate >= 50) {
      summary += `• Moderate completion rate, consider reviewing processes.\n`;
    } else {
      summary += `• Low completion rate detected, immediate attention needed.\n`;
    }
    
    if (missedTasks > 0) {
      summary += `• ${missedTasks} missed tasks may require follow-up.\n`;
    }
    
    if (totalNotes > 5) {
      summary += `• High level of detailed documentation noted.\n`;
    }
    
    console.log(summary);

    // 8. Recommendations
    console.log('\n💡 Recommendations for Daily Summary Enhancement:');
    
    if (totalChecklists === 0) {
      console.log('  ❗ Critical: No checklist data found');
      console.log('    - Verify data collection is working');
      console.log('    - Check if staff are submitting daily checklists');
      console.log('    - Confirm date format matches expectations');
    } else if (totalTasks === 0) {
      console.log('  ❗ Warning: Checklists found but no tasks');
      console.log('    - Check task template configuration');
      console.log('    - Verify task assignment process');
    } else {
      console.log('  ✅ Data Quality: Good');
      
      if (totalNotes < totalTasks * 0.1) {
        console.log('    - Consider encouraging more detailed task notes');
      }
      
      if (totalPhotos < completedTasks * 0.2) {
        console.log('    - Photo compliance could be improved');
      }
      
      if (missedRate > 20) {
        console.log('    - High missed task rate - investigate causes');
      }
    }

  } catch (error) {
    console.error('❌ Error analyzing daily data:', error);
  }
}

// Run the analysis
reviewDailyData().then(() => {
  console.log('\n✅ Analysis complete');
  process.exit(0);
}).catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});