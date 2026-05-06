import 'feedback_entry.dart';

extension FeedbackCategoryApiExtension on FeedbackCategory {
  String get apiValue {
    return switch (this) {
      FeedbackCategory.bug => 'bug',
      FeedbackCategory.suggestion => 'suggestion',
      FeedbackCategory.other => 'other',
    };
  }
}

extension FeedbackStatusApiExtension on FeedbackStatus {
  String get apiValue {
    return switch (this) {
      FeedbackStatus.open => 'open',
      FeedbackStatus.inReview => 'in_review',
      FeedbackStatus.resolved => 'resolved',
    };
  }
}

extension FeedbackCategoryParsingExtension on String {
  FeedbackCategory toFeedbackCategory() {
    return switch (this) {
      'bug' => FeedbackCategory.bug,
      'suggestion' => FeedbackCategory.suggestion,
      _ => FeedbackCategory.other,
    };
  }
}

extension FeedbackStatusParsingExtension on String {
  FeedbackStatus toFeedbackStatus() {
    return switch (this) {
      'open' => FeedbackStatus.open,
      'in_review' => FeedbackStatus.inReview,
      'resolved' => FeedbackStatus.resolved,
      _ => FeedbackStatus.open,
    };
  }
}
