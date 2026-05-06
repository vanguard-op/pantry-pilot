import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/onboarding/onboarding_bloc.dart';
import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../data/repositories/settings_repository.dart';
import '../../theme/app_theme.dart';

class KpiDashboardScreen extends StatelessWidget {
  const KpiDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final onboardingComplete = context.watch<OnboardingBloc>().state.completed;
    final pantryState = context.watch<PantryBloc>().state;
    final plannerState = context.watch<PlannerBloc>().state;
    final settingsRepository = context.read<SettingsRepository>();

    final firstPlanCreatedAt = settingsRepository.firstPlanCreatedAt;
    final plannedMealsThisWeek = plannerState.meals.where((meal) {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      return meal.date.isAfter(cutoff);
    }).length;
    final cookingSessionsLast7 = settingsRepository.cookingSessionsInLastDays(7);
    final atRiskRatio = pantryState.items.isEmpty
        ? 0.0
        : pantryState.useSoonItems.length / pantryState.items.length;

    return Scaffold(
      appBar: AppBar(title: const Text('KPI Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(AppPadding.md),
        children: <Widget>[
          _KpiCard(
            title: 'Activation',
            subtitle: 'First weekly plan completion',
            metric: firstPlanCreatedAt == null ? 'Pending' : 'Complete',
            hint: onboardingComplete
                ? 'Onboarding complete. Next milestone is first plan.'
                : 'User has not completed onboarding yet.',
          ),
          const SizedBox(height: AppPadding.md),
          _KpiCard(
            title: 'Retention Proxy',
            subtitle: 'Planning and cooking activity in last 7 days',
            metric: '$plannedMealsThisWeek meals planned / $cookingSessionsLast7 cooks',
            hint: 'Target trend: steady week-over-week planner and cooking reuse.',
          ),
          const SizedBox(height: AppPadding.md),
          _KpiCard(
            title: 'Waste-Reduction Proxy',
            subtitle: 'Share of pantry items expiring within 3 days',
            metric: '${(atRiskRatio * 100).toStringAsFixed(1)}% at risk',
            hint: 'Lower is better. Use-soon nudges should push this number down.',
          ),
          const SizedBox(height: AppPadding.md),
          _KpiCard(
            title: 'Baseline Counts',
            subtitle: 'Current inventory and planning footprint',
            metric: '${pantryState.items.length} pantry items / ${plannerState.meals.length} total planned meals',
            hint: 'Use this to sanity-check recommendation and planning coverage.',
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.hint,
  });

  final String title;
  final String subtitle;
  final String metric;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppPadding.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppPadding.xs),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppPadding.md),
            Text(
              metric,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppPadding.sm),
            Text(hint),
          ],
        ),
      ),
    );
  }
}
