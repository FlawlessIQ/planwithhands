import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/global_widgets/hands_icon.dart';
import 'package:hands_app/global_widgets/unified_menu_button.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/state/user_state.dart';

class GenericAppBarContent extends ConsumerWidget {
  final String appBarTitle;
  final int? userRole;
  const GenericAppBarContent({super.key, required this.appBarTitle, this.userRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          // Left: Back arrow, logo, and title
          IconButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                context.go(AppRoutes.userDashboardPage.path);
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
          const HandsIcon(size: 32, enableShadow: false),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appBarTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Right: Menu button
          Consumer(
            builder: (context, ref, _) {
              final userState = ref.watch(userStateProvider);
              // Use passed userRole if available, otherwise fallback to provider, then to role 0
              final effectiveUserRole = userRole ?? userState.userData?.userRole ?? 0;
              print('[GenericAppBarContent] Passed userRole: $userRole, UserState: ${userState.userData?.userRole}, effective role: $effectiveUserRole');
              return UnifiedMenuButton(userRole: effectiveUserRole);
            },
          ),
        ],
      ),
    );
  }
}
