import '../api/api_client.dart';

class SettingsRepository {
  SettingsRepository(this._apiClient);

  final ApiClient _apiClient;
  _SettingsSnapshot _settings = const _SettingsSnapshot();

  Future<void> initialize() async {
    _settings = _deserialize(await _apiClient.getObject('/api/v1/settings'));
  }

  bool get onboardingComplete => _settings.onboardingComplete;

  Future<void> setOnboardingComplete(bool value) async {
    await _update(<String, dynamic>{'onboarding_complete': value});
  }

  Future<void> saveHouseholdProfile({
    required int size,
    required String skillLevel,
    required String dietaryNotes,
  }) async {
    await _update(<String, dynamic>{
      'household_size': size,
      'skill_level': skillLevel,
      'dietary_notes': dietaryNotes,
    });
  }

  int get householdSize => _settings.householdSize;

  String get skillLevel => _settings.skillLevel;

  String get dietaryNotes => _settings.dietaryNotes;

  int get expiryThresholdDays => _settings.expiryThresholdDays;

  Future<void> setExpiryThresholdDays(int days) async {
    final normalized = days < 1 ? 1 : (days > 30 ? 30 : days);
    await _update(<String, dynamic>{'expiry_threshold_days': normalized});
  }

  bool get pantryAutoDeductEnabled => _settings.pantryAutoDeductEnabled;

  Future<void> setPantryAutoDeductEnabled(bool enabled) async {
    await _update(<String, dynamic>{'pantry_auto_deduct_enabled': enabled});
  }

  bool get expiryNotificationsEnabled => _settings.expiryNotificationsEnabled;

  bool get mealReminderNotificationsEnabled =>
      _settings.mealReminderNotificationsEnabled;

  Future<void> saveNotificationPreferences({
    required bool expiryAlerts,
    required bool mealReminders,
  }) async {
    await _update(<String, dynamic>{
      'expiry_notifications_enabled': expiryAlerts,
      'meal_reminder_notifications_enabled': mealReminders,
    });
  }

  DateTime? get firstPlanCreatedAt => _settings.firstPlanCreatedAt;

  Future<void> setFirstPlanCreatedAtIfAbsent(DateTime timestamp) async {
    if (firstPlanCreatedAt != null) {
      return;
    }
    await _update(<String, dynamic>{
      'first_plan_created_at': timestamp.toIso8601String(),
    });
  }

  Future<void> logCookingSession(DateTime timestamp) async {
    final dates = _readDateList('cooking_session_dates');
    dates.add(timestamp);
    await _update(<String, dynamic>{
      'cooking_session_dates': dates
          .map((date) => date.toIso8601String())
          .toList(growable: false),
    });
  }

  int get totalCookingSessions => _readDateList('cooking_session_dates').length;

  int cookingSessionsInLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _readDateList('cooking_session_dates')
        .where((date) => date.isAfter(cutoff))
        .length;
  }

  List<DateTime> _readDateList(String key) {
    final raw = switch (key) {
      'cooking_session_dates' => _settings.cookingSessionDates,
      _ => const <String>[],
    };

    return raw
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList(growable: false);
  }

  Future<void> _update(Map<String, dynamic> payload) async {
    _settings = _deserialize(
      await _apiClient.putObject('/api/v1/settings', body: payload),
    );
  }

  _SettingsSnapshot _deserialize(Map<String, dynamic> json) {
    return _SettingsSnapshot(
      householdSize: (json['household_size'] as num?)?.toInt() ?? 1,
      skillLevel: json['skill_level'] as String? ?? 'Beginner',
      dietaryNotes: json['dietary_notes'] as String? ?? '',
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      firstPlanCreatedAt: DateTime.tryParse(
        json['first_plan_created_at'] as String? ?? '',
      ),
      cookingSessionDates:
          (json['cooking_session_dates'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      expiryThresholdDays:
          (json['expiry_threshold_days'] as num?)?.toInt() ?? 3,
      expiryNotificationsEnabled:
          json['expiry_notifications_enabled'] as bool? ?? true,
      mealReminderNotificationsEnabled:
          json['meal_reminder_notifications_enabled'] as bool? ?? true,
      pantryAutoDeductEnabled:
          json['pantry_auto_deduct_enabled'] as bool? ?? true,
    );
  }
}

class _SettingsSnapshot {
  const _SettingsSnapshot({
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
}
