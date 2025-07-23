import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/routing/routes.dart';
// import 'package:hands_app/state/user_state.dart';

class BottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final int? userRole;
  const BottomNavBar({super.key, required this.currentIndex, this.userRole});

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.userDashboardPage.path);
        break;
      case 1:
        context.go(AppRoutes.managerDashboardPage.path);
        break;
      case 2:
        context.go(AppRoutes.adminDashboardPage.path);
        break;
      case 3:
        context.go(AppRoutes.schedulePage.path);
        break;
      case 4:
        context.go(AppRoutes.trainingMaterialsPage.path, extra: {'userRole': userRole}); // Pass userRole to training materials page
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filter tabs based on userRole
    // 0: general, 1: manager, 2: admin
    final int role = userRole ?? 0;
    final List<BottomNavigationBarItem> items = [];
    final List<int> tabMap = [];
    // Always add User tab
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard),
      label: 'User',
    ));
    tabMap.add(0);
    // Add Manager tab for role 1 and 2
    if (role >= 1) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_customize),
        label: 'Manager',
      ));
      tabMap.add(1);
    }
    // Add Admin tab for role 2 only
    if (role == 2) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings),
        label: 'Admin',
      ));
      tabMap.add(2);
    }
    // Always add Schedule and Documents tabs
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today),
      label: 'Schedule',
    ));
    tabMap.add(3);
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.description),
      label: 'Documents',
    ));
    tabMap.add(4);

    // Map currentIndex to filtered tab index
    int navIndex = tabMap.indexOf(currentIndex);
    if (navIndex == -1) navIndex = 0;

    return BottomNavigationBar(
      currentIndex: navIndex,
      onTap: (index) {
        _onItemTapped(context, tabMap[index]);
      },
      items: items,
      type: BottomNavigationBarType.fixed,
    );
  }
}