import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Debug script to check role recognition issue
/// This will help identify where the problem is in the role detection chain
class RoleDebugger {
  static Future<void> debugCurrentUserRole() async {
    print('🔍 === ROLE DEBUG SESSION START ===');

    try {
      // Step 1: Check Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return;
      }

      print('✅ Authenticated user found:');
      print('   - UID: ${user.uid}');
      print('   - Email: ${user.email}');

      // Step 2: Check Firestore document
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        print('❌ User document not found in Firestore');
        return;
      }

      print('✅ User document found in Firestore');

      // Step 3: Examine the raw data
      final data = userDoc.data() as Map<String, dynamic>;
      print('📄 Raw Firestore data:');
      data.forEach((key, value) {
        print('   - $key: $value (${value.runtimeType})');
      });

      // Step 4: Specifically check userRole field
      final userRole = data['userRole'];
      print('\n🎯 User Role Analysis:');
      print('   - Raw userRole field: $userRole');
      print('   - Type: ${userRole.runtimeType}');
      print('   - Is int?: ${userRole is int}');
      print('   - Is String?: ${userRole is String}');

      if (userRole is int) {
        print('   - Integer value: $userRole');
        print('   - Expected role mapping:');
        print('     * 0 = Staff');
        print('     * 1 = Manager');
        print('     * 2 = Admin');
        print('   - Your role should be: ${_getRoleString(userRole)}');
      } else if (userRole is String) {
        print('   - String value: "$userRole"');
        print('   - This might be the problem - role should be an integer!');
      } else {
        print('   - Unexpected type: ${userRole.runtimeType}');
        print('   - Value: $userRole');
      }

      // Step 5: Check other relevant fields
      print('\n📋 Other relevant fields:');
      print('   - organizationId: ${data['organizationId']}');
      print('   - isAdmin: ${data['isAdmin']}');
      print('   - firstName: ${data['firstName']}');
      print('   - lastName: ${data['lastName']}');

      // Step 6: Test the toAppRole function
      print('\n🔄 Testing toAppRole function:');
      if (userRole is int) {
        final appRole = _toAppRole(userRole);
        print('   - toAppRole($userRole) = $appRole');
      }
    } catch (e) {
      print('❌ Error during debug: $e');
    }

    print('🔍 === ROLE DEBUG SESSION END ===\n');
  }

  static String _getRoleString(int role) {
    switch (role) {
      case 0:
        return 'Staff';
      case 1:
        return 'Manager';
      case 2:
        return 'Admin';
      default:
        return 'Unknown ($role)';
    }
  }

  static String _toAppRole(int userRole) {
    if (userRole == 2) return 'AppRole.admin';
    if (userRole == 1) return 'AppRole.manager';
    return 'AppRole.staff';
  }
}

/// Widget that can be added to any page to debug role issues
class RoleDebugWidget extends StatefulWidget {
  const RoleDebugWidget({super.key});

  @override
  State<RoleDebugWidget> createState() => _RoleDebugWidgetState();
}

class _RoleDebugWidgetState extends State<RoleDebugWidget> {
  String debugOutput = 'Press button to debug role';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🐛 Role Debugger', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton(onPressed: _runDebug, child: const Text('Debug Role')),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(debugOutput, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _runDebug() async {
    setState(() {
      debugOutput = 'Running debug...';
    });

    try {
      final result = await _captureDebugOutput();
      setState(() {
        debugOutput = result;
      });
    } catch (e) {
      setState(() {
        debugOutput = 'Error running debug: $e';
      });
    }
  }

  Future<String> _captureDebugOutput() async {
    final buffer = StringBuffer();

    try {
      // Check Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        buffer.writeln('❌ No authenticated user found');
        return buffer.toString();
      }

      buffer.writeln('✅ Authenticated user found:');
      buffer.writeln('   - UID: ${user.uid}');
      buffer.writeln('   - Email: ${user.email}');

      // Check Firestore document
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        buffer.writeln('❌ User document not found in Firestore');
        return buffer.toString();
      }

      buffer.writeln('✅ User document found in Firestore');

      // Examine the raw data
      final data = userDoc.data() as Map<String, dynamic>;
      buffer.writeln('📄 Raw Firestore data:');
      data.forEach((key, value) {
        buffer.writeln('   - $key: $value (${value.runtimeType})');
      });

      // Specifically check userRole field
      final userRole = data['userRole'];
      buffer.writeln('\n🎯 User Role Analysis:');
      buffer.writeln('   - Raw userRole field: $userRole');
      buffer.writeln('   - Type: ${userRole.runtimeType}');
      buffer.writeln('   - Is int?: ${userRole is int}');
      buffer.writeln('   - Is String?: ${userRole is String}');

      if (userRole is int) {
        buffer.writeln('   - Integer value: $userRole');
        buffer.writeln('   - Expected role mapping:');
        buffer.writeln('     * 0 = Staff');
        buffer.writeln('     * 1 = Manager');
        buffer.writeln('     * 2 = Admin');
        buffer.writeln('   - Your role should be: ${_getRoleString(userRole)}');
      } else if (userRole is String) {
        buffer.writeln('   - String value: "$userRole"');
        buffer.writeln('   - This might be the problem - role should be an integer!');
      } else {
        buffer.writeln('   - Unexpected type: ${userRole.runtimeType}');
        buffer.writeln('   - Value: $userRole');
      }

      // Other relevant fields
      buffer.writeln('\n📋 Other relevant fields:');
      buffer.writeln('   - organizationId: ${data['organizationId']}');
      buffer.writeln('   - isAdmin: ${data['isAdmin']}');
      buffer.writeln('   - firstName: ${data['firstName']}');
      buffer.writeln('   - lastName: ${data['lastName']}');

      // Test the toAppRole function
      buffer.writeln('\n🔄 Testing toAppRole function:');
      if (userRole is int) {
        final appRole = _toAppRole(userRole);
        buffer.writeln('   - toAppRole($userRole) = $appRole');
      }
    } catch (e) {
      buffer.writeln('❌ Error during debug: $e');
    }

    return buffer.toString();
  }

  String _getRoleString(int role) {
    switch (role) {
      case 0:
        return 'Staff';
      case 1:
        return 'Manager';
      case 2:
        return 'Admin';
      default:
        return 'Unknown ($role)';
    }
  }

  String _toAppRole(int userRole) {
    if (userRole == 2) return 'AppRole.admin';
    if (userRole == 1) return 'AppRole.manager';
    return 'AppRole.staff';
  }
}
