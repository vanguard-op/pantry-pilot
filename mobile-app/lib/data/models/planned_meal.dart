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

  factory PlannedMeal.fromMap(Map<String, dynamic> map) {
    return PlannedMeal(
      id: map['id'] as String? ?? '',
      recipeId: map['recipe_id'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      slot: map['slot'] as String? ?? 'Dinner',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'recipe_id': recipeId,
      'date': _serializeDate(date),
      'slot': slot,
    };
  }

  static String _serializeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day)
        .toIso8601String()
        .split('T')
        .first;
  }
}
