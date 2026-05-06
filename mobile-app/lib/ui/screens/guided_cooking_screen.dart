import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/cooking/cooking_bloc.dart';
import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/pantry_item.dart';
import '../../data/models/recipe.dart';
import '../../navigation/app_router.dart';
import '../../data/repositories/settings_repository.dart';
import '../../theme/app_theme.dart';

class GuidedCookingScreen extends StatefulWidget {
  const GuidedCookingScreen({
    super.key,
    required this.recipe,
    this.plannedMealId,
  });

  final Recipe recipe;
  final String? plannedMealId;

  @override
  State<GuidedCookingScreen> createState() => _GuidedCookingScreenState();
}

class _GuidedCookingScreenState extends State<GuidedCookingScreen> {
  late final CookingBloc _cookingBloc;
  bool _sessionLogged = false;
  bool _checklistConfirmed = false;
  bool _pantryUpdateEnabled = true;
  bool _favoriteSelected = false;
  int _selectedRating = 0;
  final Map<String, double> _deductionAmounts = <String, double>{};
  final Set<String> _acceptedSubstitutions = <String>{};

  @override
  void initState() {
    super.initState();
    _cookingBloc = CookingBloc()..add(CookingStarted(widget.recipe));
    _favoriteSelected = widget.recipe.isFavorite;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pantryUpdateEnabled = context.read<SettingsRepository>().pantryAutoDeductEnabled;
  }

  @override
  void dispose() {
    _cookingBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CookingBloc>.value(
      value: _cookingBloc,
      child: BlocListener<CookingBloc, CookingState>(
        listenWhen: (previous, current) =>
            !previous.completed && current.completed,
        listener: (context, state) {
          if (_sessionLogged) {
            return;
          }
          _sessionLogged = true;
          context.read<SettingsRepository>().logCookingSession(DateTime.now());
        },
        child: BlocBuilder<CookingBloc, CookingState>(
          builder: (context, state) {
            final currentRecipe = state.recipe;
            if (currentRecipe == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (state.completed) {
              return _CompletionView(
                recipe: currentRecipe,
                favoriteSelected: _favoriteSelected,
                pantryUpdateEnabled: _pantryUpdateEnabled,
                selectedRating: _selectedRating,
                deductionAmounts: _deductionAmounts,
                onFavoriteChanged: (value) {
                  if (_favoriteSelected == value) {
                    return;
                  }
                  setState(() => _favoriteSelected = value);
                  context.read<RecipesBloc>().add(
                    RecipeFavoriteToggled(currentRecipe.id),
                  );
                },
                onPantryUpdateChanged: (value) {
                  setState(() => _pantryUpdateEnabled = value);
                },
                onRatingChanged: (rating) {
                  setState(() => _selectedRating = rating);
                },
                onDeductionChanged: (itemId, amount) {
                  setState(() => _deductionAmounts[itemId] = amount);
                },
                onFinish: () => _finishCooking(context, currentRecipe),
                onReviewPantry: () => context.goNamed(AppRouter.pantryName),
              );
            }

            final pantryItems = context.watch<PantryBloc>().state.items;
            if (!_checklistConfirmed) {
              return _PreCookChecklistView(
                recipe: currentRecipe,
                pantryItems: pantryItems,
                acceptedSubstitutions: _acceptedSubstitutions,
                onSubstitutionToggled: (ingredient) {
                  setState(() {
                    if (_acceptedSubstitutions.contains(ingredient)) {
                      _acceptedSubstitutions.remove(ingredient);
                    } else {
                      _acceptedSubstitutions.add(ingredient);
                    }
                  });
                },
                onCancel: () => Navigator.of(context).maybePop(),
                onStartCooking: () {
                  setState(() => _checklistConfirmed = true);
                },
              );
            }

            final textTheme = Theme.of(context).textTheme;
            final step = currentRecipe.steps[state.currentStepIndex];

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  'Cooking ${state.currentStepIndex + 1}/${currentRecipe.steps.length}',
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(AppPadding.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      step.description,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppPadding.sm),
                    Wrap(
                      spacing: AppPadding.sm,
                      runSpacing: AppPadding.sm,
                      children: step.ingredientMentions
                          .map((name) => Chip(label: Text(name)))
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppPadding.lg),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(AppPadding.md),
                        child: Column(
                          children: <Widget>[
                            Text('Step timer', style: textTheme.titleMedium),
                            const SizedBox(height: AppPadding.sm),
                            Text(
                              state.mmss,
                              style: textTheme.displayMedium,
                            ),
                            const SizedBox(height: AppPadding.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                FilledButton(
                                  onPressed: state.isTimerRunning
                                      ? null
                                      : () => context.read<CookingBloc>().add(
                                          const CookingTimerStarted(),
                                        ),
                                  child: const Text('Start'),
                                ),
                                const SizedBox(width: AppPadding.sm),
                                OutlinedButton(
                                  onPressed: state.isTimerRunning
                                      ? () => context.read<CookingBloc>().add(
                                          const CookingTimerStopped(),
                                        )
                                      : null,
                                  child: const Text('Stop'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.currentStepIndex > 0
                                ? () => context.read<CookingBloc>().add(
                                    const CookingPreviousStep(),
                                  )
                                : null,
                            child: const Text('Previous'),
                          ),
                        ),
                        const SizedBox(width: AppPadding.sm),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => context.read<CookingBloc>().add(
                              const CookingNextStep(),
                            ),
                            child: Text(
                              state.currentStepIndex ==
                                      currentRecipe.steps.length - 1
                                  ? 'Finish'
                                  : 'Next step',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _finishCooking(BuildContext context, Recipe recipe) async {
    if (_pantryUpdateEnabled) {
      _applyPantryDeductions(context, recipe);
    }
    if (widget.plannedMealId != null && widget.plannedMealId!.isNotEmpty) {
      context.read<PlannerBloc>().add(PlannedMealDeleted(widget.plannedMealId!));
    }

    if (!mounted) {
      return;
    }

    final message = _selectedRating > 0
        ? 'Saved your $_selectedRating-star cook for ${recipe.title}.'
        : 'Finished ${recipe.title}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    context.goNamed(AppRouter.homeName);
  }

  void _applyPantryDeductions(BuildContext context, Recipe recipe) {
    final pantryItems = context.read<PantryBloc>().state.items;
    for (final item in _matchingPantryItems(recipe, pantryItems)) {
      final amount = _deductionAmounts[item.id] ?? _defaultDeductionAmount(item);
      if (amount <= 0) {
        continue;
      }

      final remaining = item.quantity - amount;
      if (remaining <= 0.01) {
        context.read<PantryBloc>().add(PantryItemDeleted(item.id));
        continue;
      }

      context.read<PantryBloc>().add(
        PantryItemUpdated(item.copyWith(quantity: remaining)),
      );
    }
  }

  List<PantryItem> _matchingPantryItems(Recipe recipe, List<PantryItem> pantryItems) {
    final ingredientNames = recipe.ingredients
        .map((ingredient) => ingredient.toLowerCase().trim())
        .where((ingredient) => ingredient.isNotEmpty)
        .toSet();

    return pantryItems.where((item) {
      return ingredientNames.contains(item.name.toLowerCase().trim());
    }).toList(growable: false);
  }

  double _defaultDeductionAmount(PantryItem item) {
    return item.quantity >= 1 ? 1 : item.quantity;
  }
}

class _PreCookChecklistView extends StatelessWidget {
  const _PreCookChecklistView({
    required this.recipe,
    required this.pantryItems,
    required this.acceptedSubstitutions,
    required this.onSubstitutionToggled,
    required this.onCancel,
    required this.onStartCooking,
  });

  final Recipe recipe;
  final List<PantryItem> pantryItems;
  final Set<String> acceptedSubstitutions;
  final ValueChanged<String> onSubstitutionToggled;
  final VoidCallback onCancel;
  final VoidCallback onStartCooking;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ingredientStatus = recipe.ingredients
        .map((ingredient) => _IngredientChecklistStatus.fromPantry(
              ingredient: ingredient,
              pantryItems: pantryItems,
            ))
        .toList(growable: false);
    final availableCount = ingredientStatus.where((item) => item.available).length;
    final missingItems = ingredientStatus.where((item) => !item.available).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Pre-cook checklist')),
      body: ListView(
        padding: const EdgeInsets.all(AppPadding.md),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppPadding.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Get ready for ${recipe.title}',
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppPadding.xs),
                  Text(
                    missingItems.isEmpty
                        ? 'Everything is in place. You can move straight into cooking.'
                        : '$availableCount of ${recipe.ingredients.length} ingredients are ready. Review the missing items and accept substitutions if needed.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppPadding.md),
                  Wrap(
                    spacing: AppPadding.sm,
                    runSpacing: AppPadding.sm,
                    children: <Widget>[
                      _ChecklistSummaryChip(
                        icon: Icons.check_circle_outline,
                        label: '$availableCount ready',
                        foregroundColor: colorScheme.primary,
                        backgroundColor: colorScheme.primaryContainer.withAlpha(140),
                      ),
                      _ChecklistSummaryChip(
                        icon: Icons.error_outline,
                        label: '${missingItems.length} missing',
                        foregroundColor: colorScheme.tertiary,
                        backgroundColor: colorScheme.tertiaryContainer.withAlpha(140),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppPadding.md),
          ...ingredientStatus.map((status) {
            final substitutionAccepted = acceptedSubstitutions.contains(status.ingredient);
            return Card(
              margin: const EdgeInsets.only(bottom: AppPadding.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppPadding.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          status.available ? Icons.check_circle : Icons.remove_circle_outline,
                          color: status.available ? colorScheme.primary : colorScheme.tertiary,
                        ),
                        const SizedBox(width: AppPadding.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(status.ingredient, style: textTheme.titleMedium),
                              const SizedBox(height: AppPadding.xs),
                              Text(
                                status.available
                                    ? '${_formatQuantity(status.item!.quantity)} ${status.item!.unit} available in ${status.item!.storageLocation}'
                                    : 'Missing from pantry',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppPadding.sm,
                            vertical: AppPadding.xs,
                          ),
                          decoration: BoxDecoration(
                            color: status.available
                                ? colorScheme.primaryContainer.withAlpha(140)
                                : colorScheme.tertiaryContainer.withAlpha(140),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.available
                                ? 'Available'
                                : (substitutionAccepted ? 'Substituting' : 'Needs review'),
                            style: textTheme.labelMedium?.copyWith(
                              color: status.available ? colorScheme.primary : colorScheme.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!status.available) ...<Widget>[
                      const SizedBox(height: AppPadding.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppPadding.md),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _substitutionHint(status.ingredient),
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppPadding.sm),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => onSubstitutionToggled(status.ingredient),
                                icon: Icon(
                                  substitutionAccepted
                                      ? Icons.check_circle_outline
                                      : Icons.swap_horiz,
                                ),
                                label: Text(
                                  substitutionAccepted
                                      ? 'Substitution accepted'
                                      : 'Accept substitution',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppPadding.md,
          AppPadding.sm,
          AppPadding.md,
          AppPadding.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppPadding.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: onStartCooking,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  missingItems.isEmpty ? 'Start cooking' : 'Cook with plan',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistSummaryChip extends StatelessWidget {
  const _ChecklistSummaryChip({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppPadding.md,
        vertical: AppPadding.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: AppPadding.xs),
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(color: foregroundColor),
          ),
        ],
      ),
    );
  }
}

class _IngredientChecklistStatus {
  const _IngredientChecklistStatus({
    required this.ingredient,
    required this.available,
    required this.item,
  });

  final String ingredient;
  final bool available;
  final PantryItem? item;

  factory _IngredientChecklistStatus.fromPantry({
    required String ingredient,
    required List<PantryItem> pantryItems,
  }) {
    PantryItem? matchedItem;
    for (final item in pantryItems) {
      if (item.name.toLowerCase().trim() == ingredient.toLowerCase().trim()) {
        matchedItem = item;
        break;
      }
    }

    return _IngredientChecklistStatus(
      ingredient: ingredient,
      available: matchedItem != null,
      item: matchedItem,
    );
  }
}

String _substitutionHint(String ingredient) {
  switch (ingredient.toLowerCase()) {
    case 'olive oil':
      return 'olive oil: use butter or neutral cooking oil';
    case 'spinach':
      return 'spinach: use kale, lettuce, or frozen greens';
    case 'rice':
      return 'rice: use quinoa or pasta';
    case 'pasta':
      return 'pasta: use rice or wrap strips';
    case 'chicken':
      return 'chicken: use tofu, beans, or egg';
    default:
      return '$ingredient: swap with a similar pantry item and adjust cook time';
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.recipe,
    required this.favoriteSelected,
    required this.pantryUpdateEnabled,
    required this.selectedRating,
    required this.deductionAmounts,
    required this.onFavoriteChanged,
    required this.onPantryUpdateChanged,
    required this.onRatingChanged,
    required this.onDeductionChanged,
    required this.onFinish,
    required this.onReviewPantry,
  });

  final Recipe recipe;
  final bool favoriteSelected;
  final bool pantryUpdateEnabled;
  final int selectedRating;
  final Map<String, double> deductionAmounts;
  final ValueChanged<bool> onFavoriteChanged;
  final ValueChanged<bool> onPantryUpdateChanged;
  final ValueChanged<int> onRatingChanged;
  final void Function(String itemId, double amount) onDeductionChanged;
  final VoidCallback onFinish;
  final VoidCallback onReviewPantry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pantryItems = context.watch<PantryBloc>().state.items;
    final matchedItems = _matchedPantryItems(recipe, pantryItems);

    return Scaffold(
      appBar: AppBar(title: const Text('Meal complete')),
      body: ListView(
        padding: const EdgeInsets.all(AppPadding.md),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppPadding.lg),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.check_circle,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: AppPadding.sm),
                  Text(
                    'You finished ${recipe.title}',
                    style: textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppPadding.xs),
                  Text(
                    'Log the cook, save the recipe if it is a keeper, and review pantry deductions before you leave.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppPadding.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppPadding.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Rate this cook', style: textTheme.titleMedium),
                  const SizedBox(height: AppPadding.sm),
                  Row(
                    children: List<Widget>.generate(5, (index) {
                      final star = index + 1;
                      return IconButton(
                        onPressed: () => onRatingChanged(star),
                        icon: Icon(
                          star <= selectedRating ? Icons.star : Icons.star_border,
                          color: star <= selectedRating
                              ? colorScheme.secondary
                              : colorScheme.outline,
                        ),
                        tooltip: '$star star${star == 1 ? '' : 's'}',
                      );
                    }),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: favoriteSelected,
                    onChanged: onFavoriteChanged,
                    title: const Text('Save as a household favorite'),
                    subtitle: const Text('Keep it easy to find for next time.'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppPadding.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppPadding.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Pantry deduction summary',
                          style: textTheme.titleMedium,
                        ),
                      ),
                      Switch.adaptive(
                        value: pantryUpdateEnabled,
                        onChanged: onPantryUpdateChanged,
                      ),
                    ],
                  ),
                  Text(
                    pantryUpdateEnabled
                        ? 'Adjust the pantry changes below before finishing.'
                        : 'Pantry update is off for this cook. You can still review the suggested changes.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppPadding.md),
                  if (matchedItems.isEmpty)
                    Text(
                      'No exact pantry matches were found for this recipe, so there is nothing to deduct automatically.',
                      style: textTheme.bodyMedium,
                    )
                  else
                    ...matchedItems.map((item) {
                      final amount = deductionAmounts[item.id] ??
                          (item.quantity >= 1 ? 1.0 : item.quantity);
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppPadding.sm),
                        padding: const EdgeInsets.all(AppPadding.md),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(item.name, style: textTheme.titleSmall),
                            const SizedBox(height: AppPadding.xs),
                            Text(
                              'Current: ${_formatQuantity(item.quantity)} ${item.unit} • Remaining: ${_formatQuantity((item.quantity - amount).clamp(0, item.quantity))} ${item.unit}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppPadding.sm),
                            Row(
                              children: <Widget>[
                                IconButton(
                                  onPressed: () => onDeductionChanged(
                                    item.id,
                                    _normalizedAmount(amount - 0.5, item.quantity),
                                  ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Expanded(
                                  child: Text(
                                    '${_formatQuantity(amount)} ${item.unit} to deduct',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => onDeductionChanged(
                                    item.id,
                                    _normalizedAmount(amount + 0.5, item.quantity),
                                  ),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppPadding.md,
          AppPadding.sm,
          AppPadding.md,
          AppPadding.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: onReviewPantry,
                child: const Text('Review pantry'),
              ),
            ),
            const SizedBox(width: AppPadding.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.done),
                label: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<PantryItem> _matchedPantryItems(
    Recipe recipe,
    List<PantryItem> pantryItems,
  ) {
    final ingredients = recipe.ingredients
        .map((ingredient) => ingredient.toLowerCase().trim())
        .where((ingredient) => ingredient.isNotEmpty)
        .toSet();

    return pantryItems.where((item) {
      return ingredients.contains(item.name.toLowerCase().trim());
    }).toList(growable: false);
  }

  static double _normalizedAmount(double value, double max) {
    if (value <= 0) {
      return 0;
    }
    if (value >= max) {
      return max;
    }
    return double.parse(value.toStringAsFixed(2));
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
