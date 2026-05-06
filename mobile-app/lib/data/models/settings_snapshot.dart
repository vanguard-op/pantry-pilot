class SettingsSnapshot {
  const SettingsSnapshot({
    this.householdSize = 1,
    this.skillLevel = 'Beginner',
    this.dietaryNotes = '',
    this.onboardingComplete = false,
    this.firstPlanCreatedAt,
    this.cookingSessionDates = const <String>[],
    this.expiryThresholdDays = 3,
    this.expiryNotificationsEnabled = true,
    this.mealReminderNotificationsEnabled = true,
    this.pantryAutoDeductEnabled = true,
  });

  final int householdSize;
  final String skillLevel;
  final String dietaryNotes;
  final bool onboardingComplete;
  final DateTime? firstPlanCreatedAt;
  final List<String> cookingSessionDates;
  final int expiryThresholdDays;
  final bool expiryNotificationsEnabled;
  final bool mealReminderNotificationsEnabled;
  final bool pantryAutoDeductEnabled;

  factory SettingsSnapshot.fromMap(Map<String, dynamic> map) {
    return SettingsSnapshot(
      householdSize: (map['household_size'] as num?)?.toInt() ?? 1,
      skillLevel: map['skill_level'] as String? ?? 'Beginner',
      dietaryNotes: map['dietary_notes'] as String? ?? '',
      onboardingComplete: map['onboarding_complete'] as bool? ?? false,
      firstPlanCreatedAt: DateTime.tryParse(
        map['first_plan_created_at'] as String? ?? '',
      ),
      cookingSessionDates:
          (map['cooking_session_dates'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      expiryThresholdDays: (map['expiry_threshold_days'] as num?)?.toInt() ?? 3,
      expiryNotificationsEnabled:
          map['expiry_notifications_enabled'] as bool? ?? true,
      mealReminderNotificationsEnabled:
          map['meal_reminder_notifications_enabled'] as bool? ?? true,
      pantryAutoDeductEnabled:
          map['pantry_auto_deduct_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'household_size': householdSize,
      'skill_level': skillLevel,
      'dietary_notes': dietaryNotes,
      'onboarding_complete': onboardingComplete,
      'first_plan_created_at': firstPlanCreatedAt?.toIso8601String(),
      'cooking_session_dates': cookingSessionDates,
      'expiry_threshold_days': expiryThresholdDays,
      'expiry_notifications_enabled': expiryNotificationsEnabled,
      'meal_reminder_notifications_enabled': mealReminderNotificationsEnabled,
      'pantry_auto_deduct_enabled': pantryAutoDeductEnabled,
    };
  }
}
