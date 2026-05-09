class ShoppingListItem {
  const ShoppingListItem({
    required this.name,
    required this.neededForMeals,
    required this.unit,
    required this.suggestedQuantity,
  });

  final String name;
  final int neededForMeals;
  final String unit;
  final double suggestedQuantity;

  factory ShoppingListItem.fromMap(Map<String, dynamic> map) {
    return ShoppingListItem(
      name: (map['name'] as String? ?? '').trim().toLowerCase(),
      neededForMeals: (map['needed_for_meals'] as num?)?.toInt() ?? 0,
      unit: (map['unit'] as String? ?? 'pcs').trim().toLowerCase(),
      suggestedQuantity: (map['suggested_quantity'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
