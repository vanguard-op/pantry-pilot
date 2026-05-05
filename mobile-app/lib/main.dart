import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/models/hive_adapters.dart';
import 'data/models/pantry_item.dart';
import 'data/models/planned_meal.dart';
import 'data/models/recipe.dart';
import 'data/repositories/pantry_repository.dart';
import 'data/repositories/planner_repository.dart';
import 'data/repositories/recipe_repository.dart';
import 'data/repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(PantryItemAdapter());
  Hive.registerAdapter(RecipeStepAdapter());
  Hive.registerAdapter(RecipeAdapter());
  Hive.registerAdapter(PlannedMealAdapter());

  final settingsBox = await Hive.openBox<dynamic>('settings');
  final pantryBox = await Hive.openBox<PantryItem>('pantry_items');
  final recipesBox = await Hive.openBox<Recipe>('recipes');
  final plannerBox = await Hive.openBox<PlannedMeal>('planner');

  runApp(
    PantryPilotApp(
      settingsRepository: SettingsRepository(settingsBox),
      pantryRepository: PantryRepository(pantryBox),
      plannerRepository: PlannerRepository(plannerBox),
      recipeRepository: RecipeRepository(recipesBox),
    ),
  );
}
