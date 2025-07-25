import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:hands_app/state/app_state.dart';
import 'package:hands_app/state/user_state.dart';

class Navbar extends ConsumerWidget {
  const Navbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appState = ref.watch(appStateProvider);
    var appStateActions = ref.watch(appStateProvider.notifier);
    var userState = ref.watch(userStateProvider);

    // Define all possible navbar items with their conditions
    final List<Map<String, dynamic>> navItems = [
      {
        'icon': Icons.home,
        'label': 'Home',
        'route': AppRoutes.homePage.path,
        'roles': [2, 1, 0], // 2=admin, 1=manager, 0=staff
      },
      {
        'icon': Icons.book,
        'label': 'Training',
        'route': AppRoutes.trainingMaterialsPage.path,
        'roles': [2, 1, 0],
      },
    ];

    // Filter only the visible items
    final filteredNavItems =
        navItems
            .where(
              (item) => item['roles'].contains(userState.userData?.userRole),
            )
            .toList();

    return BottomNavigationBar(
      currentIndex: appState.currentPageIndex.clamp(
        0,
        filteredNavItems.length - 1,
      ),
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (appState.isSettingsOpen) {
          Navigator.pop(context);
          appStateActions.setIsSettingsOpen(false);
        }

        // Navigate to the correct page based on filtered items
        context.go(filteredNavItems[index]['route']);
        appStateActions.setCurrentPageIndex(index);
      },
      selectedItemColor: Theme.of(context).colorScheme.onPrimary,
      unselectedItemColor: Theme.of(
        context,
      ).colorScheme.onPrimary.withValues(alpha: 0.5),
      backgroundColor: Theme.of(context).colorScheme.primary,
      items:
          filteredNavItems
              .map(
                (item) => BottomNavigationBarItem(
                  label: item['label'],
                  icon: Icon(item['icon']),
                ),
              )
              .toList(),
    );
  }
}
