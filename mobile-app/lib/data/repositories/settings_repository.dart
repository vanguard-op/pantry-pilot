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
}
