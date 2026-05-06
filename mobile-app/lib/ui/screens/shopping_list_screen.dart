import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../blocs/recipes/recipes_bloc.dart';
import '../../data/models/pantry_item.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final Set<String> _checkedItems = <String>{};
  final Map<String, double> _purchaseQuantities = <String, double>{};
  final TextEditingController _customItemController = TextEditingController();
  final List<String> _customItems = <String>[];

  @override
  void dispose() {
    _customItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantryItems = context.watch<PantryBloc>().state.items;
    final plannedMeals = context.watch<PlannerBloc>().state.meals;
    final recipes = context.watch<RecipesBloc>().state.recipes;

    final pantrySet = pantryItems
        .map((item) => item.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    final recipeById = {for (final recipe in recipes) recipe.id: recipe};

    final missingCounts = <String, int>{};
    for (final meal in plannedMeals) {
      final recipe = recipeById[meal.recipeId];
      if (recipe == null) {
        continue;
      }
      for (final ingredient in recipe.ingredients) {
        final normalized = ingredient.trim().toLowerCase();
        if (normalized.isEmpty || pantrySet.contains(normalized)) {
          continue;
        }
        missingCounts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final generatedItems = missingCounts.keys.toList(growable: false)..sort();
    final allItems = <String>[...generatedItems, ..._customItems];

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _customItemController,
                    decoration: const InputDecoration(
                      labelText: 'Add custom item',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addCustomItem(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addCustomItem,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _checkedItems.isEmpty
                    ? null
                    : () => _showBoughtItemsSyncDialog(context),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Add Bought Items to Pantry'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: allItems.isEmpty
                ? const Center(
                    child: Text('No missing ingredients for your current plan.'),
                  )
                : ListView.builder(
                    itemCount: allItems.length,
                    itemBuilder: (context, index) {
                      final item = allItems[index];
                      final checked = _checkedItems.contains(item);
                      final plannedCount = missingCounts[item];

                      return CheckboxListTile(
                        value: checked,
                        title: Text(item),
                        subtitle: plannedCount == null
                            ? const Text('Custom item')
                            : Text('Needed for $plannedCount planned meal(s)'),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() {
                              _checkedItems.remove(item);
                              _customItems.remove(item);
                            });
                          },
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _checkedItems.add(item);
                              _purchaseQuantities.putIfAbsent(item, () => 1.0);
                            } else {
                              _checkedItems.remove(item);
                              _purchaseQuantities.remove(item);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addCustomItem() {
    final value = _customItemController.text.trim().toLowerCase();
    if (value.isEmpty) {
      return;
    }

    setState(() {
      if (!_customItems.contains(value)) {
        _customItems.add(value);
      }
      _customItemController.clear();
    });
  }

  Future<void> _showBoughtItemsSyncDialog(BuildContext context) async {
    final selectedItems = _checkedItems.toList(growable: false)..sort();
    if (selectedItems.isEmpty) {
      return;
    }

    final controllers = <String, TextEditingController>{
      for (final item in selectedItems)
        item: TextEditingController(
          text: (_purchaseQuantities[item] ?? 1.0).toStringAsFixed(1),
        ),
    };

    final shouldSync = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm bought quantities'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: selectedItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controllers[item],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: item,
                        helperText: 'Quantity purchased',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sync to pantry'),
            ),
          ],
        );
      },
    );

    if (shouldSync != true || !context.mounted) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      return;
    }

    final confirmed = <String, double>{};
    for (final item in selectedItems) {
      final raw = controllers[item]?.text.trim() ?? '';
      final parsed = double.tryParse(raw);
      if (parsed != null && parsed > 0) {
        confirmed[item] = parsed;
      }
    }

    for (final controller in controllers.values) {
      controller.dispose();
    }

    if (confirmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one valid quantity.')),
      );
      return;
    }

    _syncBoughtItemsToPantry(context, confirmed);
  }

  void _syncBoughtItemsToPantry(BuildContext context, Map<String, double> bought) {
    final pantryBloc = context.read<PantryBloc>();
    final pantryItems = pantryBloc.state.items;
    final now = DateTime.now();
    var createCounter = 0;

    for (final entry in bought.entries) {
      final normalizedName = entry.key.trim().toLowerCase();
      if (normalizedName.isEmpty) {
        continue;
      }

      PantryItem? existing;
      for (final item in pantryItems) {
        if (item.name.trim().toLowerCase() == normalizedName) {
          existing = item;
          break;
        }
      }

      if (existing != null) {
        pantryBloc.add(
          PantryItemUpdated(
            existing.copyWith(quantity: existing.quantity + entry.value),
          ),
        );
        continue;
      }

      pantryBloc.add(
        PantryItemAdded(
          PantryItem(
            id: '${now.microsecondsSinceEpoch}_${createCounter++}',
            name: entry.key,
            quantity: entry.value,
            unit: 'pcs',
            storageLocation: 'Pantry',
            expiryDate: now.add(const Duration(days: 14)),
            lowStockThreshold: 1,
          ),
        ),
      );
    }

    setState(() {
      _purchaseQuantities.addAll(bought);
      for (final key in bought.keys) {
        _checkedItems.remove(key);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${bought.length} bought item(s) synced to pantry')),
    );
  }
}
