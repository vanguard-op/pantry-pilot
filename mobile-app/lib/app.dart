import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/onboarding/onboarding_bloc.dart';
import 'blocs/pantry/pantry_bloc.dart';
import 'blocs/planner/planner_bloc.dart';
import 'blocs/recipes/recipes_bloc.dart';
import 'data/repositories/pantry_repository.dart';
import 'data/repositories/planner_repository.dart';
import 'data/repositories/recipe_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

class PantryPilotApp extends StatelessWidget {
  const PantryPilotApp({
    super.key,
    required this.settingsRepository,
    required this.pantryRepository,
    required this.plannerRepository,
    required this.recipeRepository,
  });

  final SettingsRepository settingsRepository;
  final PantryRepository pantryRepository;
  final PlannerRepository plannerRepository;
  final RecipeRepository recipeRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<SettingsRepository>.value(value: settingsRepository),
        RepositoryProvider<PantryRepository>.value(value: pantryRepository),
        RepositoryProvider<PlannerRepository>.value(value: plannerRepository),
        RepositoryProvider<RecipeRepository>.value(value: recipeRepository),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<OnboardingBloc>(
            create: (context) => OnboardingBloc(
              settingsRepository: context.read<SettingsRepository>(),
              pantryRepository: context.read<PantryRepository>(),
            )..add(const OnboardingStarted()),
          ),
          BlocProvider<PantryBloc>(
            create: (context) =>
                PantryBloc(pantryRepository: context.read<PantryRepository>())
                  ..add(const PantryStarted()),
          ),
          BlocProvider<PlannerBloc>(
            create: (context) => PlannerBloc(
              plannerRepository: context.read<PlannerRepository>(),
            )..add(const PlannerStarted()),
          ),
          BlocProvider<RecipesBloc>(
            create: (context) =>
                RecipesBloc(recipeRepository: context.read<RecipeRepository>())
                  ..add(const RecipesStarted()),
          ),
        ],
        child: BlocBuilder<OnboardingBloc, OnboardingState>(
          builder: (context, state) {
            return MaterialApp.router(
              title: 'PantryPilot',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.system,
              routerConfig: AppRouter.createRouter(
                onboardingComplete: state.completed,
              ),
            );
          },
        ),
      ),
    );
  }
}
