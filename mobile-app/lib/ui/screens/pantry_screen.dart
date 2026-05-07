import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/core/async_state.dart';
import '../../blocs/pantry/pantry_bloc.dart';
import '../../data/models/pantry_item.dart';
import '../../theme/app_theme.dart';
import '../widgets/api_status_banner.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  static const _unitOptions = <String>[
    'pcs',
    'g',
    'kg',
    'ml',
    'l',
    'pack',
    'can',
    'bottle',
  ];

  static const _storageOptions = <String>['Fridge', 'Freezer', 'Pantry shelf'];

  static const _storageAliases = <String, String>{
    'fridge': 'Fridge',
    'freezer': 'Freezer',
    'shelf': 'Pantry shelf',
    'pantry': 'Pantry shelf',
    'pantry shelf': 'Pantry shelf',
    'counter': 'Pantry shelf',
  };

  String _canonicalStorage(String value) {
    final normalized = value.trim().toLowerCase();
    return _storageAliases[normalized] ?? 'Pantry shelf';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PantryBloc>().state;
    final items = state.items;
    final useSoonItems = state.useSoonItems;
    final grouped = <String, List<PantryItem>>{
      for (final storage in _storageOptions) storage: <PantryItem>[],
    };
    for (final item in items) {
      grouped[_canonicalStorage(item.storageLocation)]!.add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pantry Inventory')),
      body: BlocListener<PantryBloc, PantryState>(
        listenWhen: (previous, current) {
          final status = current.requestStatus;
          return status is SuccessStatus<void> &&
              previous.requestStatus != current.requestStatus;
        },
        listener: (context, current) {
          final status = current.requestStatus;
          if (status is! SuccessStatus<void>) {
            return;
          }

          final message = switch (status.actionKey) {
            'pantry.itemAdded' => 'Pantry item added',
            'pantry.itemUpdated' => 'Pantry item updated',
            'pantry.itemDeleted' => 'Pantry item removed',
            'pantry.refreshed' => 'Pantry refreshed',
            _ => null,
          };
          if (message == null) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
        child: Column(
          children: <Widget>[
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.all(AppPadding.md),
                child: ApiStatusBanner(
                  message: state.errorMessage ?? 'Could not load pantry data',
                  subtitle: 'You can keep using the app and retry any time.',
                  onRetry: () =>
                      context.read<PantryBloc>().add(const PantryRefreshed()),
                ),
              ),
            Expanded(
              child: state.isLoading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? const Center(
                      child: Text('No pantry items yet. Add your first item.'),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 80),
                      children: <Widget>[
                        if (useSoonItems.isNotEmpty)
                          _UseSoonSection(
                            items: useSoonItems,
                            onTapItem: (item) =>
                                _showPantryEditor(context, existing: item),
                          ),
                        ..._storageOptions.map(
                          (storage) => _StorageSection(
                            title: storage,
                            items: grouped[storage]!,
                            onEditItem: (item) =>
                                _showPantryEditor(context, existing: item),
                            onDeleteItem: (item) => context
                                .read<PantryBloc>()
                                .add(PantryItemDeleted(item.id)),
                            onDropItem: (item) {
                              final source = _canonicalStorage(
                                item.storageLocation,
                              );
                              if (source == storage) {
                                return;
                              }
                              context.read<PantryBloc>().add(
                                PantryItemUpdated(
                                  item.copyWith(storageLocation: storage),
                                ),
                              );
                            },
                            canonicalStorage: _canonicalStorage,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPantryEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }

  Future<void> _showPantryEditor(
    BuildContext context, {
    PantryItem? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final quantityController = TextEditingController(
      text: existing != null ? existing.quantity.toString() : '1',
    );
    String selectedUnit = _unitOptions.contains(existing?.unit)
        ? existing!.unit
        : _unitOptions.first;
    final existingStorage = existing == null
        ? null
        : _canonicalStorage(existing.storageLocation);
    String selectedStorage = _storageOptions.contains(existingStorage)
        ? existingStorage!
        : _storageOptions.first;
    DateTime expiryDate =
        existing?.expiryDate ?? DateTime.now().add(const Duration(days: 7));

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Add pantry item' : 'Edit pantry item',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: _unitOptions
                          .map(
                            (unit) => DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedUnit = value);
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStorage,
                      decoration: const InputDecoration(
                        labelText: 'Storage location',
                      ),
                      items: _storageOptions
                          .map(
                            (location) => DropdownMenuItem<String>(
                              value: location,
                              child: Text(location),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStorage = value);
                        }
                      },
                    ),
                    const SizedBox(height: AppPadding.sm),
                    Row(
                      children: <Widget>[
                        const Text('Expiry:'),
                        const SizedBox(width: AppPadding.sm),
                        Text(expiryDate.toLocal().toString().split(' ').first),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              initialDate: expiryDate,
                            );
                            if (picked != null) {
                              setState(() => expiryDate = picked);
                            }
                          },
                          child: const Text('Choose'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final parsedQuantity = double.tryParse(quantityController.text.trim()) ?? 1;
    final item = PantryItem(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      quantity: parsedQuantity,
      unit: selectedUnit,
      storageLocation: selectedStorage,
      expiryDate: expiryDate,
      lowStockThreshold: 1,
    );

    if (existing == null) {
      context.read<PantryBloc>().add(PantryItemAdded(item));
    } else {
      context.read<PantryBloc>().add(PantryItemUpdated(item));
    }
  }
}

class _UseSoonSection extends StatelessWidget {
  const _UseSoonSection({required this.items, required this.onTapItem});

  final List<PantryItem> items;
  final ValueChanged<PantryItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppPadding.md,
        AppPadding.md,
        AppPadding.md,
        AppPadding.sm,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppPadding.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: AppPadding.xs),
                  Text('Use Soon', style: textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: AppPadding.xs),
              Text(
                'Items expiring in 3 days or less. Tap to edit quantity or expiry.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppPadding.sm),
              Wrap(
                spacing: AppPadding.sm,
                runSpacing: AppPadding.sm,
                children: items
                    .map(
                      (item) => ActionChip(
                        avatar: Icon(
                          Icons.schedule,
                          size: 16,
                          color: colorScheme.tertiary,
                        ),
                        label: Text('${item.name} (${item.daysUntilExpiry}d)'),
                        onPressed: () => onTapItem(item),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageSection extends StatelessWidget {
  const _StorageSection({
    required this.title,
    required this.items,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onDropItem,
    required this.canonicalStorage,
  });

  final String title;
  final List<PantryItem> items;
  final ValueChanged<PantryItem> onEditItem;
  final ValueChanged<PantryItem> onDeleteItem;
  final ValueChanged<PantryItem> onDropItem;
  final String Function(String value) canonicalStorage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppPadding.md,
        AppPadding.sm,
        AppPadding.md,
        AppPadding.sm,
      ),
      child: DragTarget<PantryItem>(
        onWillAcceptWithDetails: (details) {
          return canonicalStorage(details.data.storageLocation) != title;
        },
        onAcceptWithDetails: (details) => onDropItem(details.data),
        builder: (context, candidateData, rejectedData) {
          final isActive = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(AppPadding.sm),
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primaryContainer.withAlpha(130)
                  : colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppPadding.sm,
                    AppPadding.xs,
                    AppPadding.sm,
                    AppPadding.sm,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.inventory_2_outlined, size: 18),
                      const SizedBox(width: AppPadding.xs),
                      Expanded(
                        child: Text(
                          '$title (${items.length})',
                          style: textTheme.titleMedium,
                        ),
                      ),
                      if (isActive)
                        Text(
                          'Drop to move',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppPadding.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      color: colorScheme.surface,
                    ),
                    child: Text(
                      'No items here. Drag items into $title.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppPadding.sm),
                      child: LongPressDraggable<PantryItem>(
                        data: item,
                        feedback: Material(
                          elevation: 6,
                          color: Colors.transparent,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: _PantryItemTile(
                              item: item,
                              onTap: null,
                              onDelete: null,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.45,
                          child: _PantryItemTile(
                            item: item,
                            onTap: () => onEditItem(item),
                            onDelete: () => onDeleteItem(item),
                          ),
                        ),
                        child: _PantryItemTile(
                          item: item,
                          onTap: () => onEditItem(item),
                          onDelete: () => onDeleteItem(item),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PantryItemTile extends StatelessWidget {
  const _PantryItemTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final PantryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.name),
        subtitle: Text(
          '${item.quantity} ${item.unit}\nExpires: ${item.expiryDate.toLocal().toString().split(' ').first}',
        ),
        isThreeLine: true,
        trailing: onDelete == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
        onTap: onTap,
      ),
    );
  }
}
