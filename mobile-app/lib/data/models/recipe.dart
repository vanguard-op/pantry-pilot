import 'package:hive/hive.dart';

import 'recipe_step.dart';

class Recipe extends HiveObject {
  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.servings,
    required this.difficulty,
    required this.tags,
    required this.ingredients,
    required this.steps,
    required this.isFavorite,
  });

  final String id;

  final String title;

  final String description;

  final int prepMinutes;

  final int cookMinutes;

  final int servings;

  final String difficulty;

  final List<String> tags;

  final List<String> ingredients;

  final List<RecipeStep> steps;

  final bool isFavorite;

  int get totalMinutes => prepMinutes + cookMinutes;

  Recipe copyWith({bool? isFavorite}) {
    return Recipe(
      id: id,
      title: title,
      description: description,
      prepMinutes: prepMinutes,
      cookMinutes: cookMinutes,
      servings: servings,
      difficulty: difficulty,
      tags: tags,
      ingredients: ingredients,
      steps: steps,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
