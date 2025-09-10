import 'dart:io';
import 'dart:convert';

void main() async {
  print('Starting message creation debug...');
  
  // Test Firestore connection first
  print('\n1. Testing Firestore connection...');
  await testFirestoreConnection();
  
  // Check current messages
  print('\n2. Checking existing messages...');
  await checkExistingMessages();
  
  // Create a test message
  print('\n3. Creating test message...');
  await createTestMessage();
  
  // Wait and check Cloud Functions
  print('\n4. Waiting 30 seconds for Cloud Function trigger...');
  await Future.delayed(Duration(seconds: 30));
  await checkCloudFunctionLogs();
}

Future<void> testFirestoreConnection() async {
  try {
    final result = await Process.run('firebase', ['firestore:databases:list']);
    if (result.exitCode == 0) {
      print('✅ Firestore connection successful');
      print('Available databases: ${result.stdout}');
    } else {
      print('❌ Firestore connection failed: ${result.stderr}');
    }
  } catch (e) {
    print('❌ Error testing Firestore: $e');
  }
}

Future<void> checkExistingMessages() async {
  try {
    // Get a sample of messageThreads
    final result = await Process.run('firebase', [
      'firestore:databases:documents:list',
      'messageThreads',
      '--limit=5'
    ]);
    
    if (result.exitCode == 0) {
      print('✅ Found existing messageThreads:');
      print(result.stdout);
    } else {
      print('❌ Failed to query messageThreads: ${result.stderr}');
    }
  } catch (e) {
    print('❌ Error checking messages: $e');
  }
}

Future<void> createTestMessage() async {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final threadId = 'debug_thread_$timestamp';
  final messageId = 'debug_message_$timestamp';
  
  // Create the message document data
  final messageData = {
    'id': messageId,
    'text': 'Test message for push notification debugging',
    'timestamp': timestamp,
    'userId': 'debug_user_123',
    'userName': 'Debug User',
    'userRole': 'user',
    'isRead': false,
    'type': 'text'
  };
  
  // Create thread data
  final threadData = {
    'id': threadId,
    'recipientUserIds': ['debug_user_123', 'debug_recipient_456'],
    'organizationId': 'debug_org_123',
    'lastMessage': messageData['text'],
    'lastMessageTimestamp': timestamp,
    'lastMessageUserId': 'debug_user_123',
    'lastMessageUserName': 'Debug User'
  };
  
  try {
    print('Creating thread: $threadId');
    
    // First create the thread (if needed)
    final threadResult = await Process.run('firebase', [
      'firestore:databases:documents:create',
      'messageThreads/$threadId',
      '--data=${jsonEncode(threadData)}'
    ]);
    
    if (threadResult.exitCode == 0) {
      print('✅ Thread created successfully');
    } else {
      print('⚠️ Thread creation result: ${threadResult.stderr}');
    }
    
    // Wait a moment
    await Future.delayed(Duration(seconds: 2));
    
    // Now create the message document
    print('Creating message: $messageId in thread: $threadId');
    
    final messageResult = await Process.run('firebase', [
      'firestore:databases:documents:create',
      'messageThreads/$threadId/messages/$messageId',
      '--data=${jsonEncode(messageData)}'
    ]);
    
    if (messageResult.exitCode == 0) {
      print('✅ Message created successfully!');
      print('Message path: messageThreads/$threadId/messages/$messageId');
      print('This should trigger the onMessageCreated Cloud Function');
    } else {
      print('❌ Message creation failed: ${messageResult.stderr}');
    }
    
  } catch (e) {
    print('❌ Error creating test message: $e');
  }
}

Future<void> checkCloudFunctionLogs() async {
  try {
    print('Checking Cloud Function logs...');
    
    final result = await Process.run('firebase', [
      'functions:log',
      '--only', 'functions:onMessageCreated',
      '--limit', '10'
    ]);
    
    if (result.exitCode == 0) {
      if (result.stdout.toString().trim().isEmpty || 
          result.stdout.toString().contains('No log entries found')) {
        print('❌ No Cloud Function logs found - function may not be triggering!');
      } else {
        print('✅ Cloud Function logs found:');
        print(result.stdout);
      }
    } else {
      print('❌ Error checking logs: ${result.stderr}');
    }
    
    // Also check general function logs
    print('\nChecking all function logs...');
    final allLogsResult = await Process.run('firebase', [
      'functions:log',
      '--limit', '5'
    ]);
    
    if (allLogsResult.exitCode == 0) {
      print('Recent function activity:');
      print(allLogsResult.stdout);
    }
    
  } catch (e) {
    print('❌ Error checking function logs: $e');
  }
}
