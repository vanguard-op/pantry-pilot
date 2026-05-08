import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _dietaryNotesController = TextEditingController();

  int _householdSize = 1;
  String _skillLevel = 'Beginner';
  int _expiryThresholdDays = 3;
  bool _expiryNotificationsEnabled = true;
  bool _mealReminderNotificationsEnabled = true;
  bool _pantryAutoDeductEnabled = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsRepository>();
    _householdSize = settings.householdSize;
    _skillLevel = settings.skillLevel;
    _dietaryNotesController.text = settings.dietaryNotes;
    _expiryThresholdDays = settings.expiryThresholdDays;
    _expiryNotificationsEnabled = settings.expiryNotificationsEnabled;
    _mealReminderNotificationsEnabled =
        settings.mealReminderNotificationsEnabled;
    _pantryAutoDeductEnabled = settings.pantryAutoDeductEnabled;
  }

  @override
  void dispose() {
    _dietaryNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsRepository>();
    final notificationService = context.read<NotificationService>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppPadding.md),
        children: <Widget>[
          Text('Household profile', style: textTheme.titleMedium),
          const SizedBox(height: AppPadding.md),
          Text('Household size: $_householdSize'),
          Slider(
            value: _householdSize.toDouble(),
            min: 1,
            max: 8,
            divisions: 7,
            label: '$_householdSize',
            onChanged: (value) {
              setState(() => _householdSize = value.round());
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _skillLevel,
            decoration: const InputDecoration(labelText: 'Cooking skill'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
              DropdownMenuItem(
                value: 'Intermediate',
                child: Text('Intermediate'),
              ),
              DropdownMenuItem(value: 'Confident', child: Text('Confident')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _skillLevel = value);
            },
          ),
          const SizedBox(height: AppPadding.md),
          TextField(
            controller: _dietaryNotesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Dietary preferences'),
          ),
          const SizedBox(height: AppPadding.lg),
          Text('Notifications', style: textTheme.titleMedium),
          const SizedBox(height: AppPadding.sm),
          SwitchListTile(
            value: _expiryNotificationsEnabled,
            title: const Text('Expiry alerts'),
            subtitle: const Text('Notify when items are near expiry'),
            onChanged: (value) {
              setState(() => _expiryNotificationsEnabled = value);
            },
          ),
          SwitchListTile(
            value: _mealReminderNotificationsEnabled,
            title: const Text('Planned meal reminders'),
            subtitle: const Text('Notify before planned meals'),
            onChanged: (value) {
              setState(() => _mealReminderNotificationsEnabled = value);
            },
          ),
          const SizedBox(height: AppPadding.lg),
          Text('Pantry behavior', style: textTheme.titleMedium),
          const SizedBox(height: AppPadding.sm),
          Text('Use-soon threshold: $_expiryThresholdDays days'),
          Slider(
            value: _expiryThresholdDays.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            label: '$_expiryThresholdDays days',
            onChanged: (value) {
              setState(() => _expiryThresholdDays = value.round());
            },
          ),
          SwitchListTile(
            value: _pantryAutoDeductEnabled,
            title: const Text('Auto-deduct pantry after cooking'),
            subtitle: const Text(
              'Automatically reduce pantry quantities when meals complete',
            ),
            onChanged: (value) {
              setState(() => _pantryAutoDeductEnabled = value);
            },
          ),
          const SizedBox(height: AppPadding.md),
          const SizedBox(height: AppPadding.lg),
          FilledButton.icon(
            onPressed: () async {
              final pantryItems = context.read<PantryBloc>().state.items;
              final plannedMeals = context.read<PlannerBloc>().state.meals;
              final recipes = context.read<RecipesBloc>().state.recipes;

              await settings.saveHouseholdProfile(
                size: _householdSize,
                skillLevel: _skillLevel,
                dietaryNotes: _dietaryNotesController.text.trim(),
              );
              await settings.saveNotificationPreferences(
                expiryAlerts: _expiryNotificationsEnabled,
                mealReminders: _mealReminderNotificationsEnabled,
              );
              await settings.setExpiryThresholdDays(_expiryThresholdDays);
              await settings.setPantryAutoDeductEnabled(
                _pantryAutoDeductEnabled,
              );
              await notificationService.syncReminders(
                pantryItems: pantryItems,
                plannedMeals: plannedMeals,
                recipes: recipes,
                expiryThresholdDays: settings.expiryThresholdDays,
                expiryAlertsEnabled: settings.expiryNotificationsEnabled,
                mealRemindersEnabled: settings.mealReminderNotificationsEnabled,
              );

              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Settings saved')));
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save settings'),
          ),
        ],
      ),
    );
  }
}
