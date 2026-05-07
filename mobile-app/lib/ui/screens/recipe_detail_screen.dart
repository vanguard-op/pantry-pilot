import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/planned_meal.dart';
import '../../data/models/recipe.dart';
import '../../data/models/recommendations.dart';
import '../../data/repositories/recommendation_repository.dart';
import '../../navigation/app_router.dart';
import '../../theme/app_theme.dart';
import '../widgets/api_status_banner.dart';
import '../widgets/substitution_hint_skeleton.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.plannedMealId,
  });

  final String recipeId;
  final String? plannedMealId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, SubstitutionHint> _substitutionHints =
      const <String, SubstitutionHint>{};
  bool _substitutionsLoading = false;
  bool _substitutionsError = false;

  /// Maps missing ingredient name → accepted pantry substitute display name.
  /// Updated when the user taps "Accept" in the swap bottom sheet.
  final Map<String, String> _acceptedSubstitutes = <String, String>{};
  late Future<PantryCoverage> _coverageFuture;

  @override
  void initState() {
    super.initState();
    _coverageFuture = _fetchCoverage();
  }

  /// Fetches pantry coverage from the backend, then automatically chains
  /// a substitution-hints fetch for any missing ingredients.
  Future<PantryCoverage> _fetchCoverage() {
    final repo = context.read<RecommendationRepository>();
    return repo.fetchPantryCoverage(widget.recipeId).then((coverage) {
      if (coverage.missingIngredients.isNotEmpty) {
        if (mounted) {
          setState(() {
            _substitutionsLoading = true;
            _substitutionsError = false;
          });
        }
        repo
            .fetchSubstitutionHints(coverage.missingIngredients)
            .then((hints) {
              if (mounted) {
                setState(() {
                  _substitutionHints = hints;
                  _substitutionsLoading = false;
                  _substitutionsError = false;
                  // Drop any previously accepted substitutes whose ingredient
                  // is no longer reported as missing after a retry.
                  _acceptedSubstitutes.removeWhere(
                    (ingredient, _) =>
                        !coverage.missingIngredients.contains(ingredient),
                  );
                });
              }
            })
            .catchError((_) {
              if (mounted) {
                setState(() {
                  _substitutionsLoading = false;
                  _substitutionsError = true;
                });
              }
            });
      } else if (mounted) {
        setState(() {
          _substitutionsLoading = false;
          _substitutionsError = false;
          _substitutionHints = const <String, SubstitutionHint>{};
        });
      }
      return coverage;
    });
  }

  /// Resets all async state and retries coverage + hints fetches.
  void _retryAll() {
    setState(() {
      _substitutionHints = const <String, SubstitutionHint>{};
      _substitutionsLoading = false;
      _substitutionsError = false;
      _acceptedSubstitutes.clear();
      _coverageFuture = _fetchCoverage();
    });
  }

  /// Opens a bottom sheet that lets the user pick a pantry substitute for
  /// [ingredient]. If pantry options exist they are shown as selectable chips;
  /// the fallback text hint is always shown below.
  void _showSwapSheet(BuildContext context, String ingredient) {
    final hint = _substitutionHints[ingredient];
    final subs = hint?.pantrySubstitutes ?? const <PantrySubstituteOption>[];
    final hintText =
        hint?.hint ??
        '$ingredient: swap with a similar pantry item and adjust cook time';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentAccepted = _acceptedSubstitutes[ingredient];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        // StatefulBuilder so chip selection state is local to the sheet.
        String? selectedSub = currentAccepted;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppPadding.lg,
                AppPadding.md,
                AppPadding.lg,
                AppPadding.lg + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppPadding.md),
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Swap ingredient', style: textTheme.titleLarge),
                  const SizedBox(height: AppPadding.xs),
                  Text(
                    ingredient,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppPadding.md),
                  if (subs.isNotEmpty) ...<Widget>[
                    Text('In your pantry', style: textTheme.labelLarge),
                    const SizedBox(height: AppPadding.sm),
                    Wrap(
                      spacing: AppPadding.sm,
                      runSpacing: AppPadding.sm,
                      children: subs
                          .map(
                            (sub) => ChoiceChip(
                              label: Text(sub.pantryItemName),
                              selected: selectedSub == sub.pantryItemName,
                              onSelected: (_) => setSheetState(
                                () => selectedSub = sub.pantryItemName,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppPadding.md),
                  ],
                  Text('Tip', style: textTheme.labelLarge),
                  const SizedBox(height: AppPadding.xs),
                  Text(hintText, style: textTheme.bodyMedium),
                  const SizedBox(height: AppPadding.lg),
                  Row(
                    children: <Widget>[
                      if (currentAccepted != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(
                                () => _acceptedSubstitutes.remove(ingredient),
                              );
                              Navigator.of(sheetContext).pop();
                            },
                            child: const Text('Undo'),
                          ),
                        ),
                      if (currentAccepted != null)
                        const SizedBox(width: AppPadding.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: selectedSub == null
                              ? null
                              : () {
                                  setState(
                                    () => _acceptedSubstitutes[ingredient] =
                                        selectedSub!,
                                  );
                                  Navigator.of(sheetContext).pop();
                                },
                          child: Text(
                            selectedSub == null
                                ? 'Select a substitute'
                                : 'Accept substitute',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final recipes = context.watch<RecipesBloc>().state.recipes;

    Recipe? recipe;
    for (final current in recipes) {
      if (current.id == widget.recipeId) {
        recipe = current;
        break;
      }
    }

    if (recipe == null) {
      return const Scaffold(body: Center(child: Text('Recipe not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              context.read<RecipesBloc>().add(
                RecipeFavoriteToggled(widget.recipeId),
              );
            },
            icon: Icon(
              recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: recipe.isFavorite ? colorScheme.tertiary : null,
            ),
            tooltip: recipe.isFavorite
                ? 'Remove from favorites'
                : 'Save to favorites',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppPadding.md),
        children: <Widget>[
          // ── Recipe meta ─────────────────────────────────────────────
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppPadding.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: AppPadding.sm,
                    runSpacing: AppPadding.sm,
                    children: <Widget>[
                      _RecipeMetaChip(
                        icon: Icons.schedule_outlined,
                        label: '${recipe.totalMinutes} min',
                      ),
                      _RecipeMetaChip(
                        icon: Icons.restaurant_outlined,
                        label: '${recipe.servings} servings',
                      ),
                      _RecipeMetaChip(
                        icon: Icons.local_fire_department_outlined,
                        label: recipe.difficulty,
                      ),
                      _RecipeMetaChip(
                        icon: switch (recipe.ownershipScope) {
                          RecipeOwnershipScope.starter =>
                            Icons.menu_book_outlined,
                          RecipeOwnershipScope.plus =>
                            Icons.workspace_premium_outlined,
                          RecipeOwnershipScope.custom =>
                            Icons.edit_note_outlined,
                        },
                        label: recipe.ownershipLabel,
                      ),
                    ],
                  ),
                  if (recipe.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppPadding.md),
                    Wrap(
                      spacing: AppPadding.sm,
                      runSpacing: AppPadding.sm,
                      children: recipe.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: AppPadding.md),
                  Text(
                    recipe.description,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppPadding.md),
          // ── Pantry coverage (backend-driven) ─────────────────────────
          FutureBuilder<PantryCoverage>(
            future: _coverageFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ApiStatusBanner(
                  message: 'Could not load pantry coverage',
                  subtitle: 'Check your connection and try again.',
                  onRetry: _retryAll,
                );
              }

              if (!snapshot.hasData) {
                return const Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(AppPadding.lg),
                    child: LinearProgressIndicator(),
                  ),
                );
              }

              final coverage = snapshot.data!;
              final availableSet = coverage.availableIngredients
                  .map((e) => e.toLowerCase())
                  .toSet();

              // Client-side coverage adjusted for accepted substitutes.
              // Each accepted substitute counts as one additional matched ingredient.
              final effectiveMatched =
                  coverage.matchedCount + _acceptedSubstitutes.length;
              final effectivePercent = coverage.totalCount == 0
                  ? 100
                  : ((effectiveMatched / coverage.totalCount) * 100)
                        .round()
                        .clamp(0, 100);
              final allCovered = effectiveMatched >= coverage.totalCount;

              return Column(
                children: <Widget>[
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
                                  'Pantry coverage',
                                  style: textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                '$effectivePercent%',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: allCovered
                                      ? colorScheme.primary
                                      : colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppPadding.xs),
                          Text(
                            allCovered
                                ? 'You have everything needed for this recipe.'
                                : '$effectiveMatched of ${coverage.totalCount} ingredients are ready or substituted.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppPadding.md),
                          ...recipe!.ingredients.map((ingredient) {
                            final available = availableSet.contains(
                              ingredient.toLowerCase(),
                            );
                            final acceptedSub =
                                _acceptedSubstitutes[ingredient];
                            final isSubstituted =
                                !available && acceptedSub != null;

                            // Determine row colour/icon based on status.
                            final rowColor = available
                                ? colorScheme.primaryContainer.withAlpha(120)
                                : isSubstituted
                                ? colorScheme.secondaryContainer.withAlpha(120)
                                : colorScheme.surfaceContainerHighest;
                            final statusIcon = available
                                ? Icons.check_circle_outline
                                : isSubstituted
                                ? Icons.swap_horiz
                                : Icons.remove_circle_outline;
                            final statusColor = available
                                ? colorScheme.primary
                                : isSubstituted
                                ? colorScheme.secondary
                                : colorScheme.tertiary;
                            final statusLabel = available
                                ? 'Ready'
                                : isSubstituted
                                ? 'Substituted'
                                : 'Missing';

                            return Container(
                              margin: const EdgeInsets.only(
                                bottom: AppPadding.sm,
                              ),
                              decoration: BoxDecoration(
                                color: rowColor,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: InkWell(
                                // Tapping a missing or substituted ingredient
                                // opens the swap sheet to change the selection.
                                onTap: available
                                    ? null
                                    : () => _showSwapSheet(context, ingredient),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppPadding.md,
                                    vertical: AppPadding.sm,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        statusIcon,
                                        size: 18,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: AppPadding.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              ingredient,
                                              style: textTheme.bodyMedium,
                                            ),
                                            if (isSubstituted)
                                              Text(
                                                'Using $acceptedSub',
                                                style: textTheme.labelSmall
                                                    ?.copyWith(
                                                      color:
                                                          colorScheme.secondary,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        statusLabel,
                                        style: textTheme.labelMedium?.copyWith(
                                          color: statusColor,
                                        ),
                                      ),
                                      if (!available)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: AppPadding.xs,
                                          ),
                                          child: Icon(
                                            Icons.chevron_right,
                                            size: 16,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  // ── Substitutions ────────────────────────────────────
                  if (coverage.missingIngredients.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppPadding.md),
                    if (_substitutionsError)
                      ApiStatusBanner(
                        message: 'Could not load substitution hints',
                        onRetry: _retryAll,
                      )
                    else
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(AppPadding.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Substitutions',
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppPadding.sm),
                              ...coverage.missingIngredients.map((ingredient) {
                                final hint = _substitutionHints[ingredient];
                                final acceptedSub =
                                    _acceptedSubstitutes[ingredient];
                                final showSkeleton =
                                    _substitutionsLoading && hint == null;

                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppPadding.md,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Icon(
                                            acceptedSub != null
                                                ? Icons.check_circle_outline
                                                : Icons.swap_horiz,
                                            size: 16,
                                            color: acceptedSub != null
                                                ? colorScheme.secondary
                                                : colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: AppPadding.sm),
                                          Expanded(
                                            child: Text(
                                              ingredient,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                          if (acceptedSub != null)
                                            TextButton(
                                              onPressed: () => setState(
                                                () => _acceptedSubstitutes
                                                    .remove(ingredient),
                                              ),
                                              style: TextButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: const Text('Undo'),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: AppPadding.xs),
                                      if (acceptedSub != null)
                                        // Show which pantry item was accepted.
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppPadding.sm,
                                            vertical: AppPadding.xs,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme
                                                .secondaryContainer
                                                .withAlpha(160),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Icon(
                                                Icons.kitchen_outlined,
                                                size: 14,
                                                color: colorScheme
                                                    .onSecondaryContainer,
                                              ),
                                              const SizedBox(
                                                width: AppPadding.xs,
                                              ),
                                              Text(
                                                'Using $acceptedSub',
                                                style: textTheme.labelSmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSecondaryContainer,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (showSkeleton)
                                        const SubstitutionHintSkeleton()
                                      else ...<Widget>[
                                        // Show pantry-sourced chips if available,
                                        // with a fallback to the text hint.
                                        if (hint != null &&
                                            hint
                                                .pantrySubstitutes
                                                .isNotEmpty) ...<Widget>[
                                          Text(
                                            'In your pantry:',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: AppPadding.xs),
                                          Wrap(
                                            spacing: AppPadding.sm,
                                            runSpacing: AppPadding.xs,
                                            children: hint.pantrySubstitutes
                                                .map(
                                                  (sub) => ActionChip(
                                                    avatar: const Icon(
                                                      Icons.swap_horiz,
                                                      size: 16,
                                                    ),
                                                    label: Text(
                                                      sub.pantryItemName,
                                                    ),
                                                    onPressed: () => setState(
                                                      () =>
                                                          _acceptedSubstitutes[ingredient] =
                                                              sub.pantryItemName,
                                                    ),
                                                  ),
                                                )
                                                .toList(growable: false),
                                          ),
                                          const SizedBox(height: AppPadding.xs),
                                        ],
                                        Text(
                                          hint?.hint ??
                                              '$ingredient: swap with a similar pantry item and adjust cook time',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: AppPadding.xs),
                                        // Only show the full swap sheet button
                                        // when no pantry chip shortcuts exist.
                                        if (hint == null ||
                                            hint.pantrySubstitutes.isEmpty)
                                          TextButton.icon(
                                            onPressed: () => _showSwapSheet(
                                              context,
                                              ingredient,
                                            ),
                                            icon: const Icon(
                                              Icons.swap_horiz,
                                              size: 16,
                                            ),
                                            label: const Text('Swap'),
                                            style: TextButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppPadding.md),
          // ── Steps ────────────────────────────────────────────────────
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppPadding.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Steps', style: textTheme.titleMedium),
                  const SizedBox(height: AppPadding.sm),
                  ...recipe.steps.asMap().entries.map((entry) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppPadding.sm),
                      padding: const EdgeInsets.all(AppPadding.md),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                            child: Text('${entry.key + 1}'),
                          ),
                          const SizedBox(width: AppPadding.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.value.description,
                                  style: textTheme.bodyLarge,
                                ),
                                const SizedBox(height: AppPadding.xs),
                                Text(
                                  '${entry.value.durationMinutes} min',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
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
              child: OutlinedButton.icon(
                onPressed: () => _showAddToPlanDialog(context, recipe!),
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Add to plan'),
              ),
            ),
            const SizedBox(width: AppPadding.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  if (widget.plannedMealId == null) {
                    context.pushNamed(
                      AppRouter.recipeCookName,
                      pathParameters: <String, String>{
                        AppRouter.recipeIdParam: widget.recipeId,
                      },
                    );
                    return;
                  }

                  context.pushNamed(
                    AppRouter.recipeCookName,
                    pathParameters: <String, String>{
                      AppRouter.recipeIdParam: widget.recipeId,
                    },
                    queryParameters: <String, dynamic>{
                      'plannedMealId': widget.plannedMealId!,
                    },
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start cooking'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddToPlanDialog(BuildContext context, Recipe recipe) async {
    DateTime selectedDate = DateTime.now();
    String selectedSlot = 'Dinner';

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Add to weekly plan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(recipe.title),
                  const SizedBox(height: AppPadding.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked == null) {
                        return;
                      }
                      setState(() => selectedDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Date: ${selectedDate.toLocal().toString().split(' ').first}',
                    ),
                  ),
                  const SizedBox(height: AppPadding.md),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSlot,
                    decoration: const InputDecoration(labelText: 'Meal slot'),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'Breakfast',
                        child: Text('Breakfast'),
                      ),
                      DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'Dinner', child: Text('Dinner')),
                    ],
                    onChanged: (value) {
                      setState(() => selectedSlot = value ?? 'Dinner');
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Add meal'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true || !context.mounted) {
      return;
    }

    final normalizedDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    context.read<PlannerBloc>().add(
      PlannedMealAdded(
        PlannedMeal(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          recipeId: recipe.id,
          date: normalizedDate,
          slot: selectedSlot,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${recipe.title} added for ${normalizedDate.toString().split(' ').first} ($selectedSlot)',
        ),
      ),
    );
  }
}

class _RecipeMetaChip extends StatelessWidget {
  const _RecipeMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppPadding.md,
        vertical: AppPadding.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: AppPadding.xs),
          Text(label, style: textTheme.labelLarge),
        ],
      ),
    );
  }
}
