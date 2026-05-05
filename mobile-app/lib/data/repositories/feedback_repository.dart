import 'dart:async';

import 'package:hive/hive.dart';

import '../models/feedback_entry.dart';

class FeedbackRepository {
  FeedbackRepository(this._box);

  final Box<dynamic> _box;

  List<FeedbackEntry> getAll() {
    final entries = _box.values
        .whereType<Map>()
        .map((raw) => FeedbackEntry.fromMap(raw))
        .whereType<FeedbackEntry>()
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Stream<List<FeedbackEntry>> watchAll() async* {
    yield getAll();
    yield* _box.watch().map((_) => getAll());
  }

  Future<void> addEntry({
    required String message,
    required FeedbackCategory category,
  }) async {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final entry = FeedbackEntry(
      id: id,
      message: normalizedMessage,
      category: category,
      status: FeedbackStatus.open,
      createdAt: DateTime.now(),
    );
    await _box.put(id, entry.toMap());
  }

  Future<void> updateStatus({
    required String id,
    required FeedbackStatus status,
  }) async {
    final raw = _box.get(id);
    if (raw is! Map) {
      return;
    }

    final existing = FeedbackEntry.fromMap(raw);
    if (existing == null) {
      return;
    }

    await _box.put(id, existing.copyWith(status: status).toMap());
  }
}
