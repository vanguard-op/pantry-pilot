import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';

class WasteSummaryScreen extends StatelessWidget {
  const WasteSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: const Text('Weekly Waste Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SummaryCard(
            title: 'Expired items',
            value: '$expiredCount',
            note: 'Lower is better. Aim for zero each week.',
            icon: Icons.delete_sweep_outlined,
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: 'Use-soon pressure',
            value: '$useSoonCount items',
            note: 'These items should be prioritized in next meals.',
            icon: Icons.warning_amber_outlined,
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: 'Missing ingredients in weekly plan',
            value: '$missingForPlan',
            note:
                'Shopping list closes these gaps and prevents wasteful duplicates.',
            icon: Icons.shopping_cart_outlined,
          ),
          const SizedBox(height: 20),
          const Text(
            'Suggested next actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('1. Plan meals using current use-soon ingredients first.'),
          const Text(
            '2. Buy only missing ingredients from the generated shopping list.',
          ),
          const Text('3. Review pantry and clear expired items weekly.'),
        ],
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
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(note),
        trailing: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
