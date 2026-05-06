import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/planned_meal.dart';
import '../../data/models/recipe.dart';
import '../../data/recommendations/recommendation_engine.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_theme.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final plannerState = context.watch<PlannerBloc>().state;
    final pantryItems = context.watch<PantryBloc>().state.items;
    final recipes = context.watch<RecipesBloc>().state.recipes;
    final rankedRecommendations = RecommendationEngine.rankRecipes(
      recipes: recipes,
      pantryItems: pantryItems,
      plannedMeals: plannerState.meals,
    );
    final favoriteRecipes = RecommendationEngine.favoriteRecipes(
      recipes: recipes,
      pantryItems: pantryItems,
      plannedMeals: plannerState.meals,
    );
    final repeatRecipes = RecommendationEngine.repeatRecipes(
      recipes: recipes,
      plannedMeals: plannerState.meals,
    );

    final next7Days = List<DateTime>.generate(
      7,
      (i) => DateTime.now().add(Duration(days: i)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Planner'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Shopping list',
            onPressed: () => context.pushNamed(AppRouter.shoppingListName),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppPadding.md),
        children: next7Days
            .map((day) {
              final quickPicks = rankedRecommendations
                  .where((item) => !_isRecipePlannedOnDay(item.recipe.id, day, plannerState.meals))
                  .take(3)
                  .toList(growable: false);
              final daily = plannerState.meals.where(
                (meal) =>
                    meal.date.year == day.year &&
                    meal.date.month == day.month &&
                    meal.date.day == day.day,
              );

              return DragTarget<PlannedMeal>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (details) {
                  _moveMealToDay(context, meal: details.data, day: day);
                },
                builder: (context, candidateData, rejectedData) {
                  final isActiveDrop = candidateData.isNotEmpty;
                  return Card(
                    color: isActiveDrop
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(AppPadding.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            day.toLocal().toString().split(' ').first,
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppPadding.sm),
                          ...daily.map((meal) {
                            final recipe = _findRecipeById(recipes, meal.recipeId);
                            return LongPressDraggable<PlannedMeal>(
                              data: meal,
                              feedback: Material(
                                child: Container(
                                  padding: const EdgeInsets.all(AppPadding.sm),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Text(recipe?.title ?? 'Planned meal'),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(recipe?.title ?? 'Unknown recipe'),
                                subtitle: Text('${meal.slot} • Drag to reschedule'),
                                trailing: Wrap(
                                  spacing: 4,
                                  children: <Widget>[
                                    IconButton(
                                      tooltip: 'Cook now',
                                      icon: const Icon(Icons.play_circle_outline),
                                      onPressed: recipe == null
                                          ? null
                                          : () => context.pushNamed(
                                              AppRouter.recipeCookName,
                                              pathParameters: <String, String>{
                                                AppRouter.recipeIdParam: recipe.id,
                                              },
                                              queryParameters: <String, String>{
                                                'plannedMealId': meal.id,
                                              },
                                            ),
                                    ),
                                    IconButton(
                                      tooltip: 'Edit slot',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _showEditMealSlotDialog(
                                        context,
                                        meal: meal,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete meal',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => context.read<PlannerBloc>().add(
                                        PlannedMealDeleted(meal.id),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (quickPicks.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppPadding.sm),
                            Text(
                              'Quick add',
                              style: textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppPadding.sm),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: quickPicks
                                  .map(
                                    (item) => ActionChip(
                                      label: Text(item.recipe.title),
                                      avatar: item.useSoonIngredients.isNotEmpty
                                          ? const Icon(Icons.warning_amber_outlined, size: 18)
                                          : null,
                                      onPressed: () => _quickAddMeal(
                                        context,
                                        day: day,
                                        recipe: item.recipe,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                          TextButton.icon(
                            onPressed: () => _showAddMealDialog(
                              context,
                              day,
                              rankedRecommendations,
                              favoriteRecipes,
                              repeatRecipes,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add meal'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Future<void> _showAddMealDialog(
    BuildContext context,
    DateTime day,
    List<RecipeRecommendation> rankedRecommendations,
    List<Recipe> favoriteRecipes,
    List<Recipe> repeatRecipes,
  ) async {
    Recipe? selectedRecipe;
    String selectedSlot = 'Dinner';

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Plan meal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: AppPadding.md),
                    if (favoriteRecipes.isNotEmpty) ...<Widget>[
                      Text(
                        'Favorites',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppPadding.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: favoriteRecipes
                            .map(
                              (recipe) => ChoiceChip(
                                label: Text(recipe.title),
                                selected: selectedRecipe?.id == recipe.id,
                                onSelected: (_) => setState(() => selectedRecipe = recipe),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppPadding.md),
                    ],
                    if (repeatRecipes.isNotEmpty) ...<Widget>[
                      Text(
                        'Repeat meals',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppPadding.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: repeatRecipes
                            .map(
                              (recipe) => ChoiceChip(
                                label: Text(recipe.title),
                                selected: selectedRecipe?.id == recipe.id,
                                onSelected: (_) => setState(() => selectedRecipe = recipe),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: AppPadding.md),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: selectedRecipe?.id,
                      decoration: const InputDecoration(
                        labelText: 'Suggested recipes',
                      ),
                      isExpanded: true,
                      items: rankedRecommendations
                          .take(20)
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.recipe.id,
                              child: Text(
                                '${item.recipe.title} (${item.pantryCoverage}% pantry)',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        setState(() {
                          selectedRecipe = rankedRecommendations
                              .firstWhere((item) => item.recipe.id == value)
                              .recipe;
                        });
                      },
                    ),
                    if (selectedRecipe != null) ...<Widget>[
                      const SizedBox(height: AppPadding.md),
                      Text(
                        'Selected: ${selectedRecipe!.title}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ],
                ),
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

    _addMeal(context, day: day, recipe: selectedRecipe!, slot: selectedSlot);
  }

  void _quickAddMeal(
    BuildContext context, {
    required DateTime day,
    required Recipe recipe,
  }) {
    _addMeal(context, day: day, recipe: recipe, slot: 'Dinner');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${recipe.title} added to dinner')),
    );
  }

  void _addMeal(
    BuildContext context, {
    required DateTime day,
    required Recipe recipe,
    required String slot,
    String? id,
  }) {
    context.read<PlannerBloc>().add(
      PlannedMealAdded(
        PlannedMeal(
          id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          recipeId: recipe.id,
          date: DateTime(day.year, day.month, day.day),
          slot: slot,
        ),
      ),
    );
  }

  void _moveMealToDay(
    BuildContext context, {
    required PlannedMeal meal,
    required DateTime day,
  }) {
    final sameDay =
        meal.date.year == day.year &&
        meal.date.month == day.month &&
        meal.date.day == day.day;
    if (sameDay) {
      return;
    }

    context.read<PlannerBloc>().add(
      PlannedMealAdded(
        PlannedMeal(
          id: meal.id,
          recipeId: meal.recipeId,
          date: DateTime(day.year, day.month, day.day),
          slot: meal.slot,
        ),
      ),
    );
  }

  Future<void> _showEditMealSlotDialog(
    BuildContext context, {
    required PlannedMeal meal,
  }) async {
    String selectedSlot = meal.slot;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Edit meal slot'),
              content: DropdownButtonFormField<String>(
                initialValue: selectedSlot,
                decoration: const InputDecoration(labelText: 'Meal slot'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'Breakfast', child: Text('Breakfast')),
                  DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                  DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => selectedSlot = value);
                },
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true || !context.mounted || selectedSlot == meal.slot) {
      return;
    }

    context.read<PlannerBloc>().add(
      PlannedMealAdded(
        PlannedMeal(
          id: meal.id,
          recipeId: meal.recipeId,
          date: meal.date,
          slot: selectedSlot,
        ),
      ),
    );
  }

  bool _isRecipePlannedOnDay(
    String recipeId,
    DateTime day,
    List<PlannedMeal> meals,
  ) {
    return meals.any(
      (meal) =>
          meal.recipeId == recipeId &&
          meal.date.year == day.year &&
          meal.date.month == day.month &&
          meal.date.day == day.day,
    );
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
