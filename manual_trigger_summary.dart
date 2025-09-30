import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:hands_app/services/daily_summary_service.dart';

void main() async {
  print('🔄 Manual Daily Summary Trigger');
  print('================================');

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized');

    final service = DailySummaryService();
    const orgId = '3qjYzHagWmfbnMieJ1aj';

    // Calculate yesterday's date
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    print('📅 Target organization: $orgId');
    print('📅 Target date: $dateStr (yesterday)');

    // Generate and send daily summary
    print('🚀 Generating daily summary...');
    await service.generateAndSendDailySummary(organizationId: orgId, targetDate: yesterday);

    print('✅ Daily summary generated and sent successfully!');
    print('📱 Check your notifications in the app.');
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }

  exit(0);
}
