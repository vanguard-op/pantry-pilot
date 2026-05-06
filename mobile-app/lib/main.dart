import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app.dart';
import 'data/api/api_client.dart';
import 'data/repositories/pantry_repository.dart';
import 'data/repositories/planner_repository.dart';
import 'data/repositories/recipe_repository.dart';
import 'data/repositories/feedback_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = await ApiClient.create();
  final settingsRepository = SettingsRepository(apiClient);
  final pantryRepository = PantryRepository(apiClient);
  final plannerRepository = PlannerRepository(apiClient);
  final recipeRepository = RecipeRepository(apiClient);
  final feedbackRepository = FeedbackRepository(apiClient);
  final notificationService = NotificationService(
    FlutterLocalNotificationsPlugin(),
  );

  await Future.wait(<Future<void>>[
    settingsRepository.initialize(),
    pantryRepository.initialize(),
    plannerRepository.initialize(),
    recipeRepository.initialize(),
    feedbackRepository.initialize(),
    notificationService.initialize(),
  ]);

  runApp(
    PantryPilotApp(
      settingsRepository: settingsRepository,
      pantryRepository: pantryRepository,
      plannerRepository: plannerRepository,
      recipeRepository: recipeRepository,
      feedbackRepository: feedbackRepository,
      notificationService: notificationService,
    ),
  );
}
