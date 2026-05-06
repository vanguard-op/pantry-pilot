import 'dart:async';

import '../api/api_client.dart';
import '../models/pantry_item.dart';

class PantryRepository {
  PantryRepository(this._apiClient);

  final ApiClient _apiClient;
  final StreamController<List<PantryItem>> _controller =
      StreamController<List<PantryItem>>.broadcast();
  List<PantryItem> _items = const <PantryItem>[];
  bool _loading = false;
  bool _initialized = false;

  Future<void> initialize() => _refresh();

  List<PantryItem> getAll() => List<PantryItem>.unmodifiable(_items);

  Stream<List<PantryItem>> watchAll() async* {
    if (!_initialized && !_loading) {
      unawaited(_refresh());
    }
    yield getAll();
    yield* _controller.stream;
  }

  Future<void> addItem(PantryItem item) async {
    await _apiClient.postObject(
      '/api/v1/pantry',
      body: _serializeCreate(_normalizeItem(item)),
    );
    await _refresh();
  }

  Future<void> upsertAll(List<PantryItem> items) async {
    await _ensureLoaded();
    for (final item in items) {
      final normalized = _normalizeItem(item);
      final existing = _items.where((entry) {
        return entry.name.trim().toLowerCase() ==
            normalized.name.trim().toLowerCase();
      }).cast<PantryItem?>().firstWhere(
        (entry) => entry != null,
        orElse: () => null,
      );

      if (existing == null) {
        await _apiClient.postObject(
          '/api/v1/pantry',
          body: _serializeCreate(normalized),
        );
        continue;
      }

      await _apiClient.patchObject(
        '/api/v1/pantry/${existing.id}',
        body: <String, dynamic>{
          'quantity': existing.quantity + normalized.quantity,
          'unit': normalized.unit,
          'storage_location': normalized.storageLocation,
          'expiry_date': _serializeDate(normalized.expiryDate),
          'low_stock_threshold': normalized.lowStockThreshold,
        },
      );
    }
    await _refresh();
  }

  Future<void> updateItem(PantryItem item) async {
    await _apiClient.patchObject(
      '/api/v1/pantry/${item.id}',
      body: _serializeUpdate(_normalizeItem(item)),
    );
    await _refresh();
  }

  Future<void> deleteItem(String id) async {
    await _apiClient.delete('/api/v1/pantry/$id');
    await _refresh();
  }

  PantryItem _normalizeItem(PantryItem item) {
    final normalizedName = item.name.trim();
    final normalizedUnit = item.unit.trim();
    final normalizedStorage = item.storageLocation.trim();
    final normalizedQuantity = item.quantity <= 0 ? 0.01 : item.quantity;
    final normalizedThreshold = item.lowStockThreshold < 0
      ? 0.0
      : item.lowStockThreshold;

    return item.copyWith(
      name: normalizedName.isEmpty ? 'Unnamed item' : normalizedName,
      unit: normalizedUnit.isEmpty ? 'pcs' : normalizedUnit,
      storageLocation: normalizedStorage.isEmpty ? 'Pantry' : normalizedStorage,
      quantity: normalizedQuantity,
      lowStockThreshold: normalizedThreshold,
    );
  }

  Future<void> _ensureLoaded() async {
    if (_initialized) {
      return;
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) {
      return;
    }

    _loading = true;
    try {
      final rawItems = await _apiClient.getList('/api/v1/pantry');
      _items = rawItems
          .whereType<Map>()
          .map((item) => _deserialize(item.cast<String, dynamic>()))
          .toList(growable: false)
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      _initialized = true;
      _controller.add(getAll());
    } finally {
      _loading = false;
    }
  }

  Map<String, dynamic> _serializeCreate(PantryItem item) {
    return <String, dynamic>{
      'name': item.name,
      'quantity': item.quantity,
      'unit': item.unit,
      'storage_location': item.storageLocation,
      'expiry_date': _serializeDate(item.expiryDate),
      'low_stock_threshold': item.lowStockThreshold,
    };
  }

  Map<String, dynamic> _serializeUpdate(PantryItem item) {
    return <String, dynamic>{
      'name': item.name,
      'quantity': item.quantity,
      'unit': item.unit,
      'storage_location': item.storageLocation,
      'expiry_date': _serializeDate(item.expiryDate),
      'low_stock_threshold': item.lowStockThreshold,
    };
  }

  PantryItem _deserialize(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed item',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String? ?? 'pcs',
      storageLocation: json['storage_location'] as String? ?? 'Pantry',
      expiryDate:
          DateTime.tryParse(json['expiry_date'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      lowStockThreshold:
          (json['low_stock_threshold'] as num?)?.toDouble() ?? 1,
    );
  }

  String _serializeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day)
        .toIso8601String()
        .split('T')
        .first;
  }
}
