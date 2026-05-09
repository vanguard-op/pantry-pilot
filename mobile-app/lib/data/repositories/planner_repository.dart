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
      _meals.toList(growable: false)..sort((a, b) => a.date.compareTo(b.date));

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
    final existingMeal = _meals
        .where((entry) => entry.id == normalizedMeal.id)
        .firstOrNull;
    final responseMap = existingMeal != null
        ? await _apiClient.patchObject(
            '/api/v1/planner/${normalizedMeal.id}',
            body: _buildPatchBody(existingMeal, normalizedMeal),
          )
        : await _apiClient.postObject(
            '/api/v1/planner',
            body: normalizedMeal.toMap(),
          );
    final saved = PlannedMeal.fromMap(responseMap);

    _meals = <PlannedMeal>[
      ..._meals.where((entry) => entry.id != saved.id),
      saved,
    ];
    _emit();
  }

  Future<void> deleteMeal(String id) async {
    await _ensureLoaded();
    await _apiClient.delete('/api/v1/planner/$id');
    _meals = _meals.where((entry) => entry.id != id).toList(growable: false);
    _emit();
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
          .toList(growable: false);
      _initialized = true;
      _emit();
    } finally {
      _loading = false;
    }
  }

  void _emit() {
    _meals = _meals.toList(growable: false)
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.slot.compareTo(b.slot);
      });
    _controller.add(getAll());
  }

  Map<String, dynamic> _buildPatchBody(
    PlannedMeal existingMeal,
    PlannedMeal updatedMeal,
  ) {
    final body = <String, dynamic>{};
    if (existingMeal.recipeId != updatedMeal.recipeId) {
      body['recipe_id'] = updatedMeal.recipeId;
    }
    if (!_isSameCalendarDay(existingMeal.date, updatedMeal.date)) {
      body['date'] = _serializeDate(updatedMeal.date);
    }
    if (existingMeal.slot != updatedMeal.slot) {
      body['slot'] = updatedMeal.slot;
    }
    return body;
  }

  bool _isSameCalendarDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _serializeDate(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).toIso8601String().split('T').first;
  }
}
