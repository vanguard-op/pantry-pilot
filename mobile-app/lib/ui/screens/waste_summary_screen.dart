import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pantry_pilot/data/models/pantry_item.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/recommendations.dart';
import '../../data/repositories/recommendation_repository.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_theme.dart';

class WasteSummaryScreen extends StatefulWidget {
  const WasteSummaryScreen({super.key});

  @override
  State<WasteSummaryScreen> createState() => _WasteSummaryScreenState();
}

class _WasteSummaryScreenState extends State<WasteSummaryScreen> {
  late Future<DashboardRecommendations> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _recommendationsFuture = _fetchRecommendations();
  }

  Future<DashboardRecommendations> _fetchRecommendations() {
    return context
        .read<RecommendationRepository>()
        .fetchDashboardRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final pantryItems = context.watch<PantryBloc>().state.items;
    final plannedMeals = context.watch<PlannerBloc>().state.meals;
    final recipes = context.watch<RecipesBloc>().state.recipes;

    final recipeById = {for (final recipe in recipes) recipe.id: recipe};
    final pantrySet = pantryItems
        .map((item) => item.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    final now = DateTime.now();

    final expiredCount = pantryItems
        .where((item) => item.expiryDate.isBefore(now))
        .length;
    final useSoonCount = pantryItems
        .where((item) => item.daysUntilExpiry <= 3)
        .length;

    final leftoverItems =
        pantryItems
            .where((item) => item.itemKind == PantryItemKind.cookedMeal)
            .toList(growable: false)
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    final useSoonIngredients =
        pantryItems
            .where(
              (item) =>
                  item.daysUntilExpiry <= 3 &&
                  item.itemKind == PantryItemKind.ingredient,
            )
            .toList(growable: false)
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    var missingForPlan = 0;
    for (final meal in plannedMeals.where(
      (meal) => now.difference(meal.date).inDays <= 7,
    )) {
      final recipe = recipeById[meal.recipeId];
      if (recipe == null) {
        continue;
      }
      for (final ingredient in recipe.ingredients) {
        if (!pantrySet.contains(ingredient.toLowerCase())) {
          missingForPlan += 1;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Waste Reduction')),
      body: FutureBuilder<DashboardRecommendations>(
        future: _recommendationsFuture,
        builder: (context, snapshot) {
          final repurposeIdeas =
              snapshot.data?.leftovers ?? const <LeftoverSuggestion>[];
          return ListView(
            padding: const EdgeInsets.all(AppPadding.md),
            children: <Widget>[
              Text('Use Soon', style: textTheme.titleLarge),
              const SizedBox(height: AppPadding.sm),
              if (useSoonIngredients.isEmpty)
                Text(
                  'No ingredients expiring within 3 days.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...useSoonIngredients.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.quantity} ${item.unit} • Expires ${item.expiryDate.toLocal().toString().split(' ').first}',
                      ),
                      trailing: Text('D-${item.daysUntilExpiry}'),
                    ),
                  ),
                ),
              const SizedBox(height: AppPadding.lg),
              Text('Leftovers', style: textTheme.titleLarge),
              const SizedBox(height: AppPadding.sm),
              if (leftoverItems.isEmpty)
                Text(
                  'No cooked meal leftovers logged yet. Log them from Meal Completion.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...leftoverItems.map((item) {
                  final sourceTitle = item.name.trim();
                  final itemIdeas = repurposeIdeas
                      .where(
                        (idea) =>
                            idea.sourceRecipeTitle.toLowerCase().trim() ==
                            sourceTitle.toLowerCase().trim(),
                      )
                      .take(2)
                      .toList(growable: false);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppPadding.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(sourceTitle, style: textTheme.titleMedium),
                          const SizedBox(height: AppPadding.xs),
                          Text(
                            '${item.quantity.toInt()} serving${item.quantity.toInt() == 1 ? '' : 's'} • Consume by ${item.expiryDate.toLocal().toString().split(' ').first}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppPadding.sm),
                          if (itemIdeas.isEmpty)
                            Text(
                              'Repurpose idea: turn leftovers into wraps, bowls, or pasta add-ins.',
                              style: textTheme.bodySmall,
                            )
                          else
                            ...itemIdeas.map(
                              (idea) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(idea.recipe.title),
                                subtitle: Text(idea.reason),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.pushNamed(
                                  AppRouter.recipeDetailName,
                                  pathParameters: <String, String>{
                                    AppRouter.recipeIdParam: idea.recipe.id,
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: AppPadding.sm),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    context.read<PantryBloc>().add(
                                      PantryItemDeleted(item.id),
                                    );
                                  },
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Mark used'),
                                ),
                              ),
                              const SizedBox(width: AppPadding.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    context.read<PantryBloc>().add(
                                      PantryItemDeleted(item.id),
                                    );
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Discard'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppPadding.lg),
              Text('Weekly Waste Summary', style: textTheme.titleLarge),
              const SizedBox(height: AppPadding.sm),
              _SummaryCard(
                title: 'Expired items',
                value: '$expiredCount',
                note: 'Lower is better. Aim for zero each week.',
                icon: Icons.delete_sweep_outlined,
              ),
              const SizedBox(height: AppPadding.md),
              _SummaryCard(
                title: 'Use-soon pressure',
                value: '$useSoonCount items',
                note: 'These items should be prioritized in next meals.',
                icon: Icons.warning_amber_outlined,
              ),
              const SizedBox(height: AppPadding.md),
              _SummaryCard(
                title: 'Missing ingredients in weekly plan',
                value: '$missingForPlan',
                note:
                    'Shopping list closes these gaps and prevents wasteful duplicates.',
                icon: Icons.shopping_cart_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.note,
    required this.icon,
  });

  final String title;
  final String value;
  final String note;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppPadding.md),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(note),
        trailing: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
