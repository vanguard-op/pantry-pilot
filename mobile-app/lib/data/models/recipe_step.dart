class RecipeStep {
  const RecipeStep({
    required this.description,
    required this.durationMinutes,
    required this.ingredientMentions,
  });

  final String description;

  final int durationMinutes;

  final List<String> ingredientMentions;

  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      description: map['description'] as String? ?? '',
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 0,
      ingredientMentions:
          (map['ingredient_mentions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'description': description,
      'duration_minutes': durationMinutes,
      'ingredient_mentions': ingredientMentions,
    };
  }
}
