const { DateTime } = require('luxon');

function analyzeEmailTimingSupport() {
  console.log('🕐 Daily Summary Email Timing Analysis\n');
  
  // Current Cloud Function schedule: 21:00 UTC (9 PM UTC)
  const cloudFunctionUTC = 21 * 60; // 21:00 = 1260 minutes from midnight
  const windowMinutes = 30; // ±30 minute window
  
  const timezones = [
    'America/New_York',    // Eastern
    'America/Chicago',     // Central  
    'America/Denver',      // Mountain
    'America/Los_Angeles', // Pacific
    'Europe/London',       // GMT
    'Europe/Paris',        // CET
    'Asia/Tokyo',          // JST
    'Australia/Sydney'     // AEST
  ];
  
  console.log('📊 When 21:00 UTC (Cloud Function time) occurs in each timezone:\n');
  
  timezones.forEach(tz => {
    const utcTime = DateTime.fromObject({ hour: 21, minute: 0 }, { zone: 'UTC' });
    const localTime = utcTime.setZone(tz);
    const localMinutes = localTime.hour * 60 + localTime.minute;
    
    console.log(`${tz.padEnd(20)} | ${localTime.toFormat('h:mm a').padEnd(8)} | ${localTime.toFormat('HH:mm')}`);
  });
  
  console.log('\n🎯 What times WORK with current system (±30 min window):\n');
  
  timezones.forEach(tz => {
    const utcTime = DateTime.fromObject({ hour: 21, minute: 0 }, { zone: 'UTC' });
    const localTime = utcTime.setZone(tz);
    const centerTime = localTime.toFormat('HH:mm');
    const earliestTime = localTime.minus({ minutes: 30 }).toFormat('HH:mm');
    const latestTime = localTime.plus({ minutes: 30 }).toFormat('HH:mm');
    
    console.log(`${tz.padEnd(20)} | ${earliestTime} - ${latestTime} (centered on ${centerTime})`);
  });
  
  console.log('\n❌ Example times that DO NOT work:\n');
  
  const problematicTimes = [
    { time: '11:00 PM', reason: 'Too late (2+ hours after 9 PM in most timezones)' },
    { time: '8:00 AM', reason: 'Too early (11+ hours difference)' },
    { time: '12:00 PM', reason: 'Noon (5+ hours difference)' },
    { time: '1:00 AM', reason: 'Very late night (4+ hours after 9 PM)' }
  ];
  
  problematicTimes.forEach(({ time, reason }) => {
    console.log(`⚠️  ${time.padEnd(10)} | ${reason}`);
  });
  
  console.log('\n🔧 SOLUTIONS for flexible timing:\n');
  
  console.log('1. 🔄 MULTIPLE CLOUD FUNCTIONS (Recommended)');
  console.log('   • Create functions for different UTC hours');
  console.log('   • scheduledDailySummary_00, scheduledDailySummary_06, etc.');
  console.log('   • Each org gets assigned to appropriate function\n');
  
  console.log('2. ⏰ HOURLY FUNCTION');
  console.log('   • Run every hour, check which orgs need summaries');
  console.log('   • More resource intensive but fully flexible\n');
  
  console.log('3. 🎯 SMART SCHEDULING');
  console.log('   • Analyze org timezones and preferred times');
  console.log('   • Group orgs by optimal UTC send times');
  console.log('   • Create functions for popular time slots\n');
  
  console.log('4. 📱 ON-DEMAND TRIGGERS');
  console.log('   • Keep current scheduled function for most orgs');
  console.log('   • Add manual trigger for custom times');
  console.log('   • Use cron jobs or app-based scheduling');
}

analyzeEmailTimingSupport();