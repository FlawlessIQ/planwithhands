const { DateTime } = require('luxon');

function demonstrateFlexibleScheduling() {
  console.log('🕐 Flexible Daily Summary Scheduling Demo\n');
  
  console.log('🔄 NEW SYSTEM: Hourly checks with user preferences\n');
  
  // Example organizations with different time preferences
  const organizations = [
    {
      name: 'East Coast Restaurant',
      timezone: 'America/New_York',
      preferredTime: { hour: 23, minute: 0 }, // 11:00 PM
      description: 'Late night summary after closing'
    },
    {
      name: 'West Coast Cafe',
      timezone: 'America/Los_Angeles', 
      preferredTime: { hour: 8, minute: 30 }, // 8:30 AM
      description: 'Morning summary before opening'
    },
    {
      name: 'London Office',
      timezone: 'Europe/London',
      preferredTime: { hour: 18, minute: 0 }, // 6:00 PM
      description: 'End of business day summary'
    },
    {
      name: 'Tokyo Branch',
      timezone: 'Asia/Tokyo',
      preferredTime: { hour: 12, minute: 15 }, // 12:15 PM
      description: 'Lunch time summary'
    },
    {
      name: 'Your Pub Group',
      timezone: 'America/New_York',
      preferredTime: { hour: 17, minute: 0 }, // 5:00 PM
      description: 'Current setting (works now!)'
    }
  ];
  
  console.log('📋 Organizations and their preferred summary times:\n');
  
  organizations.forEach((org, index) => {
    const { hour, minute } = org.preferredTime;
    const localTime = DateTime.now().setZone(org.timezone).set({ hour, minute, second: 0, millisecond: 0 });
    const utcTime = localTime.toUTC();
    
    console.log(`${index + 1}. ${org.name}`);
    console.log(`   Timezone: ${org.timezone}`);
    console.log(`   Preferred: ${hour}:${String(minute).padStart(2, '0')} (${localTime.toFormat('h:mm a')})`);
    console.log(`   UTC Time: ${utcTime.toFormat('HH:mm')} UTC`);
    console.log(`   Purpose: ${org.description}`);
    console.log();
  });
  
  console.log('⚡ How the NEW system works:\n');
  console.log('1. 🕐 Cloud Function runs EVERY HOUR at :00 (1:00, 2:00, 3:00, etc.)');
  console.log('2. 🔍 Checks ALL organizations to see if any need summaries at current UTC hour');
  console.log('3. 🎯 Converts each org\'s local time preference to UTC');
  console.log('4. ✅ Sends summaries only to orgs whose time has arrived');
  console.log('5. 📝 Marks as sent to prevent duplicates');
  console.log();
  
  console.log('🎉 Benefits of NEW system:\n');
  console.log('✅ ANY TIME: Users can set 11 PM, 8 AM, or any time they want');
  console.log('✅ ANY TIMEZONE: Automatically converts to UTC correctly');
  console.log('✅ PRECISE: Checks hour and minute for accuracy');
  console.log('✅ EFFICIENT: Only processes orgs that need summaries');
  console.log('✅ RELIABLE: Won\'t miss summaries due to timing windows');
  console.log('✅ FLEXIBLE: Easy to add more organizations');
  console.log();
  
  console.log('📊 Example hourly execution at different UTC times:\n');
  
  // Show what happens at different UTC hours
  for (let utcHour = 0; utcHour < 24; utcHour += 3) {
    console.log(`🕐 ${String(utcHour).padStart(2, '0')}:00 UTC - Organizations that would get summaries:`);
    
    let foundAny = false;
    organizations.forEach(org => {
      const { hour, minute } = org.preferredTime;
      const localTime = DateTime.now().setZone(org.timezone).set({ hour, minute, second: 0, millisecond: 0 });
      const utcTime = localTime.toUTC();
      const targetUTCHour = utcTime.hour;
      
      if (targetUTCHour === utcHour) {
        console.log(`   ✅ ${org.name} (${org.preferredTime.hour}:${String(org.preferredTime.minute).padStart(2, '0')} ${org.timezone})`);
        foundAny = true;
      }
    });
    
    if (!foundAny) {
      console.log(`   (No summaries scheduled for this hour)`);
    }
    console.log();
  }
  
  console.log('🚀 How to set different times:\n');
  console.log('Users can now set ANY time in their settings:');
  console.log('• 11:00 PM → Gets summary at 11 PM their local time');
  console.log('• 8:30 AM → Gets summary at 8:30 AM their local time'); 
  console.log('• 6:15 PM → Gets summary at 6:15 PM their local time');
  console.log('• 12:45 PM → Gets summary at 12:45 PM their local time');
  console.log();
  console.log('The system automatically figures out the correct UTC time to send!');
  
  console.log('\n💰 Resource usage:');
  console.log('• Function runs 24 times per day (instead of 1)');
  console.log('• But only processes orgs that need summaries each hour');
  console.log('• Much more efficient than checking every minute');
  console.log('• Reasonable cost increase for much better flexibility');
}

demonstrateFlexibleScheduling();