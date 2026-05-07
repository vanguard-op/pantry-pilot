import 'package:flutter/material.dart';

import '../../data/models/recipe.dart';
import '../../theme/app_theme.dart';

class RecipeSummaryCard extends StatelessWidget {
  const RecipeSummaryCard({
    super.key,
    required this.recipe,
    required this.onTap,
    required this.onFavoriteToggle,
    this.leadingLabel,
    this.trailingText,
    this.footer,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final String? leadingLabel;
  final String? trailingText;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppPadding.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppPadding.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: AppPadding.sm,
                          runSpacing: AppPadding.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            if (leadingLabel != null)
                              Text(
                                leadingLabel!,
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.secondary,
                                ),
                              ),
                            _RecipeOwnershipBadge(recipe: recipe),
                          ],
                        ),
                        const SizedBox(height: AppPadding.xs),
                        Text(recipe.title, style: textTheme.titleLarge),
                        const SizedBox(height: AppPadding.xs),
                        Text(
                          recipe.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppPadding.sm),
                  IconButton(
                    icon: Icon(
                      recipe.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: recipe.isFavorite ? colorScheme.tertiary : null,
                    ),
                    onPressed: onFavoriteToggle,
                    tooltip: recipe.isFavorite
                        ? 'Remove from favorites'
                        : 'Save to favorites',
                  ),
                ],
              ),
              const SizedBox(height: AppPadding.md),
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
                    label: recipe.difficulty,
                  ),
                  _RecipeMetaChip(
                    icon: Icons.shopping_basket_outlined,
                    label: '${recipe.ingredients.length} ingredients',
                  ),
                  _RecipeMetaChip(
                    icon: Icons.people_outline,
                    label: '${recipe.servings} servings',
                  ),
                ],
              ),
              if (recipe.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppPadding.md),
                Wrap(
                  spacing: AppPadding.sm,
                  runSpacing: AppPadding.sm,
                  children: recipe.tags
                      .take(3)
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (trailingText != null || footer != null) ...<Widget>[
                const SizedBox(height: AppPadding.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppPadding.md),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child:
                      footer ??
                      Text(trailingText!, style: textTheme.bodyMedium),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeOwnershipBadge extends StatelessWidget {
  const _RecipeOwnershipBadge({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (
      IconData icon,
      Color foreground,
      Color background,
    ) = switch (recipe.ownershipScope) {
      // Starter: free curated catalog.
      RecipeOwnershipScope.starter => (
        Icons.menu_book_outlined,
        colorScheme.primary,
        colorScheme.primaryContainer.withAlpha(110),
      ),
      // Plus: premium curated catalog.
      RecipeOwnershipScope.plus => (
        Icons.workspace_premium_outlined,
        const Color(0xFFB45309), // amber-700 for good contrast on light bg
        const Color(0xFFFEF3C7).withAlpha(200), // amber-50
      ),
      // Custom: account-owned recipe.
      RecipeOwnershipScope.custom => (
        Icons.edit_note_outlined,
        colorScheme.secondary,
        colorScheme.secondaryContainer.withAlpha(120),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppPadding.sm,
        vertical: AppPadding.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: AppPadding.xs),
          Text(
            recipe.ownershipLabel,
            style: textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
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
