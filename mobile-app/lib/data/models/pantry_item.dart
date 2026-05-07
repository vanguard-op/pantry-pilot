enum PantryItemKind { ingredient, cookedMeal }

extension PantryItemKindApi on PantryItemKind {
  String get apiValue {
    switch (this) {
      case PantryItemKind.cookedMeal:
        return 'cooked_meal';
      case PantryItemKind.ingredient:
        return 'ingredient';
    }
  }

  static PantryItemKind fromApi(String? value) {
    switch (value) {
      case 'cooked_meal':
        return PantryItemKind.cookedMeal;
      default:
        return PantryItemKind.ingredient;
    }
  }
}

class PantryItem {
  PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
    required this.expiryDate,
    required this.lowStockThreshold,
    this.itemKind = PantryItemKind.ingredient,
  });

  final String id;

  final String name;

  final double quantity;

  final String unit;

  final String storageLocation;

  final DateTime expiryDate;

  final double lowStockThreshold;

  final PantryItemKind itemKind;

  factory PantryItem.fromMap(Map<String, dynamic> map) {
    return PantryItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed item',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unit: map['unit'] as String? ?? 'pcs',
      storageLocation: map['storage_location'] as String? ?? 'Pantry shelf',
      itemKind: PantryItemKindApi.fromApi(map['item_kind'] as String?),
      expiryDate:
          DateTime.tryParse(map['expiry_date'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'storage_location': storageLocation,
      'item_kind': itemKind.apiValue,
      'expiry_date': _serializeDate(expiryDate),
      'low_stock_threshold': lowStockThreshold,
    };
  }

  PantryItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? storageLocation,
    PantryItemKind? itemKind,
    DateTime? expiryDate,
    double? lowStockThreshold,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      storageLocation: storageLocation ?? this.storageLocation,
      itemKind: itemKind ?? this.itemKind,
      expiryDate: expiryDate ?? this.expiryDate,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }

  bool get isLowStock => quantity <= lowStockThreshold;

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;

  static String _serializeDate(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).toIso8601String().split('T').first;
  }
}
