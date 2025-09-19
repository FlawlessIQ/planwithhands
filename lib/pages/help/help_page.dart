import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hands_app/state/user_state.dart';
import 'package:hands_app/models/recipe.dart';
import 'package:hands_app/core/logging/logger.dart';

class HelpPage extends ConsumerStatefulWidget {
  final int? userRole;

  const HelpPage({super.key, this.userRole});

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage> {
  String _selectedCategory = 'All';

  /// Get current user role from props or user state provider
  AppRole get _currentUserRole {
    // First try to use the role passed via route parameter
    if (widget.userRole != null) {
      logger.d('[HelpPage] Using role from route parameter: ${widget.userRole}');
      return toAppRole(widget.userRole!);
    }

    // Fall back to user state provider
    final userState = ref.watch(userStateProvider);
    final userRole = userState.userData?.userRole ?? 0;
    logger.d('[HelpPage] Using role from user state: $userRole');
    return toAppRole(userRole);
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = _currentUserRole;

    // Get recipes for current user role using the new RecipeData class
    final availableRecipes = RecipeData.getRecipesForRole(currentRole);

    // Get unique categories
    final categories = ['All', ...availableRecipes.map((r) => r.category).toSet()];

    // Filter by selected category
    final filteredRecipes =
        _selectedCategory == 'All'
            ? availableRecipes
            : availableRecipes.where((r) => r.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Help Center'), backgroundColor: Theme.of(context).colorScheme.primaryContainer),
      body: Column(
        children: [
          // Category filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    categories.map((category) {
                      final isSelected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),

          // Recipe list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredRecipes.length,
              itemBuilder: (context, index) {
                final recipe = filteredRecipes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    leading: Icon(recipe.icon, color: Theme.of(context).colorScheme.primary),
                    title: Text(recipe.title, style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${recipe.duration} • ${recipe.role} • ${recipe.category}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        if (recipe.ctaLabel != null)
                          Text(
                            recipe.ctaLabel!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Steps section
                            Text(
                              'Steps:',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...recipe.steps.asMap().entries.map((entry) {
                              final stepIndex = entry.key + 1;
                              final step = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          stepIndex.toString(),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(step, style: Theme.of(context).textTheme.bodyMedium)),
                                  ],
                                ),
                              );
                            }),

                            // Troubleshoot section
                            if (recipe.troubleshoot.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Troubleshooting:',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...recipe.troubleshoot.map((troubleshootItem) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.help_outline,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          troubleshootItem,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
