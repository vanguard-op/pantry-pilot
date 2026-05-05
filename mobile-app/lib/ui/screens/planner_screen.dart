import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/planned_meal.dart';
import '../../data/models/recipe.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plannerState = context.watch<PlannerBloc>().state;
    final recipes = context.watch<RecipesBloc>().state.recipes;

    final next7Days = List<DateTime>.generate(
      7,
      (i) => DateTime.now().add(Duration(days: i)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Planner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: next7Days
            .map((day) {
              final daily = plannerState.meals.where(
                (meal) =>
                    meal.date.year == day.year &&
                    meal.date.month == day.month &&
                    meal.date.day == day.day,
              );

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        day.toLocal().toString().split(' ').first,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...daily.map((meal) {
                        final recipe = _findRecipeById(recipes, meal.recipeId);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(recipe?.title ?? 'Unknown recipe'),
                          subtitle: Text(meal.slot),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => context.read<PlannerBloc>().add(
                              PlannedMealDeleted(meal.id),
                            ),
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () => _showAddMealDialog(context, day),
                        icon: const Icon(Icons.add),
                        label: const Text('Add meal'),
                      ),
                    ],
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Future<void> _showAddMealDialog(BuildContext context, DateTime day) async {
    final recipes = context.read<RecipesBloc>().state.recipes;
    final pantryItems = context.read<PantryBloc>().state.items;
    final pantrySet = pantryItems
        .map((item) => item.name.toLowerCase())
        .toSet();

    final suggested = List<Recipe>.from(recipes)
      ..sort(
        (a, b) => _coverageScore(
          b,
          pantrySet,
        ).compareTo(_coverageScore(a, pantrySet)),
      );

    Recipe? selectedRecipe;
    String selectedSlot = 'Dinner';

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Plan meal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedSlot,
                    decoration: const InputDecoration(labelText: 'Meal slot'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'Breakfast',
                        child: Text('Breakfast'),
                      ),
                      DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                    ],
                    onChanged: (value) =>
                        setState(() => selectedSlot = value ?? 'Dinner'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRecipe?.id,
                    decoration: const InputDecoration(
                      labelText: 'Suggested recipes',
                    ),
                    isExpanded: true,
                    items: suggested
                        .take(20)
                        .map(
                          (recipe) => DropdownMenuItem<String>(
                            value: recipe.id,
                            child: Text(
                              '${recipe.title} (${_coverageScore(recipe, pantrySet)}% pantry)',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setState(() {
                        selectedRecipe = suggested.firstWhere(
                          (recipe) => recipe.id == value,
                        );
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedRecipe == null
                      ? null
                      : () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true || selectedRecipe == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    context.read<PlannerBloc>().add(
      PlannedMealAdded(
        PlannedMeal(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          recipeId: selectedRecipe!.id,
          date: DateTime(day.year, day.month, day.day),
          slot: selectedSlot,
        ),
      ),
    );
  }

  int _coverageScore(Recipe recipe, Set<String> pantryItems) {
    final covered = recipe.ingredients
        .where((ingredient) => pantryItems.contains(ingredient.toLowerCase()))
        .length;
    return ((covered / recipe.ingredients.length) * 100).round();
  }

  Recipe? _findRecipeById(List<Recipe> recipes, String recipeId) {
    for (final recipe in recipes) {
      if (recipe.id == recipeId) {
        return recipe;
      }
    }
    return null;
  }
}
