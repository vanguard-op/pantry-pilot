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
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, String> _substitutionHints = const <String, String>{};
  bool _substitutionsLoading = false;
  bool _substitutionsError = false;
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
            });
          }
        }).catchError((_) {
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
          _substitutionHints = const <String, String>{};
        });
      }
      return coverage;
    });
  }

  /// Resets all async state and retries coverage + hints fetches.
  void _retryAll() {
    setState(() {
      _substitutionHints = const <String, String>{};
      _substitutionsLoading = false;
      _substitutionsError = false;
      _coverageFuture = _fetchCoverage();
    });
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
              context.read<RecipesBloc>().add(RecipeFavoriteToggled(widget.recipeId));
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
                                '${coverage.coveragePercent}%',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: coverage.missingIngredients.isEmpty
                                      ? colorScheme.primary
                                      : colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppPadding.xs),
                          Text(
                            coverage.missingIngredients.isEmpty
                                ? 'You already have everything needed for this recipe.'
                                : '${coverage.matchedCount} of ${coverage.totalCount} ingredients are already in your pantry.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppPadding.md),
                          ...recipe!.ingredients.map((ingredient) {
                            final available =
                                availableSet.contains(ingredient.toLowerCase());
                            return Container(
                              margin:
                                  const EdgeInsets.only(bottom: AppPadding.sm),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppPadding.md,
                                vertical: AppPadding.sm,
                              ),
                              decoration: BoxDecoration(
                                color: available
                                    ? colorScheme.primaryContainer.withAlpha(120)
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    available
                                        ? Icons.check_circle_outline
                                        : Icons.remove_circle_outline,
                                    size: 18,
                                    color: available
                                        ? colorScheme.primary
                                        : colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: AppPadding.sm),
                                  Expanded(
                                    child: Text(
                                      ingredient,
                                      style: textTheme.bodyMedium,
                                    ),
                                  ),
                                  Text(
                                    available ? 'Ready' : 'Missing',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: available
                                          ? colorScheme.primary
                                          : colorScheme.tertiary,
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
                  // ── Quick substitutions ──────────────────────────────
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
                                'Quick substitutions',
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppPadding.sm),
                              ...coverage.missingIngredients.map((ingredient) {
                                final hasHint = _substitutionHints.containsKey(ingredient);
                                final showSkeleton = _substitutionsLoading && !hasHint;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppPadding.sm,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.swap_horiz,
                                          size: 16,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: AppPadding.sm),
                                      Expanded(
                                        child: showSkeleton
                                            ? const SubstitutionHintSkeleton()
                                            : Text(
                                                _substitutionHints[ingredient] ??
                                                    '$ingredient: swap with a similar pantry item and adjust cook time',
                                                style: textTheme.bodyMedium,
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
                onPressed: () => context.pushNamed(
                  AppRouter.recipeCookName,
                  pathParameters: <String, String>{
                    AppRouter.recipeIdParam: widget.recipeId,
                  },
                ),
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
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
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
