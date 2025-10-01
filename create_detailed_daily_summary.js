const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'plan-with-hands',
  });
}

const db = admin.firestore();
// Use the correct Firestore database (not the default)
db.settings({ databaseId: 'planwithhands' });

async function createDetailedDailySummary() {
  try {
    console.log('📊 Creating detailed daily summary for Hamilton Pork...\n');
    
    const orgId = 'FErQ4pkcrCovJ7T6L13M';
    const userId = 'sXAEgtodreSTrXU0DUpHKEoq0LC3';
    const userEmail = 'jgondevas@gmail.com';
    const targetDate = '2025-09-29';
    
    // Get organization data
    const orgDoc = await db.collection('organizations').doc(orgId).get();
    const orgData = orgDoc.data();
    
    console.log('🔍 Collecting detailed activity data...\n');
    
    // Detailed analysis by location and shift
    const locationDetails = [];
    let totalTasks = 0;
    let totalCompleted = 0;
    let tasksByShift = {};
    let completionByTemplate = {};
    let timeOfDayAnalysis = {};
    let criticalIssues = [];
    let topPerformers = [];
    let incompleteTasks = [];
    
    // Get all locations
    const locationsSnapshot = await db
      .collection("organizations")
      .doc(orgId)
      .collection("locations")
      .get();
    
    for (const locationDoc of locationsSnapshot.docs) {
      const locationId = locationDoc.id;
      const locationData = locationDoc.data();
      const locationName = locationData.name || "Unknown Location";
      
      console.log(`Analyzing ${locationName}...`);
      
      const locationSummary = {
        name: locationName,
        id: locationId,
        checklists: [],
        totalTasks: 0,
        completedTasks: 0,
        completionRate: 0,
        shifts: {},
        issues: [],
        highlights: []
      };
      
      // Query daily checklists for this location
      const checklistsSnapshot = await db
        .collection("organizations")
        .doc(orgId)
        .collection("locations")
        .doc(locationId)
        .collection("daily_checklists")
        .where("date", "==", targetDate)
        .get();
      
      for (const checklistDoc of checklistsSnapshot.docs) {
        const checklistData = checklistDoc.data();
        const templateName = checklistData.templateName || "Unknown Checklist";
        const shiftName = checklistData.shiftName || "Unknown Shift";
        
        // Initialize shift tracking
        if (!locationSummary.shifts[shiftName]) {
          locationSummary.shifts[shiftName] = {
            checklists: 0,
            tasks: 0,
            completed: 0,
            templates: []
          };
        }
        
        if (!tasksByShift[shiftName]) {
          tasksByShift[shiftName] = { total: 0, completed: 0 };
        }
        
        // Process tasks from subcollection
        const tasksSnapshot = await checklistDoc.ref.collection("tasks").get();
        const checklistTasks = tasksSnapshot.size;
        const checklistCompleted = tasksSnapshot.docs.filter(doc => doc.data().completed).length;
        const checklistRate = checklistTasks > 0 ? Math.round((checklistCompleted / checklistTasks) * 100) : 0;
        
        // Update counters
        totalTasks += checklistTasks;
        totalCompleted += checklistCompleted;
        locationSummary.totalTasks += checklistTasks;
        locationSummary.completedTasks += checklistCompleted;
        locationSummary.shifts[shiftName].checklists++;
        locationSummary.shifts[shiftName].tasks += checklistTasks;
        locationSummary.shifts[shiftName].completed += checklistCompleted;
        locationSummary.shifts[shiftName].templates.push(templateName);
        
        tasksByShift[shiftName].total += checklistTasks;
        tasksByShift[shiftName].completed += checklistCompleted;
        
        // Track completion by template
        if (!completionByTemplate[templateName]) {
          completionByTemplate[templateName] = { total: 0, completed: 0, instances: 0 };
        }
        completionByTemplate[templateName].total += checklistTasks;
        completionByTemplate[templateName].completed += checklistCompleted;
        completionByTemplate[templateName].instances++;
        
        // Analyze individual tasks for insights
        const taskDetails = [];
        let missedCriticalTasks = 0;
        let tasksWithNotes = 0;
        let tasksWithPhotos = 0;
        
        for (const taskDoc of tasksSnapshot.docs) {
          const taskData = taskDoc.data();
          const taskName = taskData.name || 'Unnamed Task';
          
          taskDetails.push({
            name: taskName,
            completed: taskData.completed || false,
            completedAt: taskData.completedAt,
            completedBy: taskData.completedBy,
            notes: taskData.notes,
            photoRequired: taskData.photoRequired,
            photoTaken: taskData.photoTaken,
            critical: taskData.critical || false
          });
          
          if (!taskData.completed) {
            incompleteTasks.push({
              task: taskName,
              checklist: templateName,
              location: locationName,
              shift: shiftName,
              critical: taskData.critical || false
            });
            
            if (taskData.critical) {
              missedCriticalTasks++;
              criticalIssues.push(`${locationName} - ${templateName}: Missing critical task "${taskName}"`);
            }
          }
          
          if (taskData.notes && taskData.notes.trim()) {
            tasksWithNotes++;
          }
          
          if (taskData.photoTaken) {
            tasksWithPhotos++;
          }
        }
        
        // Checklist-level analysis
        const checklistSummary = {
          template: templateName,
          shift: shiftName,
          tasks: checklistTasks,
          completed: checklistCompleted,
          rate: checklistRate,
          missedCritical: missedCriticalTasks,
          notesCount: tasksWithNotes,
          photosCount: tasksWithPhotos,
          startedAt: checklistData.createdAt,
          completedAt: checklistData.updatedAt,
          status: checklistData.status
        };
        
        locationSummary.checklists.push(checklistSummary);
        
        // Identify performance highlights and issues
        if (checklistRate >= 90) {
          locationSummary.highlights.push(`${templateName}: Excellent completion (${checklistRate}%)`);
        } else if (checklistRate < 50) {
          locationSummary.issues.push(`${templateName}: Low completion (${checklistRate}%)`);
        }
        
        if (missedCriticalTasks > 0) {
          locationSummary.issues.push(`${templateName}: ${missedCriticalTasks} critical tasks missed`);
        }
      }
      
      // Calculate location completion rate
      locationSummary.completionRate = locationSummary.totalTasks > 0 
        ? Math.round((locationSummary.completedTasks / locationSummary.totalTasks) * 100) 
        : 0;
      
      locationDetails.push(locationSummary);
    }
    
    // Calculate overall metrics
    const overallCompletionRate = totalTasks > 0 ? Math.round((totalCompleted / totalTasks) * 100) : 0;
    
    // Analyze shift performance
    const shiftPerformance = Object.entries(tasksByShift).map(([shift, data]) => ({
      shift,
      total: data.total,
      completed: data.completed,
      rate: data.total > 0 ? Math.round((data.completed / data.total) * 100) : 0
    })).sort((a, b) => b.rate - a.rate);
    
    // Analyze template performance
    const templatePerformance = Object.entries(completionByTemplate).map(([template, data]) => ({
      template,
      total: data.total,
      completed: data.completed,
      instances: data.instances,
      avgRate: data.total > 0 ? Math.round((data.completed / data.total) * 100) : 0
    })).sort((a, b) => b.avgRate - a.avgRate);
    
    // Find top and bottom performers
    const topTemplates = templatePerformance.slice(0, 3);
    const strugglingTemplates = templatePerformance.slice(-3).reverse();
    
    // Create comprehensive summary
    const detailedSummary = `
🏢 **Hamilton Pork Daily Operations Summary**
📅 **Date:** ${targetDate} | 📊 **Overall Completion:** ${overallCompletionRate}%

═══════════════════════════════════════════════════════════

📈 **EXECUTIVE OVERVIEW**
• **Total Activity:** ${totalTasks} tasks across ${locationDetails.reduce((sum, loc) => sum + loc.checklists.length, 0)} checklists
• **Completion Rate:** ${totalCompleted}/${totalTasks} tasks completed (${overallCompletionRate}%)
• **Locations Active:** ${locationDetails.length}
• **Critical Issues:** ${criticalIssues.length} items requiring attention

═══════════════════════════════════════════════════════════

🏪 **LOCATION PERFORMANCE BREAKDOWN**

${locationDetails.map(location => `
**${location.name}** (${location.completionRate}% completion)
• Checklists: ${location.checklists.length} | Tasks: ${location.completedTasks}/${location.totalTasks}
• Shifts Active: ${Object.keys(location.shifts).join(', ')}

${Object.entries(location.shifts).map(([shift, data]) => 
  `  └ ${shift}: ${data.completed}/${data.tasks} tasks (${data.tasks > 0 ? Math.round(data.completed/data.tasks*100) : 0}%)`
).join('\n')}

${location.highlights.length > 0 ? `✅ **Highlights:**\n${location.highlights.map(h => `  • ${h}`).join('\n')}` : ''}

${location.issues.length > 0 ? `⚠️ **Issues:**\n${location.issues.map(i => `  • ${i}`).join('\n')}` : ''}
`).join('\n')}

═══════════════════════════════════════════════════════════

⏰ **SHIFT PERFORMANCE ANALYSIS**

${shiftPerformance.map((shift, index) => 
  `${index + 1}. **${shift.shift}**: ${shift.completed}/${shift.total} tasks (${shift.rate}%)${
    shift.rate >= 80 ? ' 🟢' : shift.rate >= 60 ? ' 🟡' : ' 🔴'
  }`
).join('\n')}

═══════════════════════════════════════════════════════════

📋 **CHECKLIST TYPE PERFORMANCE**

**🏆 Top Performing:**
${topTemplates.map((template, index) => 
  `${index + 1}. ${template.template}: ${template.avgRate}% (${template.instances} instance${template.instances !== 1 ? 's' : ''})`
).join('\n')}

**⚠️ Needs Attention:**
${strugglingTemplates.map((template, index) => 
  `${index + 1}. ${template.template}: ${template.avgRate}% (${template.instances} instance${template.instances !== 1 ? 's' : ''})`
).join('\n')}

═══════════════════════════════════════════════════════════

🔴 **CRITICAL ISSUES** (${criticalIssues.length})
${criticalIssues.length > 0 ? criticalIssues.map(issue => `• ${issue}`).join('\n') : '✅ No critical issues found'}

═══════════════════════════════════════════════════════════

📝 **INCOMPLETE TASKS REQUIRING FOLLOW-UP** (${incompleteTasks.filter(task => task.critical).length} critical)

${incompleteTasks.filter(task => task.critical).slice(0, 10).map(task => 
  `🔴 **${task.location}** - ${task.checklist}: ${task.task}`
).join('\n')}

${incompleteTasks.filter(task => !task.critical).slice(0, 10).map(task => 
  `⚪ **${task.location}** - ${task.checklist}: ${task.task}`
).join('\n')}

${incompleteTasks.length > 20 ? `\n... and ${incompleteTasks.length - 20} more tasks` : ''}

═══════════════════════════════════════════════════════════

📊 **KEY INSIGHTS & RECOMMENDATIONS**

${overallCompletionRate >= 85 ? '🟢 **Strong Performance:** Overall completion rate is excellent.' : 
  overallCompletionRate >= 70 ? '🟡 **Good Performance:** Solid completion rate with room for improvement.' :
  '🔴 **Performance Concern:** Completion rate below expectations.'}

• **Best Performing Location:** ${locationDetails.sort((a, b) => b.completionRate - a.completionRate)[0]?.name} (${locationDetails.sort((a, b) => b.completionRate - a.completionRate)[0]?.completionRate}%)
• **Needs Focus:** ${locationDetails.sort((a, b) => a.completionRate - b.completionRate)[0]?.name} (${locationDetails.sort((a, b) => a.completionRate - b.completionRate)[0]?.completionRate}%)
• **Most Reliable Shift:** ${shiftPerformance[0]?.shift} (${shiftPerformance[0]?.rate}%)
• **Priority Attention:** ${shiftPerformance[shiftPerformance.length - 1]?.shift} (${shiftPerformance[shiftPerformance.length - 1]?.rate}%)

═══════════════════════════════════════════════════════════

🎯 **ACTION ITEMS FOR TOMORROW**
${criticalIssues.length > 0 ? `• Address ${criticalIssues.length} critical issues identified above` : ''}
• Follow up on ${incompleteTasks.length} incomplete tasks
• Focus training/support on ${strugglingTemplates[0]?.template || 'lowest performing areas'}
• Leverage success strategies from ${topTemplates[0]?.template || 'top performing areas'}

═══════════════════════════════════════════════════════════

📈 **TREND TRACKING**
Previous day comparison will be available once we have historical data.

Generated: ${new Date().toLocaleString()} EST
Report covers: ${targetDate}
`.trim();

    console.log('\n📧 Creating enhanced daily summary...');
    
    // Create the enhanced notification
    const title = `Daily Operations Report - September 29, 2025`;
    
    // Create in-app notification
    const notificationData = {
      userId: userId,
      organizationId: orgId,
      type: 'daily_summary',
      title: title,
      content: detailedSummary,
      date: targetDate,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
      archived: false,
      enhanced: true
    };
    
    const notificationRef = await db.collection('organizations')
      .doc(orgId)
      .collection('notifications')
      .add(notificationData);
    
    console.log(`✅ Created enhanced in-app notification: ${notificationRef.id}`);
    
    // Create detailed email outbox notification
    const outboxData = {
      organizationId: orgId,
      type: 'daily_summary',
      targetType: 'user',
      targetId: userId,
      title: title,
      content: detailedSummary,
      date: targetDate,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      enhanced: true,
      emailData: {
        to: userEmail,
        subject: title,
        templateId: 'daily_summary_detailed',
        templateData: {
          organizationName: orgData.name,
          date: targetDate,
          overallCompletion: overallCompletionRate,
          totalTasks: totalTasks,
          completedTasks: totalCompleted,
          locationsCount: locationDetails.length,
          checklistsCount: locationDetails.reduce((sum, loc) => sum + loc.checklists.length, 0),
          criticalIssues: criticalIssues.length,
          locationDetails: locationDetails,
          shiftPerformance: shiftPerformance,
          templatePerformance: templatePerformance,
          incompleteTasks: incompleteTasks.slice(0, 20), // Limit for email
          criticalIssuesList: criticalIssues,
          topPerformer: locationDetails.sort((a, b) => b.completionRate - a.completionRate)[0],
          needsAttention: locationDetails.sort((a, b) => a.completionRate - b.completionRate)[0]
        }
      }
    };
    
    const outboxRef = await db.collection('organizations')
      .doc(orgId)
      .collection('notificationOutbox')
      .add(outboxData);
    
    console.log(`✅ Created enhanced email outbox: ${outboxRef.id}`);
    
    console.log('\n🎉 Enhanced Daily Summary Created!');
    console.log('\n📊 Summary includes:');
    console.log('  • Executive overview with key metrics');
    console.log('  • Detailed location-by-location breakdown');
    console.log('  • Shift performance analysis');
    console.log('  • Checklist type performance ranking');
    console.log('  • Critical issues identification');
    console.log('  • Incomplete tasks requiring follow-up');
    console.log('  • Actionable insights and recommendations');
    console.log('  • Tomorrow\'s action items');
    
    console.log('\n📱 John will receive a comprehensive report that provides:');
    console.log('  • Clear performance metrics by location and shift');
    console.log('  • Identification of areas needing attention');
    console.log('  • Specific tasks requiring follow-up');
    console.log('  • Data-driven recommendations for improvement');
    
    // Show a preview of the summary
    console.log('\n📋 Preview of enhanced summary:');
    console.log(detailedSummary.substring(0, 1000) + '...\n[truncated]');
    
  } catch (error) {
    console.error('❌ Error creating detailed daily summary:', error);
  }
}

createDetailedDailySummary();