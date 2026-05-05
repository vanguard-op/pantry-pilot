import 'dart:async';

import 'package:hive/hive.dart';

import '../models/planned_meal.dart';

class PlannerRepository {
  PlannerRepository(this._box);

  final Box<PlannedMeal> _box;

  List<PlannedMeal> getAll() =>
      _box.values.toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));

  Stream<List<PlannedMeal>> watchAll() async* {
    yield getAll();
    yield* _box.watch().map((_) => getAll());
  }

  Future<void> addMeal(PlannedMeal meal) async {
    final normalizedMeal = PlannedMeal(
      id: meal.id,
      recipeId: meal.recipeId,
      date: DateTime(meal.date.year, meal.date.month, meal.date.day),
      slot: meal.slot.trim(),
    );

    final duplicateIds = _box.values
        .where(
          (existing) =>
              _isSameDay(existing.date, normalizedMeal.date) &&
              existing.slot.toLowerCase() == normalizedMeal.slot.toLowerCase(),
        )
        .map((existing) => existing.id)
        .where((id) => id != normalizedMeal.id)
        .toList(growable: false);

    if (duplicateIds.isNotEmpty) {
      await _box.deleteAll(duplicateIds);
    }

    await _box.put(normalizedMeal.id, normalizedMeal);
  }

  Future<void> deleteMeal(String id) async {
    await _box.delete(id);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
