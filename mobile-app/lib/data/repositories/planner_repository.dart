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
    await _box.put(meal.id, meal);
  }

  Future<void> deleteMeal(String id) async {
    await _box.delete(id);
  }
}
