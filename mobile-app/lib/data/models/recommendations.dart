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

/// Per-ingredient detail from the AI coverage payload.
///
/// Carries the structured data Gemini returns for each recipe ingredient:
/// normalised name, quantities, coverage status, pantry match, optional
/// substitution suggestion, and a confidence score.
class AiIngredientDetail {
  const AiIngredientDetail({
    required this.ingredientText,
    required this.normalizedName,
    required this.requiredQuantity,
    required this.requiredUnit,
    this.availableQuantity = 0,
    this.missingQuantity = 0,
    required this.status,
    this.matchedPantryItem,
    this.substitution,
    this.confidence = 1.0,
  });

  /// The raw ingredient string as it appears in the recipe (e.g. "200g pasta").
  final String ingredientText;

  /// Normalised, lower-cased ingredient name for look-up (e.g. "pasta").
  final String normalizedName;

  /// Quantity required by the recipe for this ingredient.
  final double requiredQuantity;

  /// Unit for [requiredQuantity] (e.g. "g", "pcs", "tbsp").
  final String requiredUnit;

  /// Quantity currently available in the user's pantry.
  final double availableQuantity;

  /// Quantity that is still missing after accounting for pantry stock.
  final double missingQuantity;

  /// Coverage status: "available", "missing", or "substituted".
  final String status;

  /// The pantry item name that matched this ingredient, if available.
  final String? matchedPantryItem;

  /// An AI-suggested substitution, if the ingredient is missing.
  final AiSubstitutionSuggestion? substitution;

  /// Model confidence in this assessment (0.0 – 1.0).
  final double confidence;

  factory AiIngredientDetail.fromMap(Map<String, dynamic> map) {
    final subMap =
        (map['substitution'] as Map?)?.cast<String, dynamic>();
    return AiIngredientDetail(
      ingredientText: map['ingredient_text'] as String? ?? '',
      normalizedName: map['normalized_name'] as String? ?? '',
      requiredQuantity: (map['required_quantity'] as num?)?.toDouble() ?? 1.0,
      requiredUnit: map['required_unit'] as String? ?? 'pcs',
      availableQuantity: (map['available_quantity'] as num?)?.toDouble() ?? 0,
      missingQuantity: (map['missing_quantity'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'missing',
      matchedPantryItem: map['matched_pantry_item'] as String?,
      substitution: subMap != null
          ? AiSubstitutionSuggestion.fromMap(subMap)
          : null,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// A substitution suggestion from the AI coverage payload.
class AiSubstitutionSuggestion {
  const AiSubstitutionSuggestion({
    required this.pantryItemName,
    this.notes = '',
  });

  /// The name of a pantry item that can serve as a substitute.
  final String pantryItemName;

  /// Optional human-readable notes on how to use the substitute.
  final String notes;

  factory AiSubstitutionSuggestion.fromMap(Map<String, dynamic> map) {
    return AiSubstitutionSuggestion(
      pantryItemName: map['pantry_item_name'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }
}

/// Pantry coverage for a single recipe, as computed by the backend.
///
/// Coverage comes from the AI planner endpoint
/// (`GET /api/v1/ai/planner/coverage/{recipe_id}`) which returns per-ingredient
/// detail.  The [availableIngredients] and [missingIngredients] convenience
/// lists are derived from the full AI payload so existing UI code continues
/// to work unchanged.
class PantryCoverage {
  const PantryCoverage({
    required this.recipeId,
    required this.coveragePercent,
    required this.matchedCount,
    required this.totalCount,
    required this.missingIngredients,
    required this.availableIngredients,
    this.ingredientDetails = const <AiIngredientDetail>[],
  });

  final String recipeId;
  final int coveragePercent;
  final int matchedCount;
  final int totalCount;
  final List<String> missingIngredients;
  final List<String> availableIngredients;

  /// Full per-ingredient details from the AI payload.
  ///
  /// Empty when coverage was parsed from the legacy endpoint format.
  final List<AiIngredientDetail> ingredientDetails;

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

  /// Creates [PantryCoverage] from the AI endpoint's inner payload object
  /// (the `payload` field of `AICoverageResponse`).
  factory PantryCoverage.fromAiPayload(Map<String, dynamic> payload) {
    final ingredients =
        (payload['ingredients'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (item) =>
                  AiIngredientDetail.fromMap(item.cast<String, dynamic>()),
            )
            .toList(growable: false);

    return PantryCoverage(
      recipeId: payload['recipe_id'] as String? ?? '',
      coveragePercent: (payload['coverage_percent'] as num?)?.toInt() ?? 0,
      matchedCount: (payload['matched_count'] as num?)?.toInt() ?? 0,
      totalCount: ingredients.length,
      missingIngredients: ingredients
          .where((i) => i.status == 'missing')
          .map((i) => i.normalizedName)
          .toList(growable: false),
      availableIngredients: ingredients
          .where((i) => i.status == 'available')
          .map((i) => i.normalizedName)
          .toList(growable: false),
      ingredientDetails: ingredients,
    );
  }
}
