import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/auth/auth_bloc.dart';
import 'blocs/onboarding/onboarding_bloc.dart';
import 'blocs/pantry/pantry_bloc.dart';
import 'blocs/planner/planner_bloc.dart';
import 'blocs/recipes/recipes_bloc.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/pantry_repository.dart';
import 'data/repositories/planner_repository.dart';
import 'data/repositories/recipe_repository.dart';
import 'data/repositories/feedback_repository.dart';
import 'data/repositories/recommendation_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/shopping_repository.dart';
import 'navigation/app_router.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

class PantryPilotApp extends StatelessWidget {
  const PantryPilotApp({
    super.key,
    required this.authRepository,
    required this.settingsRepository,
    required this.pantryRepository,
    required this.plannerRepository,
    required this.recipeRepository,
    required this.feedbackRepository,
    required this.recommendationRepository,
    required this.shoppingRepository,
    required this.notificationService,
  });

  final AuthRepository authRepository;
  final SettingsRepository settingsRepository;
  final PantryRepository pantryRepository;
  final PlannerRepository plannerRepository;
  final RecipeRepository recipeRepository;
  final FeedbackRepository feedbackRepository;
  final RecommendationRepository recommendationRepository;
  final ShoppingRepository shoppingRepository;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<SettingsRepository>.value(value: settingsRepository),
        RepositoryProvider<PantryRepository>.value(value: pantryRepository),
        RepositoryProvider<PlannerRepository>.value(value: plannerRepository),
        RepositoryProvider<RecipeRepository>.value(value: recipeRepository),
        RepositoryProvider<FeedbackRepository>.value(value: feedbackRepository),
        RepositoryProvider<RecommendationRepository>.value(
          value: recommendationRepository,
        ),
        RepositoryProvider<ShoppingRepository>.value(value: shoppingRepository),
        RepositoryProvider<NotificationService>.value(
          value: notificationService,
        ),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthBloc>(
            create: (context) =>
                AuthBloc(authRepository: context.read<AuthRepository>())
                  ..add(const AuthCheckRequested()),
          ),
          BlocProvider<OnboardingBloc>(
            create: (context) => OnboardingBloc(
              settingsRepository: context.read<SettingsRepository>(),
              pantryRepository: context.read<PantryRepository>(),
            )..add(const OnboardingStarted()),
          ),
          BlocProvider<PantryBloc>(
            create: (context) =>
                PantryBloc(pantryRepository: context.read<PantryRepository>()),
          ),
          BlocProvider<PlannerBloc>(
            create: (context) => PlannerBloc(
              plannerRepository: context.read<PlannerRepository>(),
            ),
          ),
          BlocProvider<RecipesBloc>(
            create: (context) =>
                RecipesBloc(recipeRepository: context.read<RecipeRepository>()),
          ),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) {
            return previous.status != current.status;
          },
          listener: (context, state) {
            if (state.isAuthenticated) {
              context.read<PantryBloc>().add(const PantryStarted());
              context.read<PlannerBloc>().add(const PlannerStarted());
              context.read<RecipesBloc>().add(const RecipesStarted());
            }

            // Re-run GoRouter redirect immediately on auth changes.
            AppRouter.appRouter.refresh();
          },
          child: BlocListener<OnboardingBloc, OnboardingState>(
            listenWhen: (previous, current) {
              return previous.completed != current.completed;
            },
            listener: (context, state) {
              // Re-run GoRouter redirect immediately when onboarding state flips.
              AppRouter.appRouter.refresh();
            },
            child: BlocListener<PantryBloc, PantryState>(
              listener: (context, pantryState) {
                final settings = context.read<SettingsRepository>();
                context.read<NotificationService>().syncReminders(
                  pantryItems: pantryState.items,
                  plannedMeals: context.read<PlannerBloc>().state.meals,
                  recipes: context.read<RecipesBloc>().state.recipes,
                  expiryThresholdDays: settings.expiryThresholdDays,
                  expiryAlertsEnabled: settings.expiryNotificationsEnabled,
                  mealRemindersEnabled:
                      settings.mealReminderNotificationsEnabled,
                );
              },
              child: BlocListener<PlannerBloc, PlannerState>(
                listenWhen: (previous, current) {
                  return previous.meals.length != current.meals.length;
                },
                listener: (context, plannerState) {
                  final settings = context.read<SettingsRepository>();
                  context.read<NotificationService>().syncReminders(
                    pantryItems: context.read<PantryBloc>().state.items,
                    plannedMeals: plannerState.meals,
                    recipes: context.read<RecipesBloc>().state.recipes,
                    expiryThresholdDays: settings.expiryThresholdDays,
                    expiryAlertsEnabled: settings.expiryNotificationsEnabled,
                    mealRemindersEnabled:
                        settings.mealReminderNotificationsEnabled,
                  );

                  if (plannerState.meals.isNotEmpty) {
                    context
                        .read<SettingsRepository>()
                        .setFirstPlanCreatedAtIfAbsent(DateTime.now());
                  }
                },
                child: BlocListener<RecipesBloc, RecipesState>(
                  listener: (context, recipesState) {
                    final settings = context.read<SettingsRepository>();
                    context.read<NotificationService>().syncReminders(
                      pantryItems: context.read<PantryBloc>().state.items,
                      plannedMeals: context.read<PlannerBloc>().state.meals,
                      recipes: recipesState.recipes,
                      expiryThresholdDays: settings.expiryThresholdDays,
                      expiryAlertsEnabled: settings.expiryNotificationsEnabled,
                      mealRemindersEnabled:
                          settings.mealReminderNotificationsEnabled,
                    );
                  },
                  child: MaterialApp.router(
                    title: 'Pantry Pilot',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.lightTheme,
                    darkTheme: AppTheme.darkTheme,
                    themeMode: ThemeMode.system,
                    routerConfig: AppRouter.appRouter,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
