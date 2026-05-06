import 'package:hive/hive.dart';

class SettingsRepository {
  SettingsRepository(this._box);

  final Box<dynamic> _box;

  bool get onboardingComplete =>
      _box.get('onboarding_complete', defaultValue: false) as bool;

  Future<void> setOnboardingComplete(bool value) async {
    await _box.put('onboarding_complete', value);
  }

  Future<void> saveHouseholdProfile({
    required int size,
    required String skillLevel,
    required String dietaryNotes,
  }) async {
    await _box.put('household_size', size);
    await _box.put('skill_level', skillLevel);
    await _box.put('dietary_notes', dietaryNotes);
  }

  int get householdSize => _box.get('household_size', defaultValue: 1) as int;

  String get skillLevel =>
      _box.get('skill_level', defaultValue: 'Beginner') as String;

  String get dietaryNotes =>
      _box.get('dietary_notes', defaultValue: '') as String;

  int get expiryThresholdDays =>
      _box.get('expiry_threshold_days', defaultValue: 3) as int;

  Future<void> setExpiryThresholdDays(int days) async {
    final normalized = days < 1 ? 1 : (days > 30 ? 30 : days);
    await _box.put('expiry_threshold_days', normalized);
  }

  bool get pantryAutoDeductEnabled =>
      _box.get('pantry_auto_deduct_enabled', defaultValue: true) as bool;

  Future<void> setPantryAutoDeductEnabled(bool enabled) async {
    await _box.put('pantry_auto_deduct_enabled', enabled);
  }

  bool get expiryNotificationsEnabled =>
      _box.get('expiry_notifications_enabled', defaultValue: true) as bool;

  bool get mealReminderNotificationsEnabled =>
      _box.get('meal_reminder_notifications_enabled', defaultValue: true)
          as bool;

  Future<void> saveNotificationPreferences({
    required bool expiryAlerts,
    required bool mealReminders,
  }) async {
    await _box.put('expiry_notifications_enabled', expiryAlerts);
    await _box.put('meal_reminder_notifications_enabled', mealReminders);
  }

  DateTime? get firstPlanCreatedAt {
    final raw = _box.get('first_plan_created_at') as String?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  Future<void> setFirstPlanCreatedAtIfAbsent(DateTime timestamp) async {
    if (firstPlanCreatedAt != null) {
      return;
    }
    await _box.put('first_plan_created_at', timestamp.toIso8601String());
  }

  Future<void> logCookingSession(DateTime timestamp) async {
    final dates = _readDateList('cooking_session_dates');
    dates.add(timestamp);
    await _box.put(
      'cooking_session_dates',
      dates.map((date) => date.toIso8601String()).toList(growable: false),
    );
  }

  int get totalCookingSessions => _readDateList('cooking_session_dates').length;

  int cookingSessionsInLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _readDateList('cooking_session_dates')
        .where((date) => date.isAfter(cutoff))
        .length;
  }

  List<DateTime> _readDateList(String key) {
    final raw = _box.get(key);
    if (raw is! List) {
      return <DateTime>[];
    }

    return raw
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList(growable: false);
  }
}
