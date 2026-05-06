import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/recommendations.dart';
import '../../data/models/recipe.dart';
import '../../data/repositories/recommendation_repository.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_theme.dart';
import '../widgets/api_status_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardRecommendations> _recommendationsFuture;

  @override
  void initState() {
    super.initState();
    _recommendationsFuture = _fetchRecommendations();
  }

  Future<DashboardRecommendations> _fetchRecommendations() {
    return context
        .read<RecommendationRepository>()
        .fetchDashboardRecommendations();
  }

  void _refreshRecommendations() {
    setState(() {
      _recommendationsFuture = _fetchRecommendations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pantryState = context.watch<PantryBloc>().state;
    final plannerState = context.watch<PlannerBloc>().state;
    final recipes = context.watch<RecipesBloc>().state.recipes;
    final upcomingMeals =
        plannerState.meals
            .where(
              (meal) => !meal.date.isBefore(
                DateTime.now().subtract(const Duration(days: 1)),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.date.compareTo(b.date));

    return MultiBlocListener(
      listeners: <BlocListener<dynamic, dynamic>>[
        BlocListener<PlannerBloc, PlannerState>(
          listenWhen: (previous, current) => previous.meals != current.meals,
          listener: (context, state) => _refreshRecommendations(),
        ),
        BlocListener<PantryBloc, PantryState>(
          listenWhen: (previous, current) => previous.items != current.items,
          listener: (context, state) => _refreshRecommendations(),
        ),
        BlocListener<RecipesBloc, RecipesState>(
          listenWhen: (previous, current) =>
              previous.recipes != current.recipes,
          listener: (context, state) => _refreshRecommendations(),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: const Text('PantryPilot')),
        body: FutureBuilder<DashboardRecommendations>(
          future: _recommendationsFuture,
          builder: (context, snapshot) {
            final recommendations =
                snapshot.data ?? DashboardRecommendations.empty;
            final useSoonIdeas = recommendations.useSoon;
            final leftoverIdeas = recommendations.leftovers;

            return ListView(
              padding: const EdgeInsets.all(AppPadding.md),
              children: <Widget>[
                if (snapshot.hasError)
                  ApiStatusBanner(
                    message: 'Could not refresh meal ideas',
                    onRetry: _refreshRecommendations,
                  ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.pushNamed(AppRouter.kpiName),
                        icon: const Icon(Icons.query_stats),
                        label: const Text('KPI dashboard'),
                      ),
                    ),
                    const SizedBox(width: AppPadding.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.pushNamed(AppRouter.feedbackName),
                        icon: const Icon(Icons.feedback_outlined),
                        label: const Text('Feedback'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppPadding.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.pushNamed(AppRouter.favoritesName),
                        icon: const Icon(Icons.favorite_outline),
                        label: const Text('Favorites'),
                      ),
                    ),
                    const SizedBox(width: AppPadding.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.pushNamed(AppRouter.settingsName),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Settings'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppPadding.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.pushNamed(AppRouter.wasteSummaryName),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Weekly waste summary'),
                  ),
                ),
                const SizedBox(height: AppPadding.sm),
                if (upcomingMeals.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppPadding.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Upcoming reminders',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppPadding.sm),
                          ...upcomingMeals.take(2).map((meal) {
                            final recipe = _findRecipeById(
                              recipes,
                              meal.recipeId,
                            );
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.notifications_none),
                              title: Text(recipe?.title ?? 'Planned meal'),
                              subtitle: Text(
                                '${meal.slot} on ${meal.date.toLocal().toString().split(' ').first}',
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                Card(
                  child: ListTile(
                    title: const Text('This week plan progress'),
                    subtitle: Text(
                      '${plannerState.meals.length} meals planned',
                    ),
                    leading: const Icon(Icons.calendar_month),
                  ),
                ),
                const SizedBox(height: AppPadding.sm),
                Card(
                  child: ListTile(
                    title: const Text('Use soon ingredients'),
                    subtitle: Text(
                      '${pantryState.useSoonItems.length} items expiring in 3 days',
                    ),
                    leading: const Icon(Icons.warning_amber_outlined),
                  ),
                ),
                const SizedBox(height: AppPadding.sm),
                Text('Use Soon Queue', style: textTheme.headlineSmall),
                const SizedBox(height: AppPadding.sm),
                if (pantryState.useSoonItems.isEmpty)
                  const Text('No urgent items right now.')
                else
                  ...pantryState.useSoonItems.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.quantity} ${item.unit} - ${item.storageLocation}',
                        ),
                        trailing: Text('D-${item.daysUntilExpiry}'),
                      ),
                    ),
                  ),
                const SizedBox(height: AppPadding.md),
                Text('Use Soon Meal Ideas', style: textTheme.headlineSmall),
                const SizedBox(height: AppPadding.sm),
                if (useSoonIdeas.isEmpty)
                  const Text(
                    'Add more pantry items to get expiry-aware meal ideas.',
                  )
                else
                  ...useSoonIdeas.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(item.recipe.title),
                        subtitle: Text(
                          'Use soon: ${item.useSoonIngredients.join(', ')} • ${item.pantryCoverage}% pantry match',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.pushNamed(
                          AppRouter.recipeDetailName,
                          pathParameters: <String, String>{
                            AppRouter.recipeIdParam: item.recipe.id,
                          },
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppPadding.md),
                Text('Leftover Ideas', style: textTheme.headlineSmall),
                const SizedBox(height: AppPadding.sm),
                if (leftoverIdeas.isEmpty)
                  const Text(
                    'Plan a few meals to unlock leftover reuse suggestions.',
                  )
                else
                  ...leftoverIdeas.map(
                    (idea) => Card(
                      child: ListTile(
                        title: Text(idea.recipe.title),
                        subtitle: Text(idea.reason),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.pushNamed(
                          AppRouter.recipeDetailName,
                          pathParameters: <String, String>{
                            AppRouter.recipeIdParam: idea.recipe.id,
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
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
