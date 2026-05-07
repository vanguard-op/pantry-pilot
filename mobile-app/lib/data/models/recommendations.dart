import 'recipe.dart';

class RecipeRecommendation {
  const RecipeRecommendation({
    required this.recipe,
    required this.score,
    required this.pantryCoverage,
    required this.matchingIngredients,
    required this.useSoonIngredients,
    required this.recentPlanCount,
  });

  final Recipe recipe;
  final int score;
  final int pantryCoverage;
  final List<String> matchingIngredients;
  final List<String> useSoonIngredients;
  final int recentPlanCount;

  factory RecipeRecommendation.fromMap(Map<String, dynamic> map) {
    final recipeMap =
        (map['recipe'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return RecipeRecommendation(
      recipe: Recipe.fromMap(recipeMap),
      score: (map['score'] as num?)?.toInt() ?? 0,
      pantryCoverage: (map['pantry_coverage'] as num?)?.toInt() ?? 0,
      matchingIngredients:
          (map['matching_ingredients'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      useSoonIngredients:
          (map['use_soon_ingredients'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      recentPlanCount: (map['recent_plan_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeftoverSuggestion {
  const LeftoverSuggestion({
    required this.recipe,
    required this.sourceRecipeTitle,
    required this.sharedIngredients,
    required this.reason,
  });

  final Recipe recipe;
  final String sourceRecipeTitle;
  final List<String> sharedIngredients;
  final String reason;

  factory LeftoverSuggestion.fromMap(Map<String, dynamic> map) {
    final recipeMap =
        (map['recipe'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return LeftoverSuggestion(
      recipe: Recipe.fromMap(recipeMap),
      sourceRecipeTitle: map['source_recipe_title'] as String? ?? '',
      sharedIngredients:
          (map['shared_ingredients'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      reason: map['reason'] as String? ?? '',
    );
  }
}

class PlannerRecommendations {
  const PlannerRecommendations({
    required this.ranked,
    required this.favorites,
    required this.repeats,
  });

  final List<RecipeRecommendation> ranked;
  final List<Recipe> favorites;
  final List<Recipe> repeats;

  factory PlannerRecommendations.fromMap(Map<String, dynamic> map) {
    final ranked = (map['ranked'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) => RecipeRecommendation.fromMap(item.cast<String, dynamic>()),
        )
        .toList(growable: false);

    final favorites = (map['favorites'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Recipe.fromMap(item.cast<String, dynamic>()))
        .toList(growable: false);

    final repeats = (map['repeats'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Recipe.fromMap(item.cast<String, dynamic>()))
        .toList(growable: false);

    return PlannerRecommendations(
      ranked: ranked,
      favorites: favorites,
      repeats: repeats,
    );
  }

  static const empty = PlannerRecommendations(
    ranked: <RecipeRecommendation>[],
    favorites: <Recipe>[],
    repeats: <Recipe>[],
  );
}

class DashboardRecommendations {
  const DashboardRecommendations({
    required this.useSoon,
    required this.leftovers,
  });

  final List<RecipeRecommendation> useSoon;
  final List<LeftoverSuggestion> leftovers;

  factory DashboardRecommendations.fromMap(Map<String, dynamic> map) {
    final useSoon = (map['use_soon'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) => RecipeRecommendation.fromMap(item.cast<String, dynamic>()),
        )
        .toList(growable: false);

    final leftovers = (map['leftovers'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => LeftoverSuggestion.fromMap(item.cast<String, dynamic>()))
        .toList(growable: false);

    return DashboardRecommendations(useSoon: useSoon, leftovers: leftovers);
  }

  static const empty = DashboardRecommendations(
    useSoon: <RecipeRecommendation>[],
    leftovers: <LeftoverSuggestion>[],
  );
}

/// A pantry item that can serve as a substitute for a missing ingredient.
class PantrySubstituteOption {
  const PantrySubstituteOption({
    required this.pantryItemName,
    required this.reason,
  });

  /// The display name of the pantry item that can be used as a substitute.
  final String pantryItemName;

  /// Human-readable explanation of why this item is a suitable substitute.
  final String reason;

  factory PantrySubstituteOption.fromMap(Map<String, dynamic> map) {
    return PantrySubstituteOption(
      pantryItemName: map['pantry_item_name'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
    );
  }
}

/// A single ingredient substitution hint, optionally pantry-aware.
class SubstitutionHint {
  const SubstitutionHint({
    required this.ingredient,
    required this.hint,
    this.pantrySubstitutes = const <PantrySubstituteOption>[],
  });

  final String ingredient;
  final String hint;

  /// Pantry items already in stock that are known substitutes for [ingredient].
  /// Empty when the user's pantry has no matching alternatives.
  final List<PantrySubstituteOption> pantrySubstitutes;

  factory SubstitutionHint.fromMap(Map<String, dynamic> map) {
    return SubstitutionHint(
      ingredient: map['ingredient'] as String? ?? '',
      hint: map['hint'] as String? ?? '',
      pantrySubstitutes:
          (map['pantry_substitutes'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => PantrySubstituteOption.fromMap(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false),
    );
  }
}

/// Pantry coverage for a single recipe, as computed by the backend.
class PantryCoverage {
  const PantryCoverage({
    required this.recipeId,
    required this.coveragePercent,
    required this.matchedCount,
    required this.totalCount,
    required this.missingIngredients,
    required this.availableIngredients,
  });

  final String recipeId;
  final int coveragePercent;
  final int matchedCount;
  final int totalCount;
  final List<String> missingIngredients;
  final List<String> availableIngredients;

  factory PantryCoverage.fromMap(Map<String, dynamic> map) {
    return PantryCoverage(
      recipeId: map['recipe_id'] as String? ?? '',
      coveragePercent: (map['coverage_percent'] as num?)?.toInt() ?? 0,
      matchedCount: (map['matched_count'] as num?)?.toInt() ?? 0,
      totalCount: (map['total_count'] as num?)?.toInt() ?? 0,
      missingIngredients:
          (map['missing_ingredients'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      availableIngredients:
          (map['available_ingredients'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
    );
  }
}
