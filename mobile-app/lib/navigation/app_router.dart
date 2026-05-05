import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

class AppRouter {
  static const onboardingName = 'onboarding';
  static const homeName = 'home';
  static const pantryName = 'pantry';
  static const plannerName = 'planner';
  static const recipesName = 'recipes';
  static const recipeDetailName = 'recipe-detail';
  static const recipeCookName = 'recipe-cook';

  static const onboardingPath = '/onboarding';
  static const homePath = '/home';
  static const pantryPath = '/pantry';
  static const plannerPath = '/planner';
  static const recipesPath = '/recipes';

  static const recipeIdParam = 'recipeId';
  static const _recipeDetailSegment = ':$recipeIdParam';
  static const _recipeCookSegment = 'cook';

  static GoRouter createRouter({required bool onboardingComplete}) {
    return GoRouter(
      initialLocation: onboardingComplete ? homePath : onboardingPath,
      redirect: (context, state) {
        final isOnboardingRoute = state.matchedLocation == onboardingPath;
        if (!onboardingComplete && !isOnboardingRoute) {
          return onboardingPath;
        }
        if (onboardingComplete && isOnboardingRoute) {
          return homePath;
        }
        return null;
      },
      routes: <RouteBase>[
        GoRoute(
          name: onboardingName,
          path: onboardingPath,
          builder: (context, state) => const OnboardingScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return HomeShell(navigationShell: navigationShell);
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  name: homeName,
                  path: homePath,
                  builder: (context, state) => const DashboardScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  name: pantryName,
                  path: pantryPath,
                  builder: (context, state) => const PantryScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  name: plannerName,
                  path: plannerPath,
                  builder: (context, state) => const PlannerScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  name: recipesName,
                  path: recipesPath,
                  builder: (context, state) => const RecipesScreen(),
                  routes: <RouteBase>[
                    GoRoute(
                      name: recipeDetailName,
                      path: _recipeDetailSegment,
                      builder: (context, state) => RecipeDetailScreen(
                        recipeId: state.pathParameters[recipeIdParam]!,
                      ),
                      routes: <RouteBase>[
                        GoRoute(
                          name: recipeCookName,
                          path: _recipeCookSegment,
                          builder: (context, state) {
                            final recipeId = state.pathParameters[recipeIdParam]!;
                            final recipe = _findRecipe(
                              context.read<RecipesBloc>().state.recipes,
                              recipeId,
                            );
                            if (recipe == null) {
                              return const _RouteErrorScreen(
                                title: 'Recipe unavailable',
                                message: 'This recipe could not be loaded for cooking.',
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

  static Recipe? _findRecipe(List<Recipe> recipes, String recipeId) {
    for (final recipe in recipes) {
      if (recipe.id == recipeId) {
        return recipe;
      }
    }
    return null;
  }
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