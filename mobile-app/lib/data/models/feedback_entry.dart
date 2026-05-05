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
      'category': category.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static FeedbackEntry? fromMap(Map<dynamic, dynamic> map) {
    final id = map['id'];
    final message = map['message'];
    final categoryName = map['category'];
    final statusName = map['status'];
    final createdAtRaw = map['createdAt'];

    if (id is! String ||
        message is! String ||
        categoryName is! String ||
        statusName is! String ||
        createdAtRaw is! String) {
      return null;
    }

    final category = FeedbackCategory.values
        .where((value) => value.name == categoryName)
        .cast<FeedbackCategory?>()
        .firstWhere(
          (value) => value != null,
          orElse: () => FeedbackCategory.other,
        );
    final status = FeedbackStatus.values
        .where((value) => value.name == statusName)
        .cast<FeedbackStatus?>()
        .firstWhere(
          (value) => value != null,
          orElse: () => FeedbackStatus.open,
        );
    final createdAt = DateTime.tryParse(createdAtRaw);

    if (createdAt == null || message.trim().isEmpty) {
      return null;
    }

    return FeedbackEntry(
      id: id,
      message: message.trim(),
      category: category ?? FeedbackCategory.other,
      status: status ?? FeedbackStatus.open,
      createdAt: createdAt,
    );
  }
}
