import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/core/async_state.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/recipe.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_theme.dart';
import '../widgets/api_status_banner.dart';
import '../widgets/recipe_summary_card.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  static const _timeOptions = <int>[15, 30, 45, 60];
  static const _skillOptions = <String>[
    'Beginner',
    'Intermediate',
    'Confident',
  ];
  static const _dietOptions = <String>[
    'Quick',
    'Easy',
    'Leafy Greens',
    'Weeknight',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = context.watch<RecipesBloc>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Recipe Library')),
      body: BlocListener<RecipesBloc, RecipesState>(
        listenWhen: (previous, current) {
          final status = current.requestStatus;
          return status is SuccessStatus<void> &&
              previous.requestStatus != current.requestStatus;
        },
        listener: (context, state) {
          final status = state.requestStatus;
          if (status is! SuccessStatus<void>) {
            return;
          }

          final message = switch (status.actionKey) {
            'recipes.favoriteToggled' => 'Recipe updated',
            _ => null,
          };
          if (message == null) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
        child: Column(
          children: <Widget>[
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppPadding.md,
                  AppPadding.md,
                  AppPadding.md,
                  0,
                ),
                child: ApiStatusBanner(
                  message: state.errorMessage ?? 'Could not load recipes',
                  subtitle: 'Try again when the connection is stable.',
                  onRetry: () =>
                      context.read<RecipesBloc>().add(const RecipesStarted()),
                ),
              ),
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
                onChanged: (value) => context.read<RecipesBloc>().add(
                  RecipesSearchChanged(value),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppPadding.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = AppPadding.sm;
                  const minFieldWidth = 156.0;
                  const maxFieldWidth = 240.0;
                  final desiredWidth =
                      (constraints.maxWidth - (spacing * 2)) / 3;
                  final fieldWidth = desiredWidth
                      .clamp(minFieldWidth, maxFieldWidth)
                      .toDouble();
                  final totalRowWidth = (fieldWidth * 3) + (spacing * 2);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppPadding.sm,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: SizedBox(
                        width: totalRowWidth < constraints.maxWidth
                            ? constraints.maxWidth
                            : totalRowWidth,
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: fieldWidth,
                              child: _RecipeFilterField<int>(
                                label: 'Max time',
                                value: state.maxMinutesFilter,
                                items: <DropdownMenuItem<int?>>[
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Any time'),
                                  ),
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
                            ),
                            const SizedBox(width: spacing),
                            SizedBox(
                              width: fieldWidth,
                              child: _RecipeFilterField<String>(
                                label: 'Skill',
                                value: state.skillFilter,
                                items: <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Any skill'),
                                  ),
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
                            ),
                            const SizedBox(width: spacing),
                            SizedBox(
                              width: fieldWidth,
                              child: _RecipeFilterField<String>(
                                label: 'Dietary',
                                value: state.dietFilter,
                                items: <DropdownMenuItem<String?>>[
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Any dietary'),
                                  ),
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
              child: state.isLoading && state.filteredRecipes.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.filteredRecipes.isEmpty
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
                          onFavoriteToggle: () => context
                              .read<RecipesBloc>()
                              .add(RecipeFavoriteToggled(recipe.id)),
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
      ),
    );
  }

  String _buildRecipeInsight(Recipe recipe) {
    return '${recipe.ingredients.length} pantry items to prep • ${recipe.steps.length} cooking steps';
  }
}

class _RecipeFilterField<T> extends StatelessWidget {
  const _RecipeFilterField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T?>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T?>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      borderRadius: BorderRadius.circular(AppRadius.md),
      isExpanded: true,
    );
  }
}
