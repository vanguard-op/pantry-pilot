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
    await _box.put(item.id, item);
  }

  Future<void> upsertAll(List<PantryItem> items) async {
    final map = <String, PantryItem>{for (final item in items) item.id: item};
    await _box.putAll(map);
  }

  Future<void> updateItem(PantryItem item) async {
    await _box.put(item.id, item);
  }

  Future<void> deleteItem(String id) async {
    await _box.delete(id);
  }
}
