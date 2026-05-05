import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/pantry_item.dart';
import '../data/models/planned_meal.dart';
import '../data/models/recipe.dart';

class NotificationService {
  NotificationService(this._notificationsPlugin);

  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  static const _androidDetails = AndroidNotificationDetails(
    'pantry_pilot_reminders',
    'PantryPilot Reminders',
    channelDescription: 'Meal plan and pantry expiry reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _details = NotificationDetails(android: _androidDetails);

  Future<void> initialize() async {
    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> syncReminders({
    required List<PantryItem> pantryItems,
    required List<PlannedMeal> plannedMeals,
    required List<Recipe> recipes,
  }) async {
    await _notificationsPlugin.cancelAll();

    final recipeById = <String, Recipe>{
      for (final recipe in recipes) recipe.id: recipe,
    };

    var notificationId = 1000;
    for (final item in pantryItems.where(
      (item) => item.daysUntilExpiry >= 0 && item.daysUntilExpiry <= 3,
    )) {
      final when = _expiryReminderTime(item.expiryDate);
      if (when.isBefore(tz.TZDateTime.now(tz.local))) {
        continue;
      }
      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: 'Use soon: ${item.name}',
        body:
            '${item.quantity} ${item.unit} in ${item.storageLocation} expires ${_daysLabel(item.daysUntilExpiry)}.',
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      notificationId += 1;
    }

    for (final meal
        in plannedMeals.where((meal) => !_isPastDay(meal.date)).take(7)) {
      final recipe = recipeById[meal.recipeId];
      final when = _mealReminderTime(meal.date, meal.slot);
      if (recipe == null || when.isBefore(tz.TZDateTime.now(tz.local))) {
        continue;
      }
      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: 'Upcoming ${meal.slot.toLowerCase()}',
        body:
            '${recipe.title} is planned for ${meal.slot.toLowerCase()} today.',
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      notificationId += 1;
    }
  }

  tz.TZDateTime _expiryReminderTime(DateTime expiryDate) {
    final localDay = tz.TZDateTime.from(expiryDate, tz.local);
    return tz.TZDateTime(
      tz.local,
      localDay.year,
      localDay.month,
      localDay.day,
      9,
    );
  }

  tz.TZDateTime _mealReminderTime(DateTime mealDate, String slot) {
    final localDay = tz.TZDateTime.from(mealDate, tz.local);
    final hour = switch (slot) {
      'Breakfast' => 8,
      'Lunch' => 11,
      _ => 17,
    };
    return tz.TZDateTime(
      tz.local,
      localDay.year,
      localDay.month,
      localDay.day,
      hour,
    );
  }

  bool _isPastDay(DateTime date) {
    final now = DateTime.now();
    final normalized = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return normalized.isBefore(today);
  }

  String _daysLabel(int daysUntilExpiry) {
    if (daysUntilExpiry <= 0) {
      return 'today';
    }
    if (daysUntilExpiry == 1) {
      return 'tomorrow';
    }
    return 'in $daysUntilExpiry days';
  }
}
