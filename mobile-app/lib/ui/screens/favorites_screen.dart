import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_theme.dart';
import '../widgets/recipe_summary_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recipesState = context.watch<RecipesBloc>().state;
    final plannerMeals = context.watch<PlannerBloc>().state.meals;
    final favoriteRecipes = recipesState.recipes
        .where((recipe) => recipe.isFavorite)
        .toList(growable: false)
      ..sort((a, b) => a.title.compareTo(b.title));

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: favoriteRecipes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppPadding.xl),
                child: Text(
                  'No favorite recipes yet. Save a few from the library and they will show up here.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppPadding.md),
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

                return RecipeSummaryCard(
                  recipe: recipe,
                  leadingLabel: 'Saved favorite',
                  footer: Row(
                    children: <Widget>[
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: AppPadding.sm),
                      Expanded(
                        child: Text(
                          'Planned $usageCount times'
                          '${lastPlannedDate == null ? '' : ' • Last planned ${_formatDate(lastPlannedDate)}'}',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  onFavoriteToggle: () {
                    context.read<RecipesBloc>().add(
                      RecipeFavoriteToggled(recipe.id),
                    );
                  },
                  onTap: () => context.pushNamed(
                    AppRouter.recipeDetailName,
                    pathParameters: <String, String>{
                      AppRouter.recipeIdParam: recipe.id,
                    },
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
