import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/utils/firestore_enforcer.dart';

class InvitationPage extends StatefulWidget {
  final String? token;

  const InvitationPage({super.key, this.token});

  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage> {
  Future<DocumentSnapshot?>? _invitationFuture;

  @override
  void initState() {
    super.initState();
    if (widget.token != null && widget.token!.isNotEmpty) {
      _invitationFuture = _verifyToken(widget.token!);
    }
  }

  Future<DocumentSnapshot?> _verifyToken(String token) async {
    try {
      final doc =
          await FirestoreEnforcer.instance
              .collection('invites')
              .doc(token)
              .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        if (expiresAt.isAfter(DateTime.now())) {
          // Token is valid and not expired
          return doc;
        }
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token == null || widget.token!.isEmpty) {
      return _buildErrorScaffold('No invitation token provided.');
    }

    return FutureBuilder<DocumentSnapshot?>(
      future: _invitationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildErrorScaffold(
            'This invitation is invalid or has expired.',
          );
        }

        // If the token is valid, redirect to the sign-up page
        final inviteData = snapshot.data!.data() as Map<String, dynamic>;
        final email = inviteData['email'] as String;
        final organizationId = inviteData['organizationId'] as String;

        // Use a post-frame callback to navigate after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(
            AppRoutes.accountCreationPage.path,
            extra: {
              'email': email,
              'organizationId': organizationId,
              'token': widget.token,
            },
          );
        });

        // Show a loading indicator while redirecting
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Widget _buildErrorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitation Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 20),
            Text(message, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.loginPage.path),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
