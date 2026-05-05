import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/recipe.dart';
import '../../navigation/app_router.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context) {
    final recipes = context.watch<RecipesBloc>().state.recipes;
    Recipe? recipe;
    for (final current in recipes) {
      if (current.id == recipeId) {
        recipe = current;
        break;
      }
    }

    if (recipe == null) {
      return const Scaffold(body: Center(child: Text('Recipe not found')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(recipe.description),
          const SizedBox(height: 12),
          Text(
            'Time: ${recipe.totalMinutes} min | Servings: ${recipe.servings}',
          ),
          Text('Difficulty: ${recipe.difficulty}'),
          const SizedBox(height: 12),
          const Text(
            'Ingredients',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...recipe.ingredients.map((ingredient) => Text('- $ingredient')),
          const SizedBox(height: 12),
          const Text('Steps', style: TextStyle(fontWeight: FontWeight.bold)),
          ...recipe.steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${entry.key + 1}. ${entry.value.description} (${entry.value.durationMinutes} min)',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.pushNamed(
              AppRouter.recipeCookName,
              pathParameters: <String, String>{
                AppRouter.recipeIdParam: recipeId,
              },
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start cooking'),
          ),
        ],
      ),
    );
  }
}
