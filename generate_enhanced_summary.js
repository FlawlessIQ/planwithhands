const admin = require('firebase-admin');
const {Firestore} = require('@google-cloud/firestore');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

// Use the same database connection as the actual functions
const FIRESTORE_DATABASE_ID = process.env.FIRESTORE_DATABASE_ID || "planwithhands";
const db = new Firestore({ databaseId: FIRESTORE_DATABASE_ID });

async function generateEnhancedSummary() {
  const orgId = '3qjYzHagWmfbnMieJ1aj';
  const targetDate = '2025-09-26';
  
  console.log(`📊 Enhanced Daily Summary for ${targetDate}`);
  console.log(`Organization: Conor's pub Group`);
  console.log('=' .repeat(60));

  try {
    // Get organization data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    
    // Get locations
    const locationsSnapshot = await db.collection('organizations').doc(orgId).collection('locations').get();
    const locations = [];
    locationsSnapshot.docs.forEach(doc => {
      const locationData = doc.data();
      locations.push({
        id: doc.id,
        name: locationData.locationName || locationData.name || 'Unnamed',
        address: locationData.address
      });
    });

    // Get user names for attribution
    const usersSnapshot = await db.collection('users').where('organizationId', '==', orgId).get();
    const userNames = {};
    usersSnapshot.docs.forEach(doc => {
      const userData = doc.data();
      userNames[doc.id] = `${userData.firstName || ''} ${userData.lastName || ''}`.trim() || 'Unknown User';
    });

    // Collect data for each location
    let totalTasks = 0;
    let completedTasks = 0;
    let missedTasks = 0;
    let tasksWithNotes = 0;
    let tasksWithPhotos = 0;
    let photoBypassCount = 0;
    
    const locationSummaries = [];
    const notesEntries = [];
    const missedTaskEntries = [];
    const photoBypassEntries = [];
    const performanceIssues = [];

    console.log('\n📍 Processing Locations:\n');

    for (const location of locations) {
      console.log(`Analyzing ${location.name}...`);
      
      // Get checklists for this location on target date
      const checklistsRef = db.collection('organizations')
        .doc(orgId)
        .collection('locations')
        .doc(location.id)
        .collection('daily_checklists')
        .where('date', '==', targetDate);
      
      const checklistsSnapshot = await checklistsRef.get();
      
      let locationTasks = 0;
      let locationCompleted = 0;
      let locationMissed = 0;
      let locationNotes = 0;
      let locationPhotos = 0;
      let locationPhotoBypass = 0;
      
      if (checklistsSnapshot.empty) {
        console.log(`  No checklists found for ${location.name}`);
        continue;
      }

      console.log(`  Found ${checklistsSnapshot.docs.length} checklists`);

      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || 'Unknown Template';
        const shiftName = checklistData.shiftName || 'Unknown Shift';
        
        // Process tasks from subcollection (primary structure)
        const tasksSnapshot = await checklistDoc.ref.collection('tasks').get();
        
        for (const taskDoc of tasksSnapshot.docs) {
          const taskData = taskDoc.data();
          const taskName = taskData.taskName || taskData.description || taskData.title || 'Unknown Task';
          const isCompleted = taskData.completed || taskData.isCompleted || false;
          const photoRequired = taskData.photoRequired || false;
          const hasPhoto = !!(taskData.proofImageUrl || taskData.photoUrl);
          
          locationTasks++;
          totalTasks++;
          
          if (isCompleted) {
            locationCompleted++;
            completedTasks++;
            
            // Check for notes
            if (taskData.notes && taskData.notes.trim()) {
              locationNotes++;
              tasksWithNotes++;
              
              const userId = taskData.completedByUserId;
              const userName = userId ? (userNames[userId] || 'Unknown User') : 'Unknown User';
              
              notesEntries.push({
                taskName,
                shiftName,
                templateName,
                locationName: location.name,
                userName,
                notes: taskData.notes,
                completedAt: taskData.completedAt
              });
            }
            
            // Check for photos
            if (hasPhoto) {
              locationPhotos++;
              tasksWithPhotos++;
            }
            
            // Check for photo bypass (completed but no photo when required)
            if (photoRequired && !hasPhoto) {
              locationPhotoBypass++;
              photoBypassCount++;
              
              const userId = taskData.completedByUserId;
              const userName = userId ? (userNames[userId] || 'Unknown User') : 'Unknown User';
              
              photoBypassEntries.push({
                taskName,
                shiftName,
                templateName,
                locationName: location.name,
                userName,
                completedAt: taskData.completedAt
              });
            }
          } else {
            // Check for missed task reasons
            const reason = taskData.reason || taskData.notCompletedReason || taskData.missedReason;
            if (reason && reason.trim()) {
              locationMissed++;
              missedTasks++;
              
              missedTaskEntries.push({
                taskName,
                shiftName,
                templateName,
                locationName: location.name,
                reason
              });
            }
          }
        }
        
        // Also process legacy tasks array if present
        const legacyTasks = checklistData.tasks || [];
        for (const taskData of legacyTasks) {
          const taskName = taskData.taskName || taskData.description || taskData.title || 'Unknown Task';
          const isCompleted = taskData.completed || taskData.isCompleted || false;
          const photoRequired = taskData.photoRequired || false;
          const hasPhoto = !!(taskData.proofImageUrl || taskData.photoUrl);
          
          locationTasks++;
          totalTasks++;
          
          if (isCompleted) {
            locationCompleted++;
            completedTasks++;
            
            if (taskData.notes && taskData.notes.trim()) {
              locationNotes++;
              tasksWithNotes++;
              
              const userId = taskData.completedByUserId;
              const userName = userId ? (userNames[userId] || 'Unknown User') : 'Unknown User';
              
              notesEntries.push({
                taskName,
                shiftName,
                templateName,
                locationName: location.name,
                userName,
                notes: taskData.notes,
                completedAt: taskData.completedAt
              });
            }
            
            if (hasPhoto) {
              locationPhotos++;
              tasksWithPhotos++;
            }
            
            if (photoRequired && !hasPhoto) {
              locationPhotoBypass++;
              photoBypassCount++;
              
              const userId = taskData.completedByUserId;
              const userName = userId ? (userNames[userId] || 'Unknown User') : 'Unknown User';
              
              photoBypassEntries.push({
                taskName,
                shiftName,
                templateName,
                locationName: location.name,
                userName,
                completedAt: taskData.completedAt
              });
            }
          } else {
            const reason = taskData.reason || taskData.notCompletedReason || taskData.missedReason;
            if (reason && reason.trim()) {
              locationMissed++;
              missedTasks++;
              
              missedTaskEntries.push({
                taskName,
                shiftName,
                templateName,
                locationName: location.name,
                reason
              });
            }
          }
        }
      }
      
      const locationCompletionRate = locationTasks > 0 ? Math.round((locationCompleted / locationTasks) * 100) : 0;
      
      locationSummaries.push({
        name: location.name,
        totalTasks: locationTasks,
        completedTasks: locationCompleted,
        completionRate: locationCompletionRate,
        notesCount: locationNotes,
        photosCount: locationPhotos,
        photoBypassCount: locationPhotoBypass,
        checklists: checklistsSnapshot.docs.length
      });
      
      // Identify performance issues
      if (locationTasks > 0) {
        if (locationCompletionRate < 30) {
          performanceIssues.push(`${location.name}: Critical completion rate (${locationCompletionRate}%)`);
        } else if (locationCompletionRate < 60) {
          performanceIssues.push(`${location.name}: Below target completion rate (${locationCompletionRate}%)`);
        }
        
        if (locationPhotoBypass > 0) {
          performanceIssues.push(`${location.name}: ${locationPhotoBypass} tasks completed without required photos`);
        }
      }
      
      console.log(`  Tasks: ${locationCompleted}/${locationTasks} (${locationCompletionRate}%)`);
    }

    // Generate the enhanced daily summary content
    const overallCompletionRate = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0;
    const missedTaskRate = totalTasks > 0 ? Math.round(((totalTasks - completedTasks) / totalTasks) * 100) : 0;
    
    console.log('\n📧 ENHANCED DAILY SUMMARY CONTENT:');
    console.log('=' .repeat(60));
    
    let summary = `Daily Summary for ${targetDate}\n`;
    summary += `Conor's pub Group\n\n`;
    
    // Executive Summary
    summary += `📊 EXECUTIVE SUMMARY\n`;
    summary += `• ${completedTasks}/${totalTasks} tasks completed across ${locationSummaries.length} locations\n`;
    summary += `• Overall completion rate: ${overallCompletionRate}%\n`;
    if (missedTasks > 0) {
      summary += `• ${missedTasks} tasks with documented reasons for incompletion\n`;
    }
    if (tasksWithNotes > 0) {
      summary += `• ${tasksWithNotes} tasks included detailed notes\n`;
    }
    if (tasksWithPhotos > 0) {
      summary += `• ${tasksWithPhotos} tasks included photo verification\n`;
    }
    
    // Performance Analysis
    summary += `\n🎯 PERFORMANCE ANALYSIS\n`;
    if (overallCompletionRate >= 90) {
      summary += `• Excellent performance! Team exceeded expectations with ${overallCompletionRate}% completion\n`;
    } else if (overallCompletionRate >= 75) {
      summary += `• Good performance with ${overallCompletionRate}% completion, minor improvements possible\n`;
    } else if (overallCompletionRate >= 50) {
      summary += `• Moderate performance at ${overallCompletionRate}% - review processes recommended\n`;
    } else {
      summary += `• ⚠️ Critical: Low completion rate of ${overallCompletionRate}% requires immediate attention\n`;
    }
    
    // Location Performance
    summary += `\n📍 LOCATION PERFORMANCE\n`;
    locationSummaries.forEach(loc => {
      const statusIcon = loc.completionRate >= 75 ? '✅' : loc.completionRate >= 50 ? '⚠️' : '🚨';
      summary += `${statusIcon} ${loc.name}: ${loc.completedTasks}/${loc.totalTasks} tasks (${loc.completionRate}%)\n`;
      if (loc.notesCount > 0) {
        summary += `   📝 ${loc.notesCount} tasks with notes\n`;
      }
      if (loc.photoBypassCount > 0) {
        summary += `   📸 ${loc.photoBypassCount} photo requirements bypassed\n`;
      }
    });
    
    // Issues and Recommendations
    if (performanceIssues.length > 0) {
      summary += `\n🚨 CRITICAL ISSUES IDENTIFIED\n`;
      performanceIssues.forEach(issue => {
        summary += `• ${issue}\n`;
      });
    }
    
    // Detailed Notes Section
    if (notesEntries.length > 0) {
      summary += `\n📝 DETAILED TASK NOTES (${notesEntries.length} entries)\n`;
      notesEntries.slice(0, 10).forEach(entry => {
        summary += `• ${entry.locationName} - ${entry.taskName}\n`;
        summary += `  ${entry.userName}: "${entry.notes}"\n`;
      });
      
      if (notesEntries.length > 10) {
        summary += `... and ${notesEntries.length - 10} more detailed notes\n`;
      }
    }
    
    // Missed Tasks Section
    if (missedTaskEntries.length > 0) {
      summary += `\n❌ INCOMPLETE TASKS WITH REASONS (${missedTaskEntries.length} entries)\n`;
      missedTaskEntries.slice(0, 10).forEach(entry => {
        summary += `• ${entry.locationName} - ${entry.taskName}\n`;
        summary += `  Reason: ${entry.reason}\n`;
      });
      
      if (missedTaskEntries.length > 10) {
        summary += `... and ${missedTaskEntries.length - 10} more incomplete tasks\n`;
      }
    }
    
    // Photo Compliance Issues
    if (photoBypassEntries.length > 0) {
      summary += `\n📸 PHOTO COMPLIANCE ISSUES (${photoBypassEntries.length} entries)\n`;
      photoBypassEntries.slice(0, 5).forEach(entry => {
        summary += `• ${entry.locationName} - ${entry.taskName} (by ${entry.userName})\n`;
      });
      
      if (photoBypassEntries.length > 5) {
        summary += `... and ${photoBypassEntries.length - 5} more photo compliance issues\n`;
      }
    }
    
    // Action Items
    summary += `\n💡 RECOMMENDED ACTIONS\n`;
    if (overallCompletionRate < 60) {
      summary += `• 🎯 Priority: Address low completion rates through staff training or process review\n`;
    }
    if (photoBypassCount > 0) {
      summary += `• 📸 Reinforce photo compliance requirements with team\n`;
    }
    if (missedTaskEntries.length > 5) {
      summary += `• 📋 Review workflow efficiency - high number of incomplete tasks\n`;
    }
    
    const bestLocation = locationSummaries.reduce((best, current) => 
      current.completionRate > best.completionRate ? current : best
    );
    
    const worstLocation = locationSummaries.reduce((worst, current) => 
      current.completionRate < worst.completionRate ? current : worst
    );
    
    if (bestLocation.completionRate !== worstLocation.completionRate) {
      summary += `• 🏆 Share best practices from ${bestLocation.name} (${bestLocation.completionRate}%) with ${worstLocation.name} (${worstLocation.completionRate}%)\n`;
    }
    
    summary += `\nGenerated: ${new Date().toLocaleString()}\nFor questions, contact your management team.`;
    
    console.log(summary);
    
    console.log('\n' + '=' .repeat(60));
    console.log('📈 SUMMARY COMPARISON:');
    console.log('BEFORE (Old Daily Summary): Minimal content, basic statistics only');
    console.log('AFTER (Enhanced Daily Summary): Rich insights, actionable recommendations, detailed analysis');
    
    console.log(`\n🎯 KEY IMPROVEMENTS:`);
    console.log(`• Performance analysis with specific completion rates by location`);
    console.log(`• Critical issue identification (${performanceIssues.length} issues flagged)`);
    console.log(`• Detailed task notes included (${notesEntries.length} entries)`);
    console.log(`• Photo compliance tracking (${photoBypassCount} issues identified)`);
    console.log(`• Specific actionable recommendations for improvement`);
    console.log(`• Location-to-location performance comparison`);

  } catch (error) {
    console.error('❌ Error generating enhanced summary:', error);
  }
}

// Run the enhanced summary generation
generateEnhancedSummary().then(() => {
  console.log('\n✅ Enhanced summary generation complete');
  process.exit(0);
}).catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});