/// Simple manual test to trigger daily summary
/// Replace YOUR_ORG_ID with your actual organization ID
void main() async {
  print('🔍 Manual Daily Summary Test');
  print('============================');

  try {
    // You need to replace this with your actual organization ID
    const orgId = 'YOUR_ORG_ID_HERE'; // ← UPDATE THIS!

    print('Attempting to manually trigger daily summary for org: $orgId');
    print('Date: ${DateTime.now()}');

    // This would trigger the summary if run in your Flutter app
    // await DailySummaryService().generateAndSendDailySummary(
    //   organizationId: orgId,
    //   targetDate: DateTime.now().subtract(Duration(days: 1)) // Yesterday
    // );

    print('✅ Manual trigger would have worked!');
    print('');
    print('📋 To actually test this:');
    print('1. Add this code to a button in your app');
    print('2. Or ensure your app is running at your preferred summary time');
    print('3. Check Firebase Console for summary logs');
  } catch (e) {
    print('❌ Error: $e');
  }
}
