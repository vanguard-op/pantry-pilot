import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pantry_pilot/blocs/onboarding/onboarding_bloc.dart';

import '../blocs/recipes/recipes_bloc.dart';
import '../data/models/recipe.dart';
import '../ui/screens/guided_cooking_screen.dart';
import '../ui/screens/home_shell.dart';
import '../ui/screens/onboarding_screen.dart';
import '../ui/screens/pantry_screen.dart';
import '../ui/screens/planner_screen.dart';
import '../ui/screens/recipe_detail_screen.dart';
import '../ui/screens/recipes_screen.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/feedback_screen.dart';
import '../ui/screens/kpi_dashboard_screen.dart';

class AppRouter {
  static const onboardingName = 'onboarding';
  static const homeName = 'home';
  static const pantryName = 'pantry';
  static const plannerName = 'planner';
  static const recipesName = 'recipes';
  static const recipeDetailName = 'recipe-detail';
  static const recipeCookName = 'recipe-cook';
  static const feedbackName = 'feedback';
  static const kpiName = 'kpi-dashboard';

  static const onboardingPath = '/onboarding';
  static const homePath = '/home';
  static const pantryPath = '/pantry';
  static const plannerPath = '/planner';
  static const recipesPath = '/recipes';
  static const feedbackPath = '/feedback';
  static const kpiPath = '/kpi';

  static const recipeIdParam = 'recipeId';
  static const _recipeDetailSegment = ':$recipeIdParam';
  static const _recipeCookSegment = 'cook';

  static final appRouter = GoRouter(
    initialLocation: AppRouter.homePath,
    redirect: (context, state) {
      final onboardingComplete = context.read<OnboardingBloc>().state.completed;
      final isOnboardingRoute =
          state.matchedLocation == AppRouter.onboardingPath;
      if (!onboardingComplete && !isOnboardingRoute) {
        return AppRouter.onboardingPath;
      }
      if (onboardingComplete && isOnboardingRoute) {
        return AppRouter.homePath;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        name: AppRouter.onboardingName,
        path: AppRouter.onboardingPath,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        name: AppRouter.feedbackName,
        path: AppRouter.feedbackPath,
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        name: AppRouter.kpiName,
        path: AppRouter.kpiPath,
        builder: (context, state) => const KpiDashboardScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                name: AppRouter.homeName,
                path: AppRouter.homePath,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                name: AppRouter.pantryName,
                path: AppRouter.pantryPath,
                builder: (context, state) => const PantryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                name: AppRouter.plannerName,
                path: AppRouter.plannerPath,
                builder: (context, state) => const PlannerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                name: AppRouter.recipesName,
                path: AppRouter.recipesPath,
                builder: (context, state) => const RecipesScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    name: AppRouter.recipeDetailName,
                    path: AppRouter._recipeDetailSegment,
                    builder: (context, state) => RecipeDetailScreen(
                      recipeId: state.pathParameters[AppRouter.recipeIdParam]!,
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        name: AppRouter.recipeCookName,
                        path: AppRouter._recipeCookSegment,
                        builder: (context, state) {
                          final recipeId =
                              state.pathParameters[AppRouter.recipeIdParam]!;
                          final recipe = _findRecipe(
                            context.read<RecipesBloc>().state.recipes,
                            recipeId,
                          );
                          if (recipe == null) {
                            return const _RouteErrorScreen(
                              title: 'Recipe unavailable',
                              message:
                                  'This recipe could not be loaded for cooking.',
                            );
                          }
                          return GuidedCookingScreen(recipe: recipe);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Recipe? _findRecipe(List<Recipe> recipes, String recipeId) {
  for (final recipe in recipes) {
    if (recipe.id == recipeId) {
      return recipe;
    }
  }
  return null;
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
