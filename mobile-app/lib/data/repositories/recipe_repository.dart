import 'dart:async';

import '../api/api_client.dart';
import '../models/recipe.dart';

class RecipeRepository {
  RecipeRepository(this._apiClient);

  final ApiClient _apiClient;
  final StreamController<List<Recipe>> _controller =
      StreamController<List<Recipe>>.broadcast();
  List<Recipe> _recipes = const <Recipe>[];
  bool _loading = false;
  bool _initialized = false;

  Future<void> initialize() => _refresh();

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
    await _ensureLoaded();
    final updated = Recipe.fromMap(
      await _apiClient.postObject('/api/v1/recipes/$id/favorite', body: const {}),
    );

    _recipes = <Recipe>[
      ..._recipes.where((recipe) => recipe.id != updated.id),
      updated,
    ];
    _controller.add(getAll());
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
          .map((recipe) => Recipe.fromMap(recipe.cast<String, dynamic>()))
          .toList(growable: false);
      _initialized = true;
      _controller.add(getAll());
    } finally {
      _loading = false;
    }
  }
}
