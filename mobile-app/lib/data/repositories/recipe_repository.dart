import 'dart:async';

import 'package:hive/hive.dart';

import '../models/recipe.dart';
import '../seed/recipe_seed_data.dart';

class RecipeRepository {
  RecipeRepository(this._box);

  final Box<Recipe> _box;

  Future<void> seedIfNeeded() async {
    if (_box.isEmpty) {
      final seeded = generateStarterRecipes();
      final map = <String, Recipe>{
        for (final recipe in seeded) recipe.id: recipe,
      };
      await _box.putAll(map);
    }
  }

  List<Recipe> getAll() => _box.values.toList(growable: false);

  Recipe? byId(String id) => _box.get(id);

  Stream<List<Recipe>> watchAll() async* {
    yield getAll();
    yield* _box.watch().map((_) => getAll());
  }

  Future<void> toggleFavorite(String id) async {
    final recipe = _box.get(id);
    if (recipe == null) {
      return;
    }
    await _box.put(id, recipe.copyWith(isFavorite: !recipe.isFavorite));
  }
}
