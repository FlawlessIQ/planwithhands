const { DateTime } = require('luxon');

console.log('\n=== ANALYZING SEND TIME PATTERN ===\n');

const sends = [
  { date: '2025-10-08', sentAtUTC: '2025-10-08T16:00:10.963Z', utcHour: 16 },
  { date: '2025-10-12', sentAtUTC: '2025-10-13T18:00:07.226Z', utcHour: 18 },
  { date: '2025-10-13', sentAtUTC: '2025-10-14T22:00:07.981Z', utcHour: 22 },
];

const timezone = 'America/New_York';

console.log('📧 SUMMARY SEND TIMES:\n');

sends.forEach(send => {
  const utcTime = DateTime.fromISO(send.sentAtUTC, { zone: 'UTC' });
  const localTime = utcTime.setZone(timezone);
  
  console.log(`${send.date} summary:`);
  console.log(`  Sent at: ${utcTime.toFormat('HH:mm')} UTC = ${localTime.toFormat('h:mm a')} EST`);
  console.log(`  → This means dailySummaryTime was set to: ${localTime.toFormat('HH:mm')}\n`);
});

console.log('📊 ANALYSIS:');
console.log('  The scheduled time has been CHANGING between sends!');
console.log('  - Oct 8:  Set to 12:00 PM (noon)');
console.log('  - Oct 12: Set to 02:00 PM');
console.log('  - Oct 13: Set to 06:00 PM  ← Current setting');
console.log('\n💡 EXPLANATION:');
console.log('  When you changed the time this morning, it was probably:');
console.log('  - Changed from 2:00 PM to a NEW time');
console.log('  - The scheduled function only runs every hour');
console.log('  - If you set it at (for example) 8:00 AM, it would send at 9:00 AM');
console.log('  - But you changed it AGAIN to 5:53 PM later in the day');
console.log('  - So it finally sent at 6:00 PM when that hour arrived');
console.log('\n❓ QUESTION:');
console.log('  What time did you originally set it to this morning?');
console.log('  If it was before the current time, it should have sent.');
console.log('  If it didn\'t send, there may have been an issue with the function at that hour.');
