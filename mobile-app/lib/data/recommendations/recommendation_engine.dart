import '../models/pantry_item.dart';
import '../models/planned_meal.dart';
import '../models/recipe.dart';

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

  bool get isFavorite => recipe.isFavorite;
}

class LeftoverSuggestion {
  const LeftoverSuggestion({
    required this.recipe,
    required this.sourceRecipeTitle,
    required this.sharedIngredients,
  });

  final Recipe recipe;
  final String sourceRecipeTitle;
  final List<String> sharedIngredients;

  String get reason {
    final joined = sharedIngredients.take(2).join(', ');
    return 'Reuse ingredients from $sourceRecipeTitle${joined.isEmpty ? '' : ' with $joined'}';
  }
}

class RecommendationEngine {
  static List<RecipeRecommendation> rankRecipes({
    required List<Recipe> recipes,
    required List<PantryItem> pantryItems,
    required List<PlannedMeal> plannedMeals,
  }) {
    final pantrySet = pantryItems.map((item) => item.name.toLowerCase()).toSet();
    final useSoonSet = pantryItems
        .where((item) => item.daysUntilExpiry <= 3)
        .map((item) => item.name.toLowerCase())
        .toSet();
    final recentCounts = _recentPlanCounts(plannedMeals);

    final ranked = recipes.map((recipe) {
      final matching = recipe.ingredients
          .where((ingredient) => pantrySet.contains(ingredient.toLowerCase()))
          .toList(growable: false);
      final useSoonMatches = recipe.ingredients
          .where((ingredient) => useSoonSet.contains(ingredient.toLowerCase()))
          .toList(growable: false);
      final coverage = recipe.ingredients.isEmpty
          ? 0
          : ((matching.length / recipe.ingredients.length) * 100).round();
      final recentPlanCount = recentCounts[recipe.id] ?? 0;
      final score =
          (coverage * 2) +
          (useSoonMatches.length * 18) +
          (recipe.isFavorite ? 14 : 0) +
          (recentPlanCount * 6);

      return RecipeRecommendation(
        recipe: recipe,
        score: score,
        pantryCoverage: coverage,
        matchingIngredients: matching,
        useSoonIngredients: useSoonMatches,
        recentPlanCount: recentPlanCount,
      );
    }).toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));

    return ranked;
  }

  static List<RecipeRecommendation> useSoonSuggestions({
    required List<Recipe> recipes,
    required List<PantryItem> pantryItems,
    required List<PlannedMeal> plannedMeals,
  }) {
    return rankRecipes(
      recipes: recipes,
      pantryItems: pantryItems,
      plannedMeals: plannedMeals,
    ).where((recommendation) => recommendation.useSoonIngredients.isNotEmpty).take(4).toList(growable: false);
  }

  static List<Recipe> repeatRecipes({
    required List<Recipe> recipes,
    required List<PlannedMeal> plannedMeals,
  }) {
    final recentCounts = _recentPlanCounts(plannedMeals);
    final repeated = recipes
        .where((recipe) => (recentCounts[recipe.id] ?? 0) > 0)
        .toList(growable: false)
      ..sort((a, b) => (recentCounts[b.id] ?? 0).compareTo(recentCounts[a.id] ?? 0));
    return repeated.take(4).toList(growable: false);
  }

  static List<Recipe> favoriteRecipes({
    required List<Recipe> recipes,
    required List<PantryItem> pantryItems,
    required List<PlannedMeal> plannedMeals,
  }) {
    final rankedFavorites = rankRecipes(
      recipes: recipes.where((recipe) => recipe.isFavorite).toList(growable: false),
      pantryItems: pantryItems,
      plannedMeals: plannedMeals,
    );
    return rankedFavorites.map((item) => item.recipe).take(4).toList(growable: false);
  }

  static List<LeftoverSuggestion> leftoverSuggestions({
    required List<Recipe> recipes,
    required List<PlannedMeal> plannedMeals,
  }) {
    final recipeById = <String, Recipe>{for (final recipe in recipes) recipe.id: recipe};
    final recentMeals = plannedMeals
        .where((meal) => DateTime.now().difference(meal.date).inDays <= 3)
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    final suggestions = <LeftoverSuggestion>[];
    final usedRecipeIds = <String>{};

    for (final meal in recentMeals) {
      final source = recipeById[meal.recipeId];
      if (source == null) {
        continue;
      }

      Recipe? bestMatch;
      List<String> shared = const <String>[];
      for (final candidate in recipes) {
        if (candidate.id == source.id || usedRecipeIds.contains(candidate.id)) {
          continue;
        }
        final overlap = candidate.ingredients
            .where((ingredient) => source.ingredients.contains(ingredient))
            .toList(growable: false);
        if (overlap.length > shared.length) {
          bestMatch = candidate;
          shared = overlap;
        }
      }

      if (bestMatch != null && shared.isNotEmpty) {
        usedRecipeIds.add(bestMatch.id);
        suggestions.add(
          LeftoverSuggestion(
            recipe: bestMatch,
            sourceRecipeTitle: source.title,
            sharedIngredients: shared,
          ),
        );
      }

      if (suggestions.length == 3) {
        break;
      }
    }

    return suggestions;
  }

  static Map<String, int> _recentPlanCounts(List<PlannedMeal> plannedMeals) {
    final counts = <String, int>{};
    for (final meal in plannedMeals) {
      if (DateTime.now().difference(meal.date).inDays > 14) {
        continue;
      }
      counts.update(meal.recipeId, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}
