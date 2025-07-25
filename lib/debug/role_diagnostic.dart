import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/firestore_enforcer.dart';
import '../constants/firestore_names.dart';

class RoleDiagnostic extends StatefulWidget {
  const RoleDiagnostic({super.key});

  @override
  State<RoleDiagnostic> createState() => _RoleDiagnosticState();
}

class _RoleDiagnosticState extends State<RoleDiagnostic> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          error = 'No user logged in';
          isLoading = false;
        });
        return;
      }

      final userDoc = await FirestoreEnforcer.instance
          .collection(FirestoreCollectionNames.users)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          error = 'User document not found';
          isLoading = false;
        });
        return;
      }

      setState(() {
        userData = userDoc.data();
        isLoading = false;
      });

      // Also print to console for debugging
      print('=== USER ROLE DIAGNOSTIC ===');
      print('User ID: ${user.uid}');
      print('User Email: ${user.email}');
      print('User Data: $userData');
      print('User Role: ${userData?['userRole']}');
      print('Organization ID: ${userData?['organizationId']}');
      print('Location ID: ${userData?['locationId']}');
      print('===========================');
    } catch (e) {
      setState(() {
        error = 'Error loading user data: $e';
        isLoading = false;
      });
      print('Error in role diagnostic: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Role Diagnostic',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const CircularProgressIndicator()
            else if (error != null)
              Text('Error: $error', style: const TextStyle(color: Colors.red))
            else if (userData != null) ...[
              _buildDataRow('User Role', userData!['userRole']?.toString() ?? 'null'),
              _buildDataRow('Organization ID', userData!['organizationId']?.toString() ?? 'null'),
              _buildDataRow('Location ID', userData!['locationId']?.toString() ?? 'null'),
              _buildDataRow('Email', FirebaseAuth.instance.currentUser?.email ?? 'null'),
              const SizedBox(height: 16),
              _buildRoleExplanation(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleExplanation() {
    final userRole = userData!['userRole'] as int? ?? 0;
    String explanation;
    Color color;

    if (userRole >= 2) {
      explanation = 'Admin Role - Routes to Admin Dashboard';
      color = Colors.red;
    } else if (userRole >= 1) {
      explanation = 'Manager Role - Routes to Manager Dashboard';
      color = Colors.orange;
    } else {
      explanation = 'User Role - Routes to User Dashboard';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            explanation,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Role Hierarchy:\n• Role 0: User Dashboard\n• Role 1: Manager Dashboard\n• Role 2+: Admin Dashboard',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
