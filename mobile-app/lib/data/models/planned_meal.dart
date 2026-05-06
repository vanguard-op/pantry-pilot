class PlannedMeal {
  PlannedMeal({
    required this.id,
    required this.recipeId,
    required this.date,
    required this.slot,
  });

  final String id;

  final String recipeId;

  final DateTime date;

  final String slot;
}
