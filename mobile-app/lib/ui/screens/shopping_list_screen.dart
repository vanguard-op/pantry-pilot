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
                onPressed: _checkedItems.isEmpty
                    ? null
                    : () => _showBoughtItemsSyncDialog(context),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Add Bought Items to Pantry'),
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

                                return CheckboxListTile(
                                  value: checked,
                                  title: Text(item),
                                  subtitle: plannedCount == null
                                      ? const Text('Custom item')
                                      : Text(
                                          'Needed for $plannedCount planned meal(s)',
                                        ),
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
                                        _purchaseQuantities.putIfAbsent(
                                          item,
                                          () => 1.0,
                                        );
                                      } else {
                                        _checkedItems.remove(item);
                                        _purchaseQuantities.remove(item);
                                      }
                                    });
                                  },
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
                children: selectedItems
                    .map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppPadding.md),
                        child: TextField(
                          controller: controllers[item],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: item,
                            helperText: 'Quantity purchased',
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
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

    await _syncBoughtItemsToPantry(context, confirmed);
  }

  Future<void> _syncBoughtItemsToPantry(
    BuildContext context,
    Map<String, double> bought,
  ) async {
    final shoppingRepository = context.read<ShoppingRepository>();
    final pantryBloc = context.read<PantryBloc>();
    final messenger = ScaffoldMessenger.of(context);

    await shoppingRepository.syncBoughtItems(bought);
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
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load shopping list from server.';
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
