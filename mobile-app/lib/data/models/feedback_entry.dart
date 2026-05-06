enum FeedbackCategory { bug, suggestion, other }

enum FeedbackStatus { open, inReview, resolved }

class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.message,
    required this.category,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String message;
  final FeedbackCategory category;
  final FeedbackStatus status;
  final DateTime createdAt;

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    return FeedbackEntry(
      id: map['id'] as String? ?? '',
      message: map['message'] as String? ?? '',
      category: parseCategory(map['category'] as String? ?? 'other'),
      status: parseStatus(map['status'] as String? ?? 'open'),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  FeedbackEntry copyWith({FeedbackStatus? status}) {
    return FeedbackEntry(
      id: id,
      message: message,
      category: category,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'message': message,
      'category': categoryToApi(category),
      'status': statusToApi(status),
      'created_at': createdAt.toIso8601String(),
    };
  }

  static String categoryToApi(FeedbackCategory value) {
    return switch (value) {
      FeedbackCategory.bug => 'bug',
      FeedbackCategory.suggestion => 'suggestion',
      FeedbackCategory.other => 'other',
    };
  }

  static String statusToApi(FeedbackStatus value) {
    return switch (value) {
      FeedbackStatus.open => 'open',
      FeedbackStatus.inReview => 'in_review',
      FeedbackStatus.resolved => 'resolved',
    };
  }

  static FeedbackCategory parseCategory(String value) {
    return switch (value) {
      'bug' => FeedbackCategory.bug,
      'suggestion' => FeedbackCategory.suggestion,
      _ => FeedbackCategory.other,
    };
  }

  static FeedbackStatus parseStatus(String value) {
    return switch (value) {
      'open' => FeedbackStatus.open,
      'in_review' => FeedbackStatus.inReview,
      'resolved' => FeedbackStatus.resolved,
      _ => FeedbackStatus.open,
    };
  }
}
