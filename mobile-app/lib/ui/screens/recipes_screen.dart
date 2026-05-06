import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/recipe.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_theme.dart';
import '../widgets/recipe_summary_card.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  static const _timeOptions = <int>[15, 30, 45, 60];
  static const _skillOptions = <String>['Beginner', 'Intermediate', 'Confident'];
  static const _dietOptions = <String>['Quick', 'Easy', 'Leafy Greens', 'Weeknight'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<RecipesBloc>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Library')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppPadding.md,
              AppPadding.md,
              AppPadding.md,
              AppPadding.sm,
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: AppPadding.md),
            child: Wrap(
              spacing: AppPadding.sm,
              runSpacing: AppPadding.sm,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppPadding.md,
              AppPadding.md,
              AppPadding.md,
              AppPadding.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${state.filteredRecipes.length} recipes ready',
                    style: textTheme.titleMedium,
                  ),
                ),
                Text(
                  state.searchTerm.isEmpty &&
                          state.maxMinutesFilter == null &&
                          state.skillFilter == null &&
                          state.dietFilter == null
                      ? 'All results'
                      : 'Filtered',
                  style: textTheme.labelMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: state.filteredRecipes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppPadding.xl),
                      child: Text(
                        'No recipes match those filters yet. Try widening your search.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppPadding.md,
                      0,
                      AppPadding.md,
                      AppPadding.md,
                    ),
                    itemCount: state.filteredRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = state.filteredRecipes[index];
                      return RecipeSummaryCard(
                        recipe: recipe,
                        leadingLabel: 'Recipe pick',
                        trailingText: _buildRecipeInsight(recipe),
                        onFavoriteToggle: () => context.read<RecipesBloc>().add(
                          RecipeFavoriteToggled(recipe.id),
                        ),
                        onTap: () => context.pushNamed(
                          AppRouter.recipeDetailName,
                          pathParameters: <String, String>{
                            AppRouter.recipeIdParam: recipe.id,
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _buildRecipeInsight(Recipe recipe) {
    return '${recipe.ingredients.length} pantry items to prep • ${recipe.steps.length} cooking steps';
  }
}
