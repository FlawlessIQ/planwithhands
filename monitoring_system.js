const { getDB, admin } = require('./firebase_config');
const { validateLocationConsistency } = require('./validate_location_consistency');

const db = getDB();

/**
 * Monitoring and alerting system for location consistency issues
 * This should be run as a scheduled job (daily/weekly)
 */

async function saveMonitoringReport(report) {
  const timestamp = new Date().toISOString();
  const reportId = `validation_${Date.now()}`;
  
  try {
    await db.collection('system_monitoring')
      .doc('location_consistency')
      .collection('reports')
      .doc(reportId)
      .set({
        timestamp,
        ...report,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    
    // Update latest status
    await db.collection('system_monitoring')
      .doc('location_consistency')
      .set({
        lastCheck: timestamp,
        lastCheckResult: report.success ? 'SUCCESS' : 'ISSUES_FOUND',
        issueCount: report.issues?.length || 0,
        highSeverityCount: report.highSeverityCount || 0,
        mediumSeverityCount: report.mediumSeverityCount || 0,
        lowSeverityCount: report.lowSeverityCount || 0,
        stats: report.stats,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

    console.log(`📊 Monitoring report saved as ${reportId}`);
  } catch (error) {
    console.error('❌ Failed to save monitoring report:', error);
  }
}

async function sendAlertIfNeeded(report) {
  if (!report.success && report.highSeverityCount > 0) {
    console.log('🚨 HIGH SEVERITY ISSUES DETECTED - SENDING ALERT');
    
    try {
      // Save alert to database for dashboard
      await db.collection('system_alerts').add({
        type: 'LOCATION_CONSISTENCY_CRITICAL',
        severity: 'HIGH',
        title: 'Critical Location Consistency Issues Detected',
        message: `Found ${report.highSeverityCount} high severity and ${report.mediumSeverityCount} medium severity location consistency issues that need immediate attention.`,
        details: {
          issueCount: report.issues?.length || 0,
          highSeverityCount: report.highSeverityCount,
          mediumSeverityCount: report.mediumSeverityCount,
          affectedOrgs: [...new Set(report.issues?.map(i => i.orgName) || [])],
          issues: report.issues?.filter(i => i.severity === 'HIGH').slice(0, 5) // Top 5 issues
        },
        acknowledged: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)) // 7 days
      });

      console.log('✅ Alert saved to database');

      // Here you could add additional alerting:
      // - Send email notifications
      // - Send Slack messages
      // - Send push notifications
      // - Trigger webhooks
      
    } catch (error) {
      console.error('❌ Failed to send alert:', error);
    }
  } else if (!report.success && report.mediumSeverityCount > 0) {
    console.log('⚠️ Medium severity issues detected - logging warning');
    
    try {
      await db.collection('system_alerts').add({
        type: 'LOCATION_CONSISTENCY_WARNING',
        severity: 'MEDIUM',
        title: 'Location Consistency Issues Detected',
        message: `Found ${report.mediumSeverityCount} medium severity location consistency issues that should be reviewed.`,
        details: {
          issueCount: report.issues?.length || 0,
          mediumSeverityCount: report.mediumSeverityCount,
          affectedOrgs: [...new Set(report.issues?.map(i => i.orgName) || [])]
        },
        acknowledged: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 3 * 24 * 60 * 60 * 1000)) // 3 days
      });
    } catch (error) {
      console.error('❌ Failed to log warning:', error);
    }
  }
}

async function getMonitoringHistory(days = 7) {
  try {
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    
    const reportsSnapshot = await db.collection('system_monitoring')
      .doc('location_consistency')
      .collection('reports')
      .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(cutoff))
      .orderBy('createdAt', 'desc')
      .get();

    const reports = [];
    reportsSnapshot.forEach(doc => {
      reports.push({
        id: doc.id,
        ...doc.data()
      });
    });

    return reports;
  } catch (error) {
    console.error('❌ Failed to get monitoring history:', error);
    return [];
  }
}

async function runMonitoring() {
  console.log('🔍 Starting scheduled location consistency monitoring...');
  console.log(`⏰ ${new Date().toISOString()}`);
  console.log('='.repeat(60));

  try {
    // Run validation
    const report = await validateLocationConsistency();
    
    // Save report to database
    await saveMonitoringReport(report);
    
    // Send alerts if needed
    await sendAlertIfNeeded(report);
    
    // Clean up old reports (keep last 30 days)
    try {
      const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      const oldReportsSnapshot = await db.collection('system_monitoring')
        .doc('location_consistency')
        .collection('reports')
        .where('createdAt', '<', admin.firestore.Timestamp.fromDate(cutoff))
        .get();

      if (oldReportsSnapshot.size > 0) {
        console.log(`🗑️ Cleaning up ${oldReportsSnapshot.size} old reports...`);
        const batch = db.batch();
        oldReportsSnapshot.docs.forEach(doc => {
          batch.delete(doc.ref);
        });
        await batch.commit();
      }
    } catch (error) {
      console.error('⚠️ Failed to clean up old reports:', error);
    }

    console.log('\n✅ Monitoring completed successfully');
    
    if (report.success) {
      console.log('🎉 No issues detected - system is healthy!');
    } else {
      console.log(`⚠️ Issues detected and logged. High: ${report.highSeverityCount}, Medium: ${report.mediumSeverityCount}, Low: ${report.lowSeverityCount}`);
    }

    return report;
  } catch (error) {
    console.error('❌ Monitoring failed:', error);
    
    // Log the failure
    try {
      await db.collection('system_alerts').add({
        type: 'MONITORING_FAILURE',
        severity: 'HIGH',
        title: 'Location Consistency Monitoring Failed',
        message: `The scheduled location consistency check failed to complete: ${error.message}`,
        details: { error: error.message, stack: error.stack },
        acknowledged: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)) // 24 hours
      });
    } catch (alertError) {
      console.error('❌ Failed to log monitoring failure:', alertError);
    }
    
    throw error;
  }
}

// CLI Commands
async function handleCLI() {
  const command = process.argv[2];
  
  switch (command) {
    case 'run':
      await runMonitoring();
      break;
      
    case 'history':
      const days = parseInt(process.argv[3]) || 7;
      const history = await getMonitoringHistory(days);
      console.log(`📊 Monitoring history (last ${days} days):`);
      console.log('='.repeat(50));
      
      if (history.length === 0) {
        console.log('No reports found');
      } else {
        history.forEach(report => {
          const date = new Date(report.timestamp).toLocaleDateString();
          const time = new Date(report.timestamp).toLocaleTimeString();
          const status = report.success ? '✅ CLEAN' : `❌ ${report.issueCount} ISSUES`;
          console.log(`${date} ${time}: ${status}`);
          if (!report.success) {
            console.log(`  High: ${report.highSeverityCount}, Medium: ${report.mediumSeverityCount}, Low: ${report.lowSeverityCount}`);
          }
        });
      }
      break;
      
    case 'status':
      try {
        const statusDoc = await db.collection('system_monitoring')
          .doc('location_consistency').get();
        
        if (statusDoc.exists) {
          const status = statusDoc.data();
          console.log('📊 Current monitoring status:');
          console.log('='.repeat(40));
          console.log(`Last check: ${status.lastCheck || 'Never'}`);
          console.log(`Result: ${status.lastCheckResult || 'Unknown'}`);
          console.log(`Issues found: ${status.issueCount || 0}`);
          console.log(`  High severity: ${status.highSeverityCount || 0}`);
          console.log(`  Medium severity: ${status.mediumSeverityCount || 0}`);
          console.log(`  Low severity: ${status.lowSeverityCount || 0}`);
          
          if (status.stats) {
            console.log('\nLast check statistics:');
            console.log(`  Organizations: ${status.stats.totalOrgsChecked || 0}`);
            console.log(`  Shifts: ${status.stats.totalShiftsChecked || 0}`);
            console.log(`  Checklists: ${status.stats.totalChecklistsChecked || 0}`);
          }
        } else {
          console.log('No monitoring status found. Run monitoring first.');
        }
      } catch (error) {
        console.error('Failed to get status:', error);
      }
      break;
      
    default:
      console.log('Location Consistency Monitoring System');
      console.log('=====================================');
      console.log('');
      console.log('Commands:');
      console.log('  run                     - Run monitoring check now');
      console.log('  history [days]          - Show monitoring history (default: 7 days)');
      console.log('  status                  - Show current monitoring status');
      console.log('');
      console.log('Examples:');
      console.log('  node monitoring_system.js run');
      console.log('  node monitoring_system.js history 30');
      console.log('  node monitoring_system.js status');
      console.log('');
      console.log('For scheduled monitoring, add to crontab:');
      console.log('  # Run daily at 6 AM');
      console.log('  0 6 * * * cd /path/to/project && node monitoring_system.js run');
      process.exit(0);
  }
}

module.exports = {
  runMonitoring,
  getMonitoringHistory,
  saveMonitoringReport,
  sendAlertIfNeeded
};

// Handle CLI execution
if (require.main === module) {
  handleCLI().then(() => {
    process.exit(0);
  }).catch(error => {
    console.error('Command failed:', error);
    process.exit(1);
  });
}