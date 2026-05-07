import 'recipe_step.dart';

enum RecipeOwnershipScope { global, custom }

class Recipe {
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
    required this.ownershipScope,
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

  final RecipeOwnershipScope ownershipScope;

  factory Recipe.fromMap(Map<String, dynamic> map) {
    final rawSteps = (map['steps'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((step) => step.cast<String, dynamic>())
        .toList(growable: false);

    return Recipe(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled recipe',
      description: map['description'] as String? ?? '',
      prepMinutes: (map['prep_minutes'] as num?)?.toInt() ?? 0,
      cookMinutes: (map['cook_minutes'] as num?)?.toInt() ?? 0,
      servings: (map['servings'] as num?)?.toInt() ?? 1,
      difficulty: map['difficulty'] as String? ?? 'Beginner',
      tags: (map['tags'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      ingredients: (map['ingredients'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      steps: rawSteps.map(RecipeStep.fromMap).toList(growable: false),
      isFavorite: map['is_favorite'] as bool? ?? false,
      ownershipScope: _ownershipScopeFromApi(map['ownership_scope'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'prep_minutes': prepMinutes,
      'cook_minutes': cookMinutes,
      'servings': servings,
      'difficulty': difficulty,
      'tags': tags,
      'ingredients': ingredients,
      'steps': steps.map((step) => step.toMap()).toList(growable: false),
      'is_favorite': isFavorite,
    };
  }

  int get totalMinutes => prepMinutes + cookMinutes;

  bool get isGlobal => ownershipScope == RecipeOwnershipScope.global;

  String get ownershipLabel => isGlobal ? 'Global' : 'Owned';

  Recipe copyWith({bool? isFavorite, RecipeOwnershipScope? ownershipScope}) {
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
      ownershipScope: ownershipScope ?? this.ownershipScope,
    );
  }

  static RecipeOwnershipScope _ownershipScopeFromApi(String? value) {
    switch (value) {
      case 'global':
        return RecipeOwnershipScope.global;
      case 'custom':
        return RecipeOwnershipScope.custom;
      default:
        return RecipeOwnershipScope.custom;
    }
  }
}
