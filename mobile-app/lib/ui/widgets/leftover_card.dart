import 'package:flutter/material.dart';

import '../../data/models/pantry_item.dart';
import '../../data/models/recommendations.dart';
import '../../theme/app_theme.dart';

/// A reusable card for a single leftover (cooked meal) pantry item.
///
/// Displays the item name, quantity, consume-by date, and a "Use soon" chip
/// when [item.daysUntilExpiry] is ≤ 3. Shows repurpose recipe suggestions
/// when available, and provides Mark used / Discard action buttons.
class LeftoverCard extends StatelessWidget {
  const LeftoverCard({
    super.key,
    required this.item,
    required this.onMarkUsed,
    required this.onDiscard,
    required this.onRecipeTap,
  });

  final PantryItem item;

  final VoidCallback onMarkUsed;
  final VoidCallback onDiscard;

  /// Called with the recipe id when the user taps a repurpose suggestion.
  final void Function(String recipeId) onRecipeTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isUseSoon = item.daysUntilExpiry <= 3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppPadding.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(item.name.trim(), style: textTheme.titleMedium),
                ),
                if (isUseSoon)
                  Chip(
                    label: const Text('Use soon'),
                    labelStyle: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onError,
                    ),
                    backgroundColor: colorScheme.error,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: AppPadding.xs),
            Text(
              '${item.quantity.toInt()} serving${item.quantity.toInt() == 1 ? '' : 's'} • Consume by ${item.expiryDate.toLocal().toString().split(' ').first}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppPadding.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMarkUsed,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark used'),
                  ),
                ),
                const SizedBox(width: AppPadding.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDiscard,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Discard'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
