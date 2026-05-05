import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/pantry/pantry_bloc.dart';
import '../../blocs/planner/planner_bloc.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pantryState = context.watch<PantryBloc>().state;
    final plannerState = context.watch<PlannerBloc>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('PantryPilot')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: ListTile(
              title: const Text('This week plan progress'),
              subtitle: Text('${plannerState.meals.length} meals planned'),
              leading: const Icon(Icons.calendar_month),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('Use soon ingredients'),
              subtitle: Text(
                '${pantryState.useSoonItems.length} items expiring in 3 days',
              ),
              leading: const Icon(Icons.warning_amber_outlined),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use Soon Queue',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (pantryState.useSoonItems.isEmpty)
            const Text('No urgent items right now.')
          else
            ...pantryState.useSoonItems.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.quantity} ${item.unit} - ${item.storageLocation}',
                  ),
                  trailing: Text('D-${item.daysUntilExpiry}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
