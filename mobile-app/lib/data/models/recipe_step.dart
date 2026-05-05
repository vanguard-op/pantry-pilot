class RecipeStep {
  const RecipeStep({
    required this.description,
    required this.durationMinutes,
    required this.ingredientMentions,
  });

  final String description;

  final int durationMinutes;

  final List<String> ingredientMentions;
}
