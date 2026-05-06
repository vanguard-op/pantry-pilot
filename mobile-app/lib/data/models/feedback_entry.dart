import 'feedback_enum_extensions.dart';

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
      category: (map['category'] as String? ?? 'other').toFeedbackCategory(),
      status: (map['status'] as String? ?? 'open').toFeedbackStatus(),
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
      'category': category.apiValue,
      'status': status.apiValue,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
