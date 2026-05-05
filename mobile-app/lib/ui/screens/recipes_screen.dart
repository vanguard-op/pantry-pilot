import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/recipes/recipes_bloc.dart';
import '../../navigation/app_router.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RecipesBloc>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Library')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search recipes or ingredients',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  context.read<RecipesBloc>().add(RecipesSearchChanged(value)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: state.filteredRecipes.length,
              itemBuilder: (context, index) {
                final recipe = state.filteredRecipes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text(recipe.title),
                    subtitle: Text(
                      '${recipe.difficulty} - ${recipe.totalMinutes} min - ${recipe.ingredients.length} ingredients',
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        recipe.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: recipe.isFavorite ? Colors.red : null,
                      ),
                      onPressed: () => context.read<RecipesBloc>().add(
                        RecipeFavoriteToggled(recipe.id),
                      ),
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
          ),
        ],
      ),
    );
  }
}
