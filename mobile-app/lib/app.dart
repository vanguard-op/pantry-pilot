import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/onboarding/onboarding_bloc.dart';
import 'blocs/pantry/pantry_bloc.dart';
import 'blocs/planner/planner_bloc.dart';
import 'blocs/recipes/recipes_bloc.dart';
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
    required this.settingsRepository,
    required this.pantryRepository,
    required this.plannerRepository,
    required this.recipeRepository,
    required this.feedbackRepository,
    required this.recommendationRepository,
    required this.shoppingRepository,
    required this.notificationService,
  });

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
        child: BlocListener<PantryBloc, PantryState>(
          listener: (context, pantryState) {
            final settings = context.read<SettingsRepository>();
            context.read<NotificationService>().syncReminders(
              pantryItems: pantryState.items,
              plannedMeals: context.read<PlannerBloc>().state.meals,
              recipes: context.read<RecipesBloc>().state.recipes,
              expiryThresholdDays: settings.expiryThresholdDays,
              expiryAlertsEnabled: settings.expiryNotificationsEnabled,
              mealRemindersEnabled: settings.mealReminderNotificationsEnabled,
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
                mealRemindersEnabled: settings.mealReminderNotificationsEnabled,
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
                title: 'PantryPilot',
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
    );
  }
}
