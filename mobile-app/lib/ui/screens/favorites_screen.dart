import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../navigation/app_router.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipesState = context.watch<RecipesBloc>().state;
    final plannerMeals = context.watch<PlannerBloc>().state.meals;
    final favoriteRecipes = recipesState.recipes
        .where((recipe) => recipe.isFavorite)
        .toList(growable: false)
      ..sort((a, b) => a.title.compareTo(b.title));

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favoriteRecipes.isEmpty
          ? const Center(child: Text('No favorite recipes yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: favoriteRecipes.length,
              itemBuilder: (context, index) {
                final recipe = favoriteRecipes[index];
                final usageCount = plannerMeals
                    .where((meal) => meal.recipeId == recipe.id)
                    .length;
                DateTime? lastPlannedDate;
                for (final meal in plannerMeals) {
                  if (meal.recipeId != recipe.id) {
                    continue;
                  }
                  if (lastPlannedDate == null || meal.date.isAfter(lastPlannedDate)) {
                    lastPlannedDate = meal.date;
                  }
                }

                return Card(
                  child: ListTile(
                    title: Text(recipe.title),
                    subtitle: Text(
                      'Planned $usageCount times'
                      '${lastPlannedDate == null ? '' : ' • Last planned ${_formatDate(lastPlannedDate)}'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite),
                      color: Colors.red,
                      onPressed: () {
                        context.read<RecipesBloc>().add(
                          RecipeFavoriteToggled(recipe.id),
                        );
                      },
                    ),
                    onTap: () => context.pushNamed(
                      AppRouter.recipeDetailName,
                      pathParameters: <String, String>{
                        AppRouter.recipeIdParam: recipe.id,
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }
}
