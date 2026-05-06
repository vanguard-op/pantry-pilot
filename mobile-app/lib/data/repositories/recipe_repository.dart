import 'dart:async';

import '../api/api_client.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';
import '../seed/recipe_seed_data.dart';

class RecipeRepository {
  RecipeRepository(this._apiClient);

  final ApiClient _apiClient;
  final StreamController<List<Recipe>> _controller =
      StreamController<List<Recipe>>.broadcast();
  List<Recipe> _recipes = const <Recipe>[];
  bool _loading = false;
  bool _initialized = false;

  Future<void> initialize() => _refresh();

  Future<void> seedIfNeeded() async {
    await _ensureLoaded();
    if (_recipes.isEmpty) {
      final seeded = generateStarterRecipes();
      for (final recipe in seeded) {
        await _apiClient.postObject(
          '/api/v1/recipes',
          body: _serializeRecipe(recipe),
        );
      }
      await _refresh();
    }
  }

  List<Recipe> getAll() => List<Recipe>.unmodifiable(_recipes);

  Recipe? byId(String id) {
    for (final recipe in _recipes) {
      if (recipe.id == id) {
        return recipe;
      }
    }
    return null;
  }

  Stream<List<Recipe>> watchAll() async* {
    if (!_initialized && !_loading) {
      unawaited(_refresh());
    }
    yield getAll();
    yield* _controller.stream;
  }

  Future<void> toggleFavorite(String id) async {
    await _apiClient.postObject('/api/v1/recipes/$id/favorite', body: const {});
    await _refresh();
  }

  Future<void> _ensureLoaded() async {
    if (_initialized) {
      return;
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) {
      return;
    }

    _loading = true;
    try {
      final rawRecipes = await _apiClient.getList('/api/v1/recipes');
      _recipes = rawRecipes
          .whereType<Map>()
          .map((recipe) => _deserialize(recipe.cast<String, dynamic>()))
          .toList(growable: false);
      _initialized = true;
      _controller.add(getAll());
    } finally {
      _loading = false;
    }
  }

  Map<String, dynamic> _serializeRecipe(Recipe recipe) {
    return <String, dynamic>{
      'title': recipe.title,
      'description': recipe.description,
      'prep_minutes': recipe.prepMinutes,
      'cook_minutes': recipe.cookMinutes,
      'servings': recipe.servings,
      'difficulty': recipe.difficulty,
      'tags': recipe.tags,
      'ingredients': recipe.ingredients,
      'steps': recipe.steps.map(_serializeStep).toList(growable: false),
      'is_favorite': recipe.isFavorite,
    };
  }

  Map<String, dynamic> _serializeStep(RecipeStep step) {
    return <String, dynamic>{
      'description': step.description,
      'duration_minutes': step.durationMinutes,
      'ingredient_mentions': step.ingredientMentions,
    };
  }

  Recipe _deserialize(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((step) => step.cast<String, dynamic>())
        .toList(growable: false);

    return Recipe(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled recipe',
      description: json['description'] as String? ?? '',
      prepMinutes: (json['prep_minutes'] as num?)?.toInt() ?? 0,
      cookMinutes: (json['cook_minutes'] as num?)?.toInt() ?? 0,
      servings: (json['servings'] as num?)?.toInt() ?? 1,
      difficulty: json['difficulty'] as String? ?? 'Beginner',
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      ingredients: (json['ingredients'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      steps: rawSteps.map(_deserializeStep).toList(growable: false),
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  RecipeStep _deserializeStep(Map<String, dynamic> json) {
    return RecipeStep(
      description: json['description'] as String? ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      ingredientMentions:
          (json['ingredient_mentions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
    );
  }
}
