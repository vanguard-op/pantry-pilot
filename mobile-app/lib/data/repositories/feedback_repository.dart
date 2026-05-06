import 'dart:async';

import '../api/api_client.dart';
import '../models/feedback_enum_extensions.dart';
import '../models/feedback_entry.dart';

class FeedbackRepository {
  FeedbackRepository(this._apiClient);

  final ApiClient _apiClient;
  final StreamController<List<FeedbackEntry>> _controller =
      StreamController<List<FeedbackEntry>>.broadcast();
  List<FeedbackEntry> _entries = const <FeedbackEntry>[];
  bool _loading = false;
  bool _initialized = false;

  Future<void> initialize() => _refresh();

  List<FeedbackEntry> getAll() {
    return List<FeedbackEntry>.unmodifiable(_entries);
  }

  Stream<List<FeedbackEntry>> watchAll() async* {
    if (!_initialized && !_loading) {
      unawaited(_refresh());
    }
    yield getAll();
    yield* _controller.stream;
  }

  Future<void> addEntry({
    required String message,
    required FeedbackCategory category,
  }) async {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }

    await _ensureLoaded();
    final created = FeedbackEntry.fromMap(
      await _apiClient.postObject(
        '/api/v1/feedback',
        body: <String, dynamic>{
          'message': normalizedMessage,
          'category': category.apiValue,
        },
      ),
    );

    _upsert(created);
    _emit();
  }

  Future<void> updateStatus({
    required String id,
    required FeedbackStatus status,
  }) async {
    await _ensureLoaded();
    final updated = FeedbackEntry.fromMap(
      await _apiClient.patchObject(
        '/api/v1/feedback/$id',
        body: <String, dynamic>{'status': status.apiValue},
      ),
    );
    _upsert(updated);
    _emit();
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
      final rawEntries = await _apiClient.getList('/api/v1/feedback');
      _entries =
          rawEntries
              .whereType<Map>()
              .map(
                (entry) => FeedbackEntry.fromMap(entry.cast<String, dynamic>()),
              )
              .toList(growable: false);
      _initialized = true;
      _emit();
    } finally {
      _loading = false;
    }
  }

  void _upsert(FeedbackEntry value) {
    _entries = <FeedbackEntry>[
      ..._entries.where((entry) => entry.id != value.id),
      value,
    ];
  }

  void _emit() {
    _entries = _entries.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _controller.add(getAll());
  }
}
