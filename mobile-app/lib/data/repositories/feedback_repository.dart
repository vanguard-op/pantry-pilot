import 'dart:async';

import '../api/api_client.dart';
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

    await _apiClient.postObject(
      '/api/v1/feedback',
      body: <String, dynamic>{
        'message': normalizedMessage,
        'category': _serializeCategory(category),
      },
    );
    await _refresh();
  }

  Future<void> updateStatus({
    required String id,
    required FeedbackStatus status,
  }) async {
    await _apiClient.patchObject(
      '/api/v1/feedback/$id',
      body: <String, dynamic>{'status': _serializeStatus(status)},
    );
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) {
      return;
    }

    _loading = true;
    try {
      final rawEntries = await _apiClient.getList('/api/v1/feedback');
      _entries = rawEntries
          .whereType<Map>()
          .map((entry) => _deserialize(entry.cast<String, dynamic>()))
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _initialized = true;
      _controller.add(getAll());
    } finally {
      _loading = false;
    }
  }

  FeedbackEntry _deserialize(Map<String, dynamic> json) {
    return FeedbackEntry(
      id: json['id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      category: _parseCategory(json['category'] as String? ?? 'other'),
      status: _parseStatus(json['status'] as String? ?? 'open'),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String _serializeCategory(FeedbackCategory value) {
    return switch (value) {
      FeedbackCategory.bug => 'bug',
      FeedbackCategory.suggestion => 'suggestion',
      FeedbackCategory.other => 'other',
    };
  }

  String _serializeStatus(FeedbackStatus value) {
    return switch (value) {
      FeedbackStatus.open => 'open',
      FeedbackStatus.inReview => 'in_review',
      FeedbackStatus.resolved => 'resolved',
    };
  }

  FeedbackCategory _parseCategory(String value) {
    return switch (value) {
      'bug' => FeedbackCategory.bug,
      'suggestion' => FeedbackCategory.suggestion,
      _ => FeedbackCategory.other,
    };
  }

  FeedbackStatus _parseStatus(String value) {
    return switch (value) {
      'open' => FeedbackStatus.open,
      'in_review' => FeedbackStatus.inReview,
      'resolved' => FeedbackStatus.resolved,
      _ => FeedbackStatus.open,
    };
  }
}
