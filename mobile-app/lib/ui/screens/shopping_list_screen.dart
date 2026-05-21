import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';
import '../../data/models/shopping_list_item.dart';
import '../../data/repositories/shopping_repository.dart';
import '../../theme/app_theme.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  static const List<String> _categoryOrder = <String>[
    'Produce',
    'Protein',
    'Dairy',
    'Grains',
    'Pantry Staples',
    'Other',
    'Custom',
  ];

  static const Map<String, List<String>> _categoryKeywordMap =
      <String, List<String>>{
        'Produce': <String>[
          'spinach',
          'lettuce',
          'tomato',
          'onion',
          'garlic',
          'pepper',
          'carrot',
          'kale',
          'potato',
          'broccoli',
          'cucumber',
          'lemon',
          'lime',
          'avocado',
          'mushroom',
          'zucchini',
          'corn',
          'celery',
          'cabbage',
          'apple',
          'banana',
        ],
        'Protein': <String>[
          'chicken',
          'beef',
          'pork',
          'tofu',
          'egg',
          'beans',
          'lentil',
          'fish',
          'salmon',
          'tuna',
          'shrimp',
        ],
        'Dairy': <String>[
          'milk',
          'butter',
          'cheese',
          'yogurt',
          'cream',
          'ghee',
        ],
        'Grains': <String>[
          'rice',
          'pasta',
          'bread',
          'quinoa',
          'oats',
          'flour',
          'noodle',
          'tortilla',
        ],
        'Pantry Staples': <String>[
          'olive oil',
          'oil',
          'salt',
          'sugar',
          'vinegar',
          'soy sauce',
          'stock',
          'broth',
          'spice',
          'paprika',
          'cumin',
        ],
      };

  final Set<String> _checkedItems = <String>{};
  final Map<String, double> _purchaseQuantities = <String, double>{};
  final TextEditingController _customItemController = TextEditingController();
  final List<String> _customItems = <String>[];
  List<ShoppingListItem> _generatedItems = const <ShoppingListItem>[];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadShoppingList();
  }

  @override
  void dispose() {
    _customItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plannedMeals = context.watch<PlannerBloc>().state.meals;
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weeklyPlannedMeals = plannedMeals
        .where((meal) {
          return !meal.date.isBefore(weekStart) && meal.date.isBefore(weekEnd);
        })
        .toList(growable: false);

    final missingCounts = <String, int>{
      for (final item in _generatedItems) item.name: item.neededForMeals,
    };
    final itemUnits = <String, String>{
      for (final item in _generatedItems) item.name: item.unit,
      for (final item in _customItems) item: 'pcs',
    };
    final generatedItems = _generatedItems
        .map((item) => item.name)
        .toList(growable: false);
    final allItems = <String>{
      ...generatedItems,
      ..._customItems,
    }.toList(growable: false)..sort();
    final groupedItems = _groupShoppingItems(allItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh list',
            onPressed: _isLoading ? null : _loadShoppingList,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Export list',
            onPressed: allItems.isEmpty
                ? null
                : () => _exportListToClipboard(
                    context,
                    groupedItems: groupedItems,
                    missingCounts: missingCounts,
                    weeklyMealCount: weeklyPlannedMeals.length,
                  ),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppPadding.md,
              AppPadding.md,
              AppPadding.md,
              AppPadding.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${weeklyPlannedMeals.length} meals in this week\'s plan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${generatedItems.length} missing ingredients',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppPadding.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _customItemController,
                    decoration: const InputDecoration(
                      labelText: 'Add custom item',
                    ),
                    onSubmitted: (_) => _addCustomItem(),
                  ),
                ),
                const SizedBox(width: AppPadding.sm),
                FilledButton(
                  onPressed: _addCustomItem,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppPadding.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _checkedItems.isEmpty || _isSyncing
                    ? null
                    : () => _syncSelectedBoughtItems(context, itemUnits),
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(
                  _isSyncing
                      ? 'Syncing to Pantry...'
                      : 'Add Bought Items to Pantry',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppPadding.sm),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppPadding.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: AppPadding.sm),
                          FilledButton(
                            onPressed: _loadShoppingList,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : allItems.isEmpty
                ? const Center(
                    child: Text(
                      'No missing ingredients for your current plan.',
                    ),
                  )
                : ListView(
                    children: groupedItems.entries
                        .map((entry) {
                          final category = entry.key;
                          final items = entry.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppPadding.md,
                                  AppPadding.sm,
                                  AppPadding.md,
                                  AppPadding.xs,
                                ),
                                child: Text(
                                  category,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              ...items.map((item) {
                                final checked = _checkedItems.contains(item);
                                final plannedCount = missingCounts[item];
                                final quantity =
                                    _purchaseQuantities[item] ?? 1.0;
                                final unit = itemUnits[item] ?? 'pcs';

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AppPadding.md,
                                    vertical: AppPadding.xs,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppPadding.sm,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Text(
                                                    item,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.titleMedium,
                                                  ),
                                                  const SizedBox(
                                                    height: AppPadding.xs,
                                                  ),
                                                  Text(
                                                    plannedCount == null
                                                        ? 'Custom item'
                                                        : 'Needed for $plannedCount planned meal(s)',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _checkedItems.remove(item);
                                                  _purchaseQuantities.remove(
                                                    item,
                                                  );
                                                  _customItems.remove(item);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppPadding.sm),
                                        Row(
                                          children: <Widget>[
                                            Checkbox(
                                              value: checked,
                                              onChanged: (value) {
                                                setState(() {
                                                  if (value == true) {
                                                    _checkedItems.add(item);
                                                    _purchaseQuantities
                                                        .putIfAbsent(
                                                          item,
                                                          () => quantity,
                                                        );
                                                  } else {
                                                    _checkedItems.remove(item);
                                                  }
                                                });
                                              },
                                            ),
                                            const Text('Mark as bought'),
                                            const Spacer(),
                                            IconButton(
                                              tooltip: 'Decrease quantity',
                                              onPressed: () => _adjustQuantity(
                                                item,
                                                delta: -1,
                                              ),
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 52,
                                              child: Text(
                                                _formatQuantity(quantity),
                                                textAlign: TextAlign.center,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleSmall,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Increase quantity',
                                              onPressed: () => _adjustQuantity(
                                                item,
                                                delta: 1,
                                              ),
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: AppPadding.sm,
                                                    vertical: AppPadding.xs,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                unit,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        })
                        .toList(growable: false),
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
      _purchaseQuantities.putIfAbsent(value, () => 1.0);
      _customItemController.clear();
    });
  }

  void _adjustQuantity(String item, {required double delta}) {
    final current = _purchaseQuantities[item] ?? 1.0;
    final next = current + delta;
    if (next < 1) {
      return;
    }

    setState(() {
      _purchaseQuantities[item] = next;
    });
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  Future<void> _syncSelectedBoughtItems(
    BuildContext context,
    Map<String, String> itemUnits,
  ) async {
    final bought = <String, double>{
      for (final item in _checkedItems)
        if ((_purchaseQuantities[item] ?? 0) > 0)
          item: _purchaseQuantities[item] ?? 1.0,
    };

    if (bought.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to sync.')),
      );
      return;
    }

    await _syncBoughtItemsToPantry(context, bought, itemUnits);
  }

  Future<void> _syncBoughtItemsToPantry(
    BuildContext context,
    Map<String, double> bought,
    Map<String, String> itemUnits,
  ) async {
    final shoppingRepository = context.read<ShoppingRepository>();
    final pantryBloc = context.read<PantryBloc>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSyncing = true;
    });

    try {
      await shoppingRepository.syncBoughtItems(bought, itemUnits);
      if (!mounted) {
        return;
      }
      pantryBloc.add(const PantryRefreshed());
      await _loadShoppingList();
      if (!mounted) {
        return;
      }

      setState(() {
        _purchaseQuantities.addAll(bought);
        for (final key in bought.keys) {
          _checkedItems.remove(key);
        }
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('${bought.length} bought item(s) synced to pantry'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _loadShoppingList() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final shoppingRepository = context.read<ShoppingRepository>();
      final items = await shoppingRepository.getShoppingList(days: 7);
      if (!mounted) {
        return;
      }
      setState(() {
        _generatedItems = items;
        final activeNames = <String>{
          ...items.map((item) => item.name),
          ..._customItems,
        };
        _purchaseQuantities.removeWhere((key, _) => !activeNames.contains(key));
        for (final item in items) {
          _purchaseQuantities.putIfAbsent(
            item.name,
            () => item.suggestedQuantity,
          );
        }
        _checkedItems.removeWhere((key) => !activeNames.contains(key));
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Map<String, List<String>> _groupShoppingItems(List<String> items) {
    final grouped = <String, List<String>>{};
    for (final item in items) {
      final category = _categoryForItem(item);
      grouped.putIfAbsent(category, () => <String>[]).add(item);
    }

    final sortedEntries = grouped.entries.toList(growable: false)
      ..sort((a, b) {
        final leftIndex = _categoryOrder.indexOf(a.key);
        final rightIndex = _categoryOrder.indexOf(b.key);
        if (leftIndex == -1 || rightIndex == -1) {
          return a.key.compareTo(b.key);
        }
        return leftIndex.compareTo(rightIndex);
      });

    return {
      for (final entry in sortedEntries)
        entry.key: (entry.value.toList(growable: false)..sort()),
    };
  }

  String _categoryForItem(String item) {
    if (_customItems.contains(item)) {
      return 'Custom';
    }

    for (final category in _categoryOrder) {
      final keywords = _categoryKeywordMap[category];
      if (keywords == null) {
        continue;
      }
      if (keywords.any((keyword) => item.contains(keyword))) {
        return category;
      }
    }

    return 'Other';
  }

  Future<void> _exportListToClipboard(
    BuildContext context, {
    required Map<String, List<String>> groupedItems,
    required Map<String, int> missingCounts,
    required int weeklyMealCount,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('PantryPilot shopping list');
    buffer.writeln('Meals in plan this week: $weeklyMealCount');
    buffer.writeln('');

    for (final entry in groupedItems.entries) {
      buffer.writeln('${entry.key}:');
      for (final item in entry.value) {
        final count = missingCounts[item];
        if (count == null) {
          buffer.writeln('- $item');
        } else {
          buffer.writeln('- $item ($count meal${count == 1 ? '' : 's'})');
        }
      }
      buffer.writeln('');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shopping list copied to clipboard')),
    );
  }
}
