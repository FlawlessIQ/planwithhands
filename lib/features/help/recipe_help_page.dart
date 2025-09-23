import 'package:flutter/material.dart';
import 'package:hands_app/utils/app_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/models/recipe.dart';
import 'package:go_router/go_router.dart';
import 'package:hands_app/routing/routes.dart';
import 'package:url_launcher/url_launcher.dart';

class _QuickAction {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction({required this.title, required this.description, required this.icon, required this.onTap});
}

class RecipeHelpPage extends ConsumerStatefulWidget {
  final int? userRole;

  const RecipeHelpPage({super.key, this.userRole});

  @override
  ConsumerState<RecipeHelpPage> createState() => _RecipeHelpPageState();
}

class _RecipeHelpPageState extends ConsumerState<RecipeHelpPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AppRole _currentRole;
  late List<AppRole> _visibleTabs;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize with safe defaults - use provided role or fall back to staff
    final initialRole = widget.userRole != null ? toAppRole(widget.userRole!) : AppRole.staff;
    _currentRole = initialRole;
    _visibleTabs = RecipeData.getVisibleTabs(initialRole);

    // Ensure we have at least one tab to prevent controller errors
    if (_visibleTabs.isEmpty) {
      _visibleTabs = [AppRole.staff];
      _currentRole = AppRole.staff;
    }

    _tabController = TabController(length: _visibleTabs.length, vsync: this);

    // Initialize animation with a longer duration for smoother experience
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart));

    // Start animation after a brief delay to ensure everything is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.forward();
      }
    });

    debugPrint('HelpCenter: initState completed with role=$_currentRole, tabs=${_visibleTabs.length}');
  }

  @override
  void dispose() {
    debugPrint('HelpCenter: Disposing controllers');
    try {
      _tabController.dispose();
    } catch (e) {
      debugPrint('HelpCenter: Error disposing tab controller: $e');
    }
    try {
      _fadeController.dispose();
    } catch (e) {
      debugPrint('HelpCenter: Error disposing fade controller: $e');
    }
    super.dispose();
  }

  void _handleCta(Recipe recipe) {
    switch (recipe.ctaLabel) {
      case 'Open Dashboard':
        context.go('/dashboard');
        break;
      case 'Open Manager Dashboard':
        context.go('/manager');
        break;
      case 'Open Admin Dashboard':
        context.go('/admin');
        break;
      case 'Open Training':
        context.go('/training');
        break;
      case 'Compose Notification':
        _showSendNotificationSheet();
        break;
      case 'Open Web Portal':
        _launchWebPortal();
        break;
    }
  }

  void _showSendNotificationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.campaign_outlined,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Send Notification',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This would open the notification composer',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  void _launchWebPortal() async {
    // Prevent opening the web portal on iOS (App Store review restriction).
    if (isIOS) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Web portal access is not available in the iOS app.')));
      return;
    }

    final url = Uri.parse('https://portal.planwithhands.com/settings/locations');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showGuideDetails(Recipe recipe) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog.fullscreen(child: _GuideDetailView(recipe: recipe, onAction: () => _handleCta(recipe))),
    );
  }

  void _showTroubleshootingDetails(String tip) {
    final solution = _getTroubleshootingSolution(tip);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.support_agent_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Troubleshooting',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Solution:', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(solution, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Got it', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ),
            ],
          ),
    );
  }

  String _getTroubleshootingSolution(String tip) {
    if (tip.contains('push alerts') || tip.contains('notifications')) {
      return '1. Go to your device Settings\n2. Find "Notifications" or "Apps"\n3. Look for "Hands" app\n4. Enable notifications and all notification types\n5. Make sure "Do Not Disturb" is off';
    } else if (tip.contains('camera') || tip.contains('Camera')) {
      return '1. Go to your device Settings\n2. Find "Privacy" or "App Permissions"\n3. Tap "Camera"\n4. Find "Hands" app and enable camera access\n5. Restart the app if needed';
    } else if (tip.contains('location') || tip.contains('GPS')) {
      return '1. Go to your device Settings\n2. Find "Privacy" or "Location Services"\n3. Enable Location Services\n4. Find "Hands" app and set to "While Using App"\n5. Make sure GPS is enabled';
    } else if (tip.contains('login') || tip.contains('password')) {
      return '1. Check your internet connection\n2. Try resetting your password\n3. Make sure you\'re using the correct email\n4. Contact your manager or admin if issues persist\n5. Try force-closing and reopening the app';
    } else if (tip.contains('load') || tip.contains('restart')) {
      return '1. Force close the app completely\n2. Wait 5 seconds\n3. Reopen the app\n4. Check your internet connection\n5. Try logging out and back in if needed';
    } else if (tip.contains('photos') || tip.contains('uploading')) {
      return '1. Check camera permissions (see Camera solution above)\n2. Ensure you have good internet connection\n3. Try taking a new photo\n4. Check available storage space\n5. Force close and restart the app';
    } else if (tip.contains('shifts') || tip.contains('manager')) {
      return '1. Pull down to refresh the screen\n2. Check if you\'re assigned to the correct location\n3. Contact your manager to verify your schedule\n4. Make sure you\'re not looking at the wrong date\n5. Try logging out and back in';
    } else if (tip.contains('tasks') || tip.contains('refresh')) {
      return '1. Pull down on the screen to refresh\n2. Check your internet connection\n3. Make sure you\'re in the right location\n4. Verify the date/time is correct\n5. Contact your manager if tasks are still missing';
    } else if (tip.contains('location switching') || tip.contains('menu')) {
      return '1. Tap the menu button (3 lines) in the top right\n2. Look for "Switch Location" or location name\n3. Select your desired location\n4. Wait for the app to reload\n5. Contact admin if you don\'t see your location';
    } else {
      return '1. Try restarting the app\n2. Check your internet connection\n3. Make sure you have the latest app version\n4. Contact your manager or admin for help\n5. If urgent, try using the web version';
    }
  }

  Color _getRoleColor(AppRole role) {
    switch (role) {
      case AppRole.staff:
        return Colors.blue;
      case AppRole.manager:
        return Colors.orange;
      case AppRole.admin:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current user role reactively
    final userState = ref.watch(userStateProvider);

    // Use provided role from route or fall back to user state with default
    final userRole = widget.userRole ?? userState.userData?.userRole ?? 0; // Default to staff role
    final currentRole = toAppRole(userRole);
    final visibleTabs = RecipeData.getVisibleTabs(currentRole);

    // Debug output
    debugPrint('HelpCenter: === BUILD METHOD DEBUG ===');
    debugPrint('HelpCenter: userState.userData = ${userState.userData}');
    debugPrint('HelpCenter: widget.userRole = ${widget.userRole}');
    debugPrint('HelpCenter: resolved userRole=$userRole -> $currentRole, tabs=$visibleTabs');
    debugPrint('HelpCenter: === END BUILD DEBUG ===');

    // Update tabs if role changed (but only if we have a significant change)
    if (currentRole != _currentRole || visibleTabs.length != _visibleTabs.length) {
      debugPrint('HelpCenter: Role changed from $_currentRole to $currentRole, updating tabs');

      // Update state
      _currentRole = currentRole;
      _visibleTabs = visibleTabs;

      // Safely recreate tab controller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _tabController.dispose();
            _tabController = TabController(length: _visibleTabs.length, vsync: this);
          });
        }
      });
    }

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 800;
    final isMedium = size.width >= 800 && size.width < 1200;
    final isWide = size.width >= 1200;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Enhanced App Bar with integrated quick actions for wide screens
            SliverAppBar(
              expandedHeight:
                  isMobile
                      ? 180 // Increased from 140 to provide more space for title
                      : isWide
                      ? 160
                      : 150,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeroSection(isMobile, isMedium, isWide),
                titlePadding: const EdgeInsets.only(left: 72, bottom: 16), // Add left padding for back button
                title: null, // Remove default title to avoid overlap
              ),
              bottom:
                  _visibleTabs.length > 1
                      ? PreferredSize(
                        preferredSize: const Size.fromHeight(48),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorColor: Theme.of(context).colorScheme.primary,
                            indicatorWeight: 3,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelColor: Theme.of(context).colorScheme.primary,
                            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            tabs: _visibleTabs.map((role) => Tab(text: RecipeData.getRoleDisplayName(role))).toList(),
                          ),
                        ),
                      )
                      : null,
            ),

            // Content
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: _visibleTabs.map((tab) => _buildTabContent(tab, isMobile, isMedium, isWide)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isMobile, bool isMedium, bool isWide) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isWide
                ? 48
                : isMobile
                ? 20
                : 32,
            isMobile ? 60 : 50, // More top padding for mobile to accommodate the back button
            isWide
                ? 48
                : isMobile
                ? 20
                : 32,
            isMobile ? 24 : 16, // More bottom padding for mobile to prevent cut-off
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min, // Prevent overflow
            children: [
              if (isWide) ...[
                // Wide screen: Only show the hero title, no quick actions in hero area
                Flexible(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(flex: 2, child: _buildHeroTitle())],
                  ),
                ),
              ] else ...[
                // Mobile and medium: Just title with proper spacing
                _buildHeroTitle(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Help Center',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            height: 1.2, // Improved line height to prevent cut-off
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6), // Slightly more spacing
        Text(
          'Step-by-step guides for every task',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 14, // Slightly larger for better readability
            height: 1.3, // Better line height to prevent cut-off
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getRoleColor(_currentRole).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _getRoleColor(_currentRole).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getRoleIcon(_currentRole), size: 14, color: _getRoleColor(_currentRole)),
              const SizedBox(width: 6),
              Text(
                'Your role: ${RecipeData.getRoleDisplayName(_currentRole)}',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: _getRoleColor(_currentRole), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_QuickAction> _getQuickActionsForRole(AppRole role) {
    switch (role) {
      case AppRole.staff:
        return [
          _QuickAction(
            title: 'View Today\'s Tasks',
            description: 'See what you need to complete today',
            icon: Icons.today_rounded,
            onTap: () => context.go('/dashboard'),
          ),
          _QuickAction(
            title: 'Find Training Materials',
            description: 'Access guides, SOPs, and training videos',
            icon: Icons.school_rounded,
            onTap: () => context.go('/training'),
          ),
        ];
      case AppRole.manager:
        return [
          _QuickAction(
            title: 'Check Team Progress',
            description: 'Monitor active shifts and task completion',
            icon: Icons.groups_rounded,
            onTap: () => context.go('/manager'),
          ),
          _QuickAction(
            title: 'Send Team Message',
            description: 'Communicate with your team instantly',
            icon: Icons.message_rounded,
            onTap: () => _showSendNotificationSheet(),
          ),
        ];
      case AppRole.admin:
        // Build admin actions but hide web-management on iOS (App Store review restriction)
        final actions = <_QuickAction>[
          _QuickAction(
            title: 'System Overview',
            description: 'View organization-wide metrics and status',
            icon: Icons.dashboard_rounded,
            onTap: () => context.go('/admin'),
          ),
          _QuickAction(
            title: 'Web Management',
            description: 'Access advanced settings and configuration',
            icon: Icons.settings_rounded,
            onTap: () => _launchWebPortal(),
          ),
        ];

        // If running on native iOS (not iOS web), hide the Web Management action to satisfy App Review
        if (isIOS) {
          return actions.where((a) => a.title != 'Web Management').toList();
        }

        return actions;
    }
  }

  IconData _getRoleIcon(AppRole role) {
    switch (role) {
      case AppRole.staff:
        return Icons.person_rounded;
      case AppRole.manager:
        return Icons.supervisor_account_rounded;
      case AppRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Widget _buildTabContent(AppRole activeTab, bool isMobile, bool isMedium, bool isWide) {
    final isOverviewTab = activeTab != _currentRole && _currentRole != AppRole.staff;
    final recipes = RecipeData.getRecipesForRole(activeTab);

    if (isWide) {
      return _buildWideScreenLayout(activeTab, recipes, isOverviewTab);
    } else if (isMedium) {
      return _buildMediumScreenLayout(activeTab, recipes, isOverviewTab);
    } else {
      return _buildMobileLayout(activeTab, recipes, isOverviewTab);
    }
  }

  Widget _buildWideScreenLayout(AppRole activeTab, List<Recipe> recipes, bool isOverviewTab) {
    final featured = RecipeData.getFeaturedRecipes(activeTab);

    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000), // Reduced from 1200 for better density
        margin: const EdgeInsets.symmetric(horizontal: 32), // Reduced margin
        padding: const EdgeInsets.symmetric(vertical: 24), // Reduced padding
        child:
            isOverviewTab
                ? _buildOverviewCard(activeTab, false, false, true)
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main content in a unified card layout
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Quick Actions at the top in a banner style
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            child: _buildWideQuickActions(),
                          ),

                          // Content sections in a two-column layout
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left: Featured guides in a more compact grid
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionHeader('Featured Guides', Icons.star_rounded),
                                      const SizedBox(height: 16),
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: 1.3,
                                        ),
                                        itemCount: featured.length,
                                        itemBuilder: (context, index) => _buildCompactCard(featured[index]),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Right: All guides in a sidebar style
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionHeader('All Guides', Icons.list_rounded),
                                      const SizedBox(height: 16),
                                      _buildAllGuidesCompactList(recipes),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Troubleshooting as a separate card
                    _buildTroubleshootingCard(),
                  ],
                ),
      ),
    );
  }

  Widget _buildWideQuickActions() {
    final quickActions = _getQuickActionsForRole(_currentRole);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.flash_on_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(
              'Get started with the most common tasks',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children:
              quickActions
                  .map(
                    (action) => Expanded(
                      child: Padding(padding: const EdgeInsets.only(right: 12), child: _buildWideActionCard(action)),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildWideActionCard(_QuickAction action) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: action.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(action.icon, size: 18, color: Theme.of(context).colorScheme.primary),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  action.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  action.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAllGuidesCompactList(List<Recipe> recipes) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children:
            recipes.asMap().entries.map((entry) {
              final index = entry.key;
              final recipe = entry.value;
              final isLast = index == recipes.length - 1;

              return Column(
                children: [
                  _buildSidebarGuideItem(recipe),
                  if (!isLast) Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildSidebarGuideItem(Recipe recipe) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showGuideDetails(recipe),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getRoleColor(recipe.role).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(recipe.icon, size: 14, color: _getRoleColor(recipe.role)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipe.duration != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        recipe.duration!,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTroubleshootingCard() {
    final tips = RecipeData.getQuickTroubleshootingTips();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.support_agent_rounded, color: Theme.of(context).colorScheme.error, size: 20),
          ),
          title: Text(
            'Quick Troubleshooting',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Common solutions to frequent issues',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 8,
                childAspectRatio: 10,
              ),
              itemCount: tips.take(6).length,
              itemBuilder:
                  (context, index) => InkWell(
                    onTap: () => _showTroubleshootingDetails(tips[index]),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tips[index],
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediumScreenLayout(AppRole activeTab, List<Recipe> recipes, bool isOverviewTab) {
    final featured = RecipeData.getFeaturedRecipes(activeTab);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child:
          isOverviewTab
              ? _buildOverviewCard(activeTab, false, true, false)
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unified content card
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Quick Actions header
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: _buildMediumQuickActions(),
                        ),

                        // Content in two columns
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader('Featured Guides', Icons.star_rounded),
                                    const SizedBox(height: 16),
                                    ...featured.map(
                                      (recipe) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _buildListCard(recipe),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader('All Guides', Icons.list_rounded),
                                    const SizedBox(height: 16),
                                    ...recipes.map(
                                      (recipe) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: _buildMiniCard(recipe),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildTroubleshootingCard(),
                ],
              ),
    );
  }

  Widget _buildMediumQuickActions() {
    final quickActions = _getQuickActionsForRole(_currentRole);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.flash_on_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children:
              quickActions
                  .map(
                    (action) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: action == quickActions.last ? 0 : 12),
                        child: _buildMediumActionButton(action),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildMediumActionButton(_QuickAction action) {
    return FilledButton.tonal(
      onPressed: action.onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(action.icon, size: 18), const Spacer(), Icon(Icons.arrow_forward_rounded, size: 14)]),
          const SizedBox(height: 8),
          Text(action.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            action.description,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(AppRole activeTab, List<Recipe> recipes, bool isOverviewTab) {
    final featured = RecipeData.getFeaturedRecipes(activeTab);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child:
          isOverviewTab
              ? _buildOverviewCard(activeTab, true, false, false)
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions in a prominent card
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                    ),
                    child: Padding(padding: const EdgeInsets.all(20), child: _buildMobileQuickActions()),
                  ),

                  const SizedBox(height: 24),

                  // Featured guides
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Featured Guides', Icons.star_rounded),
                          const SizedBox(height: 16),
                          ...featured.map(
                            (recipe) =>
                                Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildListCard(recipe)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // All guides
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('All Guides', Icons.list_rounded),
                          const SizedBox(height: 16),
                          ...recipes.map(
                            (recipe) =>
                                Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildListCard(recipe)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildTroubleshootingCard(),

                  const SizedBox(height: 24),
                  _buildGradientSupportSection(),
                ],
              ),
    );
  }

  Widget _buildMobileQuickActions() {
    final quickActions = _getQuickActionsForRole(_currentRole);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.flash_on_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        ...quickActions.map(
          (action) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildMobileActionButton(action)),
        ),
      ],
    );
  }

  Widget _buildMobileActionButton(_QuickAction action) {
    return FilledButton.tonal(
      onPressed: action.onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(action.icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  action.description,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Removed unused: _buildFeaturedSection, _buildAllGuidesSection, _buildAllGuidesCompact
  // These helpers were not referenced and caused lint/compile warnings. Their
  // functionality remains covered by existing builders in the layout.

  Widget _buildCompactCard(Recipe recipe) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showGuideDetails(recipe),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getRoleColor(recipe.role).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(recipe.icon, size: 20, color: _getRoleColor(recipe.role)),
                    ),
                    const Spacer(),
                    if (recipe.duration != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          recipe.duration!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  recipe.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(Recipe recipe) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showGuideDetails(recipe),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getRoleColor(recipe.role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(recipe.icon, size: 20, color: _getRoleColor(recipe.role)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleColor(recipe.role).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              RecipeData.getRoleDisplayName(recipe.role),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: _getRoleColor(recipe.role),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (recipe.duration != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              recipe.duration!,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCard(Recipe recipe) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showGuideDetails(recipe),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getRoleColor(recipe.role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(recipe.icon, size: 16, color: _getRoleColor(recipe.role)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (recipe.duration != null)
                  Text(
                    recipe.duration!,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // removed unused: _buildSidebarItem

  Widget _buildOverviewCard(AppRole role, bool isMobile, bool isMedium, bool isWide) {
    return Container(
      margin: EdgeInsets.all(
        isWide
            ? 48
            : isMobile
            ? 20
            : 32,
      ),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_getRoleIcon(role), size: 32, color: _getRoleColor(role)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${RecipeData.getRoleDisplayName(role)} Overview',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Key responsibilities and capabilities',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              RecipeData.getOverviewText(role),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  // _buildTroubleshootingSection was removed (unreferenced). Keep _buildTroubleshootingCompact.

  // removed unused: _buildTroubleshootingCompact

  Widget _buildGradientSupportSection() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 800;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.support_agent_rounded, size: 48, color: Theme.of(context).colorScheme.onPrimary),
          const SizedBox(height: 16),
          Text(
            'Need More Help?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our support team is here to help you succeed',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: isMobile ? Alignment.center : Alignment.centerLeft,
            child: FilledButton(
              onPressed: () {
                context.go(AppRoutes.contactUsPage.path);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Contact Support'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideDetailView extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onAction;

  const _GuideDetailView({required this.recipe, this.onAction});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 800;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: !isMobile,
      ),
      body: CustomScrollView(
        slivers: [
          // Hero Header Section
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 16 : 24),
              padding: EdgeInsets.all(isMobile ? 20 : 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer.withOpacity(0.6),
                    colorScheme.secondaryContainer.withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Icon and Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(recipe.icon, size: isMobile ? 32 : 40, color: colorScheme.primary),
                      ),
                      SizedBox(width: isMobile ? 16 : 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step-by-Step Guide',
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              recipe.title,
                              style: Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (recipe.duration != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            'Takes ${recipe.duration}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Steps Section
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.list_alt_rounded, color: colorScheme.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Steps to Complete',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Step Cards
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final step = recipe.steps[index];
              return Container(
                margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 8),
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step Number
                    Container(
                      width: isMobile ? 32 : 36,
                      height: isMobile ? 32 : 36,
                      decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(18)),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 12 : 16),

                    // Step Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            step,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.4, color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }, childCount: recipe.steps.length),
          ),

          // Troubleshooting Section (if available)
          if (recipe.troubleshoot.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.all(isMobile ? 16 : 24),
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.error.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline_rounded, color: colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Troubleshooting Tips',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...recipe.troubleshoot.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 16, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // No bottom CTA - removed per request
      bottomNavigationBar: null,
    );
  }
}
