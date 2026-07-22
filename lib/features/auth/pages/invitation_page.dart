import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/widgets/responsive_appbar_title.dart';

class InvitationPage extends StatefulWidget {
  final String? token;

  const InvitationPage({super.key, this.token});

  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage> {
  @override
  Widget build(BuildContext context) {
    if (widget.token == null || widget.token!.isEmpty) {
      return _buildErrorScaffold('No invitation token provided.');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('${AppRoutes.welcomePage.path}?inviteId=${widget.token}');
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildErrorScaffold(String message) {
    return Scaffold(
      appBar: AppBar(title: const ResponsiveAppBarTitle('Invitation Error')),
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
