import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/cooking/cooking_bloc.dart';
import '../../data/models/recipe.dart';

class GuidedCookingScreen extends StatelessWidget {
  const GuidedCookingScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CookingBloc>(
      create: (_) => CookingBloc()..add(CookingStarted(recipe)),
      child: BlocBuilder<CookingBloc, CookingState>(
        builder: (context, state) {
          final currentRecipe = state.recipe;
          if (currentRecipe == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.completed) {
            return Scaffold(
              appBar: AppBar(title: const Text('Meal complete')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle,
                        size: 64,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You finished ${currentRecipe.title}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Great job. Pantry update automation is ready for Phase 2.',
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final step = currentRecipe.steps[state.currentStepIndex];

          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Cooking ${state.currentStepIndex + 1}/${currentRecipe.steps.length}',
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    step.description,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: step.ingredientMentions
                        .map((name) => Chip(label: Text(name)))
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: <Widget>[
                          const Text('Step timer'),
                          const SizedBox(height: 8),
                          Text(
                            state.mmss,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              FilledButton(
                                onPressed: state.isTimerRunning
                                    ? null
                                    : () => context.read<CookingBloc>().add(
                                        const CookingTimerStarted(),
                                      ),
                                child: const Text('Start'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: state.isTimerRunning
                                    ? () => context.read<CookingBloc>().add(
                                        const CookingTimerStopped(),
                                      )
                                    : null,
                                child: const Text('Stop'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: state.currentStepIndex > 0
                              ? () => context.read<CookingBloc>().add(
                                  const CookingPreviousStep(),
                                )
                              : null,
                          child: const Text('Previous'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => context.read<CookingBloc>().add(
                            const CookingNextStep(),
                          ),
                          child: Text(
                            state.currentStepIndex ==
                                    currentRecipe.steps.length - 1
                                ? 'Finish'
                                : 'Next step',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
