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
      body: _normalizeItem(item).toMap(),
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
          body: normalized.toMap(),
        );
        continue;
      }

      await _apiClient.patchObject(
        '/api/v1/pantry/${existing.id}',
        body: normalized.copyWith(quantity: existing.quantity + normalized.quantity).toMap(),
      );
    }
    await _refresh();
  }

  Future<void> updateItem(PantryItem item) async {
    await _apiClient.patchObject(
      '/api/v1/pantry/${item.id}',
      body: _normalizeItem(item).toMap(),
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
          .map((item) => PantryItem.fromMap(item.cast<String, dynamic>()))
          .toList(growable: false)
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      _initialized = true;
      _controller.add(getAll());
    } finally {
      _loading = false;
    }
  }
}
