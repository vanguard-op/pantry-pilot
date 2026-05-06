import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/recipes/recipes_bloc.dart';
import '../../navigation/app_router.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  static const _timeOptions = <int>[15, 30, 45, 60];
  static const _skillOptions = <String>['Beginner', 'Intermediate', 'Confident'];
  static const _dietOptions = <String>['Quick', 'Easy', 'Leafy Greens', 'Weeknight'];

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                DropdownButton<int?>(
                  value: state.maxMinutesFilter,
                  hint: const Text('Max time'),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem<int?>(value: null, child: Text('Any time')),
                    ..._timeOptions.map(
                      (minutes) => DropdownMenuItem<int?>(
                        value: minutes,
                        child: Text('<= $minutes min'),
                      ),
                    ),
                  ],
                  onChanged: (value) => context
                      .read<RecipesBloc>()
                      .add(RecipesTimeFilterChanged(value)),
                ),
                DropdownButton<String?>(
                  value: state.skillFilter,
                  hint: const Text('Skill'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('Any skill')),
                    ..._skillOptions.map(
                      (skill) => DropdownMenuItem<String?>(
                        value: skill,
                        child: Text(skill),
                      ),
                    ),
                  ],
                  onChanged: (value) => context
                      .read<RecipesBloc>()
                      .add(RecipesSkillFilterChanged(value)),
                ),
                DropdownButton<String?>(
                  value: state.dietFilter,
                  hint: const Text('Dietary'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('Any dietary')),
                    ..._dietOptions.map(
                      (diet) => DropdownMenuItem<String?>(
                        value: diet,
                        child: Text(diet),
                      ),
                    ),
                  ],
                  onChanged: (value) => context
                      .read<RecipesBloc>()
                      .add(RecipesDietFilterChanged(value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
