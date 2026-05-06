class ShoppingListItem {
  const ShoppingListItem({required this.name, required this.neededForMeals});

  final String name;
  final int neededForMeals;

  factory ShoppingListItem.fromMap(Map<String, dynamic> map) {
    return ShoppingListItem(
      name: (map['name'] as String? ?? '').trim().toLowerCase(),
      neededForMeals: (map['needed_for_meals'] as num?)?.toInt() ?? 0,
    );
  }
}
