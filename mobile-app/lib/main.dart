import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app.dart';
import 'data/api/api_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/pantry_repository.dart';
import 'data/repositories/planner_repository.dart';
import 'data/repositories/recipe_repository.dart';
import 'data/repositories/feedback_repository.dart';
import 'data/repositories/recommendation_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/shopping_repository.dart';
import 'services/notification_service.dart';

bool _isStartupUnauthorized(Object error) {
  if (error is! ApiException) {
    return false;
  }
  return error.message.startsWith('Unauthorized (');
}

Future<void> _runInitializer(String name, Future<void> Function() run) async {
  try {
    await run();
  } catch (error, stackTrace) {
    if (_isStartupUnauthorized(error)) {
      debugPrint('Startup preload skipped for $name: $error');
      return;
    }

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'pantry_pilot.main',
        context: ErrorDescription('while initializing $name'),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authRepository = AuthRepository();
  await authRepository.initialize();
  final apiClient = await ApiClient.create(
    tokenProvider: authRepository.getAccessToken,
  );
  final settingsRepository = SettingsRepository(apiClient);
  final pantryRepository = PantryRepository(apiClient);
  final plannerRepository = PlannerRepository(apiClient);
  final recipeRepository = RecipeRepository(apiClient);
  final feedbackRepository = FeedbackRepository(apiClient);
  final recommendationRepository = RecommendationRepository(apiClient);
  final shoppingRepository = ShoppingRepository(apiClient);
  final notificationService = NotificationService(
    FlutterLocalNotificationsPlugin(),
  );

  await Future.wait(<Future<void>>[
    _runInitializer('settingsRepository', settingsRepository.initialize),
    _runInitializer('pantryRepository', pantryRepository.initialize),
    _runInitializer('plannerRepository', plannerRepository.initialize),
    _runInitializer('recipeRepository', recipeRepository.initialize),
    _runInitializer('feedbackRepository', feedbackRepository.initialize),
    _runInitializer('notificationService', notificationService.initialize),
  ]);

  runApp(
    PantryPilotApp(
      authRepository: authRepository,
      settingsRepository: settingsRepository,
      pantryRepository: pantryRepository,
      plannerRepository: plannerRepository,
      recipeRepository: recipeRepository,
      feedbackRepository: feedbackRepository,
      recommendationRepository: recommendationRepository,
      shoppingRepository: shoppingRepository,
      notificationService: notificationService,
    ),
  );
}
