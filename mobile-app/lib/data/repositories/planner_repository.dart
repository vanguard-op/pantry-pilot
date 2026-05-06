import 'dart:async';

import '../api/api_client.dart';
import '../models/planned_meal.dart';

class PlannerRepository {
  PlannerRepository(this._apiClient);

  final ApiClient _apiClient;
  final StreamController<List<PlannedMeal>> _controller =
      StreamController<List<PlannedMeal>>.broadcast();
  List<PlannedMeal> _meals = const <PlannedMeal>[];
  bool _loading = false;
  bool _initialized = false;

  Future<void> initialize() => _refresh();

  List<PlannedMeal> getAll() =>
      _meals.toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));

  Stream<List<PlannedMeal>> watchAll() async* {
    if (!_initialized && !_loading) {
      unawaited(_refresh());
    }
    yield getAll();
    yield* _controller.stream;
  }

  Future<void> addMeal(PlannedMeal meal) async {
    final normalizedMeal = PlannedMeal(
      id: meal.id,
      recipeId: meal.recipeId,
      date: DateTime(meal.date.year, meal.date.month, meal.date.day),
      slot: meal.slot.trim().isEmpty ? 'Dinner' : meal.slot.trim(),
    );

    await _ensureLoaded();
    final exists = _meals.any((entry) => entry.id == normalizedMeal.id);
    if (exists) {
      await _apiClient.patchObject(
        '/api/v1/planner/${normalizedMeal.id}',
        body: normalizedMeal.toMap(),
      );
    } else {
      await _apiClient.postObject(
        '/api/v1/planner',
        body: normalizedMeal.toMap(),
      );
    }
    await _refresh();
  }

  Future<void> deleteMeal(String id) async {
    await _apiClient.delete('/api/v1/planner/$id');
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
      final rawMeals = await _apiClient.getList('/api/v1/planner');
      _meals = rawMeals
          .whereType<Map>()
          .map((meal) => PlannedMeal.fromMap(meal.cast<String, dynamic>()))
          .toList(growable: false)
        ..sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          if (dateCompare != 0) {
            return dateCompare;
          }
          return a.slot.compareTo(b.slot);
        });
      _initialized = true;
      _controller.add(getAll());
    } finally {
      _loading = false;
    }
  }
}
