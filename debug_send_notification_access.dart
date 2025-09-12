import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Debug widget to check send notification access
/// Add this widget temporarily to your main dashboard to see the debug info
class SendNotificationDebugWidget extends StatefulWidget {
  const SendNotificationDebugWidget({super.key});

  @override
  State<SendNotificationDebugWidget> createState() => _SendNotificationDebugWidgetState();
}

class _SendNotificationDebugWidgetState extends State<SendNotificationDebugWidget> {
  String _debugInfo = "Loading...";
  int? _userRole;
  String? _userId;
  String? _orgId;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _debugInfo = "❌ No user logged in";
        });
        return;
      }

      _userId = user.uid;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        setState(() {
          _debugInfo = "❌ User document not found";
        });
        return;
      }

      final userData = userDoc.data()!;
      _userRole = userData['userRole'] as int? ?? 0;
      _orgId = userData['organizationId'] as String?;
      final firstName = userData['firstName'] ?? 'Unknown';
      final lastName = userData['lastName'] ?? 'Unknown';

      String debugText = """
🔍 Send Notification Access Debug
=====================================

👤 User: $firstName $lastName
📧 Email: ${user.email}
🆔 User ID: ${user.uid}
🔑 User Role: $_userRole
🏢 Organization: $_orgId

🔐 Permissions Check:
""";

      if (_userRole! >= 2) {
        debugText += "✅ HAS ADMIN ACCESS (role $_userRole >= 2)\n";
        debugText += "✅ SHOULD see 'Send notification' in menu\n";
        debugText += "✅ CAN create notification groups\n";
      } else if (_userRole! >= 1) {
        debugText += "❌ HAS MANAGER ACCESS ONLY (role $_userRole)\n";
        debugText += "❌ CANNOT send notifications (need role 2)\n";
        debugText += "❌ CANNOT create groups\n";
      } else {
        debugText += "❌ HAS USER ACCESS ONLY (role $_userRole)\n";
        debugText += "❌ CANNOT send notifications\n";
        debugText += "❌ CANNOT access admin features\n";
      }

      debugText += """

💡 Role System:
   0 = User (basic access)
   1 = Manager (schedule management)  
   2 = Admin (full access + notifications)

🚨 Issue Resolution:
""";

      if (_userRole! < 2) {
        debugText += """
   Your role ($_userRole) is too low for sending notifications.
   
   Solutions:
   1. Ask another admin to upgrade your role to 2
   2. Or use another admin account
   3. Check if role was accidentally changed
""";
      } else {
        debugText += """
   Your role looks correct. If you still can't see the option:
   
   Troubleshooting:
   1. Try refreshing the app (hot restart)
   2. Check the 3-dot menu button (top right)
   3. Log out and log back in
   4. Clear app cache
""";
      }

      setState(() {
        _debugInfo = debugText;
      });
    } catch (e) {
      setState(() {
        _debugInfo = "❌ Error checking access: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("🐛 DEBUG MODE", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SelectableText(_debugInfo, style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(onPressed: _checkAccess, child: Text("Refresh")),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // Copy debug info to clipboard
                  // You can implement this if needed
                },
                child: Text("Copy Debug Info"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Usage instructions:
/// 
/// 1. Add this widget to your dashboard temporarily:
/// 
/// ```dart
/// Column(
///   children: [
///     SendNotificationDebugWidget(), // Add this line
///     // ... rest of your dashboard
///   ],
/// )
/// ```
/// 
/// 2. Hot restart the app
/// 3. Check the debug output 
/// 4. Remove the widget when done
