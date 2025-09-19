import 'package:flutter/material.dart';
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
    // Initialize with defaults, role will be determined in build() when userState is available
    _currentRole = AppRole.staff;
    _visibleTabs = [AppRole.staff];
    _tabController = TabController(length: _visibleTabs.length, vsync: this);
    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
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
    final url = Uri.parse('https://portal.planwithhands.com/settings/locations');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showRecipeDetails(Recipe recipe) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog.fullscreen(child: _RecipeDetailView(recipe: recipe, onAction: () => _handleCta(recipe))),
    );
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

    // Show loading screen if userData is not available yet
    if (userState.userData == null) {
      debugPrint('HelpCenter: === USER DATA NOT LOADED YET ===');
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final userRole = widget.userRole ?? userState.userData!.userRole;
    final currentRole = toAppRole(userRole);
    final visibleTabs = RecipeData.getVisibleTabs(currentRole);

    // Debug output
    debugPrint('HelpCenter: === BUILD METHOD DEBUG ===');
    debugPrint('HelpCenter: userState.userData = ${userState.userData}');
    debugPrint('HelpCenter: userRole=$userRole -> $currentRole, tabs=$visibleTabs');
    debugPrint('HelpCenter: THIS IS THE NEW FIXED VERSION!');
    debugPrint('HelpCenter: === END BUILD DEBUG ===');

    // Update tabs if role changed
    if (currentRole != _currentRole || visibleTabs.length != _visibleTabs.length) {
      _currentRole = currentRole;
      _visibleTabs = visibleTabs;
      _tabController.dispose();
      _tabController = TabController(length: _visibleTabs.length, vsync: this);
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
                      ? 140
                      : isWide
                      ? 160
                      : 150, // Reduced heights
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
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
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
            50, // Reduced from 60
            isWide
                ? 48
                : isMobile
                ? 20
                : 32,
            16, // Reduced from 24
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
                // Mobile and medium: Just title
                Flexible(child: _buildHeroTitle()),
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
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 24, height: 1.1),
        ),
        const SizedBox(height: 4),
        Text(
          'Step-by-step guides for every task',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
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

  Widget _buildQuickActionsInHero() {
    final quickActions = _getQuickActionsForRole(_currentRole);

    return Container(
      padding: const EdgeInsets.all(16), // Reduced padding
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12), // Smaller border radius
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 18, // Smaller icon
              ),
              const SizedBox(width: 6),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  // Smaller title
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10), // Reduced spacing
          ...quickActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 6), // Reduced spacing
              child: _buildCompactQuickActionButton(action),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactQuickActionButton(_QuickAction action) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: action.onTap,
          child: Padding(
            padding: const EdgeInsets.all(8), // Smaller padding
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    action.icon,
                    size: 14, // Smaller icon
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12, // Smaller font
                        ),
                      ),
                      Text(
                        action.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10, // Smaller font
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12, // Smaller icon
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
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
        return [
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
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
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
        onTap: () => _showRecipeDetails(recipe),
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
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 8,
                childAspectRatio: 8,
              ),
              itemCount: tips.take(6).length,
              itemBuilder:
                  (context, index) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tips[index],
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildQuickStartSection(List<Recipe> recipes, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Start', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) => _buildCompactCard(recipes[index]),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard(List<Recipe> featured) {
    final quickActions = _getQuickActionsForRole(_currentRole);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
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
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...quickActions.map(
            (action) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildMobileActionButton(action)),
          ),
        ],
      ),
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

  Widget _buildFeaturedSection(List<Recipe> featured, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured Guides',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (isWide) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: featured.length,
            itemBuilder: (context, index) => _buildCompactCard(featured[index]),
          ),
        ] else ...[
          ...featured.map(
            (recipe) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildListCard(recipe)),
          ),
        ],
      ],
    );
  }

  Widget _buildAllGuidesSection(List<Recipe> recipes, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('All Guides', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (isMobile) ...[
          ...recipes.map(
            (recipe) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildListCard(recipe)),
          ),
        ] else ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3.5,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) => _buildMiniCard(recipes[index]),
          ),
        ],
      ],
    );
  }

  Widget _buildAllGuidesCompact(List<Recipe> recipes) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Guides', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...recipes.map(
            (recipe) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildSidebarItem(recipe)),
          ),
        ],
      ),
    );
  }

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
          onTap: () => _showRecipeDetails(recipe),
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
                          color: Theme.of(context).colorScheme.surfaceVariant,
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
                if (recipe.ctaLabel != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => _handleCta(recipe),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(recipe.ctaLabel!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
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
          onTap: () => _showRecipeDetails(recipe),
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
          onTap: () => _showRecipeDetails(recipe),
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

  Widget _buildSidebarItem(Recipe recipe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _showRecipeDetails(recipe),
        child: Row(
          children: [
            Icon(recipe.icon, size: 16, color: _getRoleColor(recipe.role)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                recipe.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
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

  Widget _buildTroubleshootingSection() {
    return _buildTroubleshootingCompact();
  }

  Widget _buildTroubleshootingCompact() {
    final tips = RecipeData.getQuickTroubleshootingTips();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.2)),
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
          children:
              tips
                  .take(5)
                  .map(
                    (tip) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(child: Text(tip, style: Theme.of(context).textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

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

class _RecipeDetailView extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onAction;

  const _RecipeDetailView({required this.recipe, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(recipe.title), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe content here - simplified for now
            Text('Recipe Details', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(recipe.title),
            const SizedBox(height: 16),
            ...recipe.steps.map((step) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• $step'))),
          ],
        ),
      ),
      bottomNavigationBar:
          recipe.ctaLabel != null
              ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onAction?.call();
                    },
                    child: Text(recipe.ctaLabel!),
                  ),
                ),
              )
              : null,
    );
  }
}
