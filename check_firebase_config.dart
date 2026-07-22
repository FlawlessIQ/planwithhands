#!/usr/bin/env dart
// Firebase APNs Configuration Checker
// This script checks if APNs certificates are properly configured in Firebase

import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  print('🔍 Firebase APNs Configuration Checker');
  print('=====================================\n');

  // Check if Firebase CLI is installed
  print('1. Checking Firebase CLI installation...');
  final firebaseCliResult = await Process.run('firebase', ['--version'], runInShell: true);
  if (firebaseCliResult.exitCode != 0) {
    print('❌ Firebase CLI not found. Please install it: npm install -g firebase-tools');
    return;
  }
  print('✅ Firebase CLI installed: ${firebaseCliResult.stdout.toString().trim()}');

  // Check if logged in
  print('\n2. Checking Firebase authentication...');
  final loginResult = await Process.run('firebase', ['projects:list'], runInShell: true);
  if (loginResult.exitCode != 0) {
    print('❌ Not logged in to Firebase. Run: firebase login');
    return;
  }
  print('✅ Authenticated with Firebase');

  // Check current project
  print('\n3. Checking current Firebase project...');
  final projectResult = await Process.run('firebase', ['use'], runInShell: true);
  if (projectResult.exitCode != 0) {
    print('❌ No Firebase project selected. Run: firebase use <project-id>');
    return;
  }

  final currentProject = projectResult.stdout.toString().trim();
  print('✅ Current project: $currentProject');

  // Try to get project info (this will show us the project details)
  print('\n4. Getting project configuration...');
  final projectInfoResult = await Process.run('firebase', ['projects:list', '--json'], runInShell: true);
  if (projectInfoResult.exitCode == 0) {
    try {
      final projects = jsonDecode(projectInfoResult.stdout.toString()) as List;
      final currentProjectInfo = projects.firstWhere(
        (p) => currentProject.contains(p['projectId']),
        orElse: () => null,
      );

      if (currentProjectInfo != null) {
        print('📋 Project Details:');
        print('   Project ID: ${currentProjectInfo['projectId']}');
        print('   Project Name: ${currentProjectInfo['displayName']}');
        print('   Project Number: ${currentProjectInfo['projectNumber']}');
      }
    } catch (e) {
      print('⚠️  Could not parse project info: $e');
    }
  }

  print('\n5. Checking Firebase configuration files...');

  // Check for GoogleService-Info.plist (iOS)
  final iosConfigFile = File('ios/Runner/GoogleService-Info.plist');
  if (iosConfigFile.existsSync()) {
    print('✅ iOS config file found: ios/Runner/GoogleService-Info.plist');

    // Try to extract bundle ID from plist
    try {
      final plistContent = await iosConfigFile.readAsString();
      final bundleIdMatch = RegExp(r'<key>BUNDLE_ID</key>\s*<string>(.*?)</string>').firstMatch(plistContent);
      if (bundleIdMatch != null) {
        final bundleId = bundleIdMatch.group(1);
        print('   Bundle ID: $bundleId');

        if (bundleId != 'com.planwithhands.hands') {
          print('⚠️  Bundle ID mismatch! Expected: com.planwithhands.hands, Found: $bundleId');
        } else {
          print('✅ Bundle ID matches expected value');
        }
      }
    } catch (e) {
      print('⚠️  Could not parse iOS config file: $e');
    }
  } else {
    print('❌ iOS config file not found: ios/Runner/GoogleService-Info.plist');
  }

  // Check for google-services.json (Android)
  final androidConfigFile = File('android/app/google-services.json');
  if (androidConfigFile.existsSync()) {
    print('✅ Android config file found: android/app/google-services.json');
  } else {
    print('❌ Android config file not found: android/app/google-services.json');
  }

  print('\n6. APNs Configuration Check');
  print('============================');
  print('To verify APNs configuration manually:');
  print('1. Go to Firebase Console: https://console.firebase.google.com/');
  print('2. Select your project: $currentProject');
  print('3. Go to Project Settings → Cloud Messaging');
  print('4. Under "Apple app configuration" section:');
  print('   ✅ APNs Authentication Key should be uploaded (preferred)');
  print('   ✅ OR APNs Certificates should be uploaded');
  print('   ✅ Bundle ID should be: com.planwithhands.hands');
  print('   ✅ Team ID should be set');
  print('   ✅ Key ID should be set (if using auth key)');

  print('\n7. Critical Production Requirements:');
  print('====================================');
  print('For TestFlight/Production notifications to work:');
  print('• APNs Production certificate/key must be configured');
  print('• Bundle ID must exactly match: com.planwithhands.hands');
  print('• App must be built with --release flag for TestFlight');
  print('• Push Notifications capability must be enabled in Xcode');

  print('\n8. Testing Recommendations:');
  print('============================');
  print('• Use the Firebase Console to send test notifications');
  print('• Test with FCM tokens from Firestore deviceTokens collection');
  print('• Check Cloud Function logs for notification sending errors');
  print('• Use the Flutter app debug tool we created: PushNotificationTestWidget');

  print('\n🎯 Next Steps:');
  print('==============');
  print('1. Verify APNs configuration in Firebase Console');
  print('2. Test FCM token generation with the debug widget');
  print('3. Send test notification from Firebase Console');
  print('4. Check Cloud Function logs for any errors');
}
