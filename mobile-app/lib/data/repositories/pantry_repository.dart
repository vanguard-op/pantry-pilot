import 'dart:async';

import 'package:hive/hive.dart';

import '../models/pantry_item.dart';

class PantryRepository {
  PantryRepository(this._box);

  final Box<PantryItem> _box;

  List<PantryItem> getAll() => _box.values.toList(growable: false);

  Stream<List<PantryItem>> watchAll() async* {
    yield getAll();
    yield* _box.watch().map((_) => getAll());
  }

  Future<void> addItem(PantryItem item) async {
    await _box.put(item.id, _normalizeItem(item));
  }

  Future<void> upsertAll(List<PantryItem> items) async {
    final map = <String, PantryItem>{
      for (final item in items) item.id: _normalizeItem(item),
    };
    await _box.putAll(map);
  }

  Future<void> updateItem(PantryItem item) async {
    await _box.put(item.id, _normalizeItem(item));
  }

  Future<void> deleteItem(String id) async {
    await _box.delete(id);
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
}
