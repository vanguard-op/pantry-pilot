import '../api/api_client.dart';
import '../models/recommendations.dart';

class RecommendationRepository {
  RecommendationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PlannerRecommendations> fetchPlannerRecommendations() async {
    final response = await _apiClient.getObject(
      '/api/v1/recommendations/planner',
    );
    return PlannerRecommendations.fromMap(response);
  }

  Future<DashboardRecommendations> fetchDashboardRecommendations() async {
    final response = await _apiClient.getObject(
      '/api/v1/recommendations/dashboard',
    );
    return DashboardRecommendations.fromMap(response);
  }

  /// Fetches pantry-aware substitution hints for a list of ingredient names.
  ///
  /// Returns a map of [ingredient] → [SubstitutionHint] for convenient UI
  /// look-up. Each hint includes a text description and any pantry items that
  /// are known substitutes and are currently in the user's pantry.
  Future<Map<String, SubstitutionHint>> fetchSubstitutionHints(
    List<String> ingredients,
  ) async {
    if (ingredients.isEmpty) {
      return const <String, SubstitutionHint>{};
    }

    final response = await _apiClient.getObject(
      '/api/v1/substitutions',
      queryParameters: <String, String>{'ingredients': ingredients.join(',')},
    );

    final hintsList = (response['hints'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => SubstitutionHint.fromMap(item.cast<String, dynamic>()))
        .toList(growable: false);

    return <String, SubstitutionHint>{
      for (final hint in hintsList) hint.ingredient: hint,
    };
  }

  /// Fetches pantry coverage for [recipeId] from the backend.
  ///
  /// Coverage is computed server-side so future improvements (partial
  /// quantities, expiry awareness, unit normalisation) need no mobile changes.
  Future<PantryCoverage> fetchPantryCoverage(String recipeId) async {
    final response = await _apiClient.getObject(
      '/api/v1/recipes/$recipeId/coverage',
    );
    return PantryCoverage.fromMap(response);
  }
}
