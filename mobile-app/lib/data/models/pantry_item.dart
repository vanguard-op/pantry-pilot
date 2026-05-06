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

  factory PantryItem.fromMap(Map<String, dynamic> map) {
    return PantryItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed item',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unit: map['unit'] as String? ?? 'pcs',
      storageLocation: map['storage_location'] as String? ?? 'Pantry',
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

  static String _serializeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day)
        .toIso8601String()
        .split('T')
        .first;
  }
}
