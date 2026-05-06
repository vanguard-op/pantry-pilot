import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../data/models/pantry_item.dart';
import '../../theme/app_theme.dart';

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

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

  static const _storageOptions = <String>[
    'Pantry',
    'Fridge',
    'Freezer',
    'Counter',
  ];

  @override
  Widget build(BuildContext context) {
    final items = context.watch<PantryBloc>().state.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Pantry Inventory')),
      body: items.isEmpty
          ? const Center(
              child: Text('No pantry items yet. Add your first item.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.quantity} ${item.unit} - ${item.storageLocation}\nExpires: ${item.expiryDate.toLocal().toString().split(' ').first}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => context.read<PantryBloc>().add(
                        PantryItemDeleted(item.id),
                      ),
                    ),
                    onTap: () => _showPantryEditor(context, existing: item),
                  ),
                );
              },
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
    String selectedStorage = _storageOptions.contains(existing?.storageLocation)
        ? existing!.storageLocation
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
