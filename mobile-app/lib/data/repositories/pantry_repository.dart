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

  Future<void> refresh() => _refresh(force: true);

  List<PantryItem> getAll() => List<PantryItem>.unmodifiable(_items);

  Stream<List<PantryItem>> watchAll() async* {
    if (!_initialized && !_loading) {
      unawaited(_refresh());
    }
    yield getAll();
    yield* _controller.stream;
  }

  Future<void> addItem(PantryItem item) async {
    await _ensureLoaded();
    final created = PantryItem.fromMap(
      await _apiClient.postObject(
        '/api/v1/pantry',
        body: _normalizeItem(item).toMap(),
      ),
    );
    _upsert(created);
    _emit();
  }

  Future<void> upsertAll(List<PantryItem> items) async {
    await _ensureLoaded();
    for (final item in items) {
      final normalized = _normalizeItem(item);
      final existing = _items
          .where((entry) {
            return entry.name.trim().toLowerCase() ==
                normalized.name.trim().toLowerCase();
          })
          .cast<PantryItem?>()
          .firstWhere((entry) => entry != null, orElse: () => null);

      if (existing == null) {
        final created = PantryItem.fromMap(
          await _apiClient.postObject(
            '/api/v1/pantry',
            body: normalized.toMap(),
          ),
        );
        _upsert(created);
        continue;
      }

      final updated = PantryItem.fromMap(
        await _apiClient.patchObject(
          '/api/v1/pantry/${existing.id}',
          body: normalized
              .copyWith(quantity: existing.quantity + normalized.quantity)
              .toMap(),
        ),
      );
      _upsert(updated);
    }
    _emit();
  }

  Future<void> updateItem(PantryItem item) async {
    await _ensureLoaded();
    final updated = PantryItem.fromMap(
      await _apiClient.patchObject(
        '/api/v1/pantry/${item.id}',
        body: _normalizeItem(item).toMap(),
      ),
    );
    _upsert(updated);
    _emit();
  }

  Future<void> deleteItem(String id) async {
    await _ensureLoaded();
    await _apiClient.delete('/api/v1/pantry/$id');
    _items = _items.where((item) => item.id != id).toList(growable: false);
    _emit();
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

  Future<void> _refresh({bool force = false}) async {
    if (_loading) {
      return;
    }
    if (_initialized && !force) {
      return;
    }

    _loading = true;
    try {
      final rawItems = await _apiClient.getList('/api/v1/pantry');
      _items = rawItems
          .whereType<Map>()
          .map((item) => PantryItem.fromMap(item.cast<String, dynamic>()))
          .toList(growable: false);
      _initialized = true;
      _emit();
    } finally {
      _loading = false;
    }
  }

  void _upsert(PantryItem value) {
    _items = <PantryItem>[
      ..._items.where((item) => item.id != value.id),
      value,
    ];
  }

  void _emit() {
    _items = _items.toList(growable: false)
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    _controller.add(getAll());
  }
}
