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
    required int expiryThresholdDays,
    required bool expiryAlertsEnabled,
    required bool mealRemindersEnabled,
    int maxDailyNotifications = 2,
  }) async {
    await _notificationsPlugin.cancelAll();

    if (!expiryAlertsEnabled && !mealRemindersEnabled) {
      return;
    }

    final recipeById = <String, Recipe>{
      for (final recipe in recipes) recipe.id: recipe,
    };
    final scheduledPerDay = <String, int>{};

    var notificationId = 1000;
    if (expiryAlertsEnabled) {
      for (final item in pantryItems.where(
        (item) =>
            item.daysUntilExpiry >= 0 &&
            item.daysUntilExpiry <= expiryThresholdDays,
      )) {
        final when = _expiryReminderTime(item.expiryDate);
        if (!_canSchedule(
          when,
          scheduledPerDay: scheduledPerDay,
          maxDailyNotifications: maxDailyNotifications,
        )) {
          continue;
        }
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
        _markScheduled(when, scheduledPerDay: scheduledPerDay);
        notificationId += 1;
      }
    }

    if (mealRemindersEnabled) {
      for (final meal
          in plannedMeals.where((meal) => !_isPastDay(meal.date)).take(7)) {
        final recipe = recipeById[meal.recipeId];
        final when = _mealReminderTime(meal.date, meal.slot);
        if (!_canSchedule(
          when,
          scheduledPerDay: scheduledPerDay,
          maxDailyNotifications: maxDailyNotifications,
        )) {
          continue;
        }
        if (recipe == null || when.isBefore(tz.TZDateTime.now(tz.local))) {
          continue;
        }
        await _notificationsPlugin.zonedSchedule(
          id: notificationId,
          title: 'Upcoming ${meal.slot.toLowerCase()}',
          body:
              '${recipe.title} is planned for ${meal.slot.toLowerCase()} ${_dayLabel(meal.date)}.',
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        _markScheduled(when, scheduledPerDay: scheduledPerDay);
        notificationId += 1;
      }
    }
  }

  bool _canSchedule(
    tz.TZDateTime when, {
    required Map<String, int> scheduledPerDay,
    required int maxDailyNotifications,
  }) {
    final key = _dayKey(when);
    final alreadyScheduled = scheduledPerDay[key] ?? 0;
    return alreadyScheduled < maxDailyNotifications;
  }

  void _markScheduled(
    tz.TZDateTime when, {
    required Map<String, int> scheduledPerDay,
  }) {
    final key = _dayKey(when);
    scheduledPerDay.update(key, (count) => count + 1, ifAbsent: () => 1);
  }

  String _dayKey(tz.TZDateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final normalized = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (normalized == today) {
      return 'today';
    }
    if (normalized == tomorrow) {
      return 'tomorrow';
    }
    return 'on ${normalized.toString().split(' ').first}';
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
