class PantryItem {
  PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
    required this.expiryDate,
    required this.lowStockThreshold,
  });

  final String id;

  final String name;

  final double quantity;

  final String unit;

  final String storageLocation;

  final DateTime expiryDate;

  final double lowStockThreshold;

  PantryItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? storageLocation,
    DateTime? expiryDate,
    double? lowStockThreshold,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      storageLocation: storageLocation ?? this.storageLocation,
      expiryDate: expiryDate ?? this.expiryDate,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }

  bool get isLowStock => quantity <= lowStockThreshold;

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
}
