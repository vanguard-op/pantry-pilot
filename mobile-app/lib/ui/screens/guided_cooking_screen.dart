import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/cooking/cooking_bloc.dart';
import '../../data/models/recipe.dart';
import '../../data/repositories/settings_repository.dart';

class GuidedCookingScreen extends StatefulWidget {
  const GuidedCookingScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<GuidedCookingScreen> createState() => _GuidedCookingScreenState();
}

class _GuidedCookingScreenState extends State<GuidedCookingScreen> {
  bool _sessionLogged = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CookingBloc>(
      create: (_) => CookingBloc()..add(CookingStarted(widget.recipe)),
      child: BlocListener<CookingBloc, CookingState>(
        listenWhen: (previous, current) =>
            !previous.completed && current.completed,
        listener: (context, state) {
          if (_sessionLogged) {
            return;
          }
          _sessionLogged = true;
          context.read<SettingsRepository>().logCookingSession(DateTime.now());
        },
        child: BlocBuilder<CookingBloc, CookingState>(
          builder: (context, state) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
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
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You finished ${currentRecipe.title}',
                        style: textTheme.headlineMedium,
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
                    style: textTheme.headlineMedium,
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
                            style: textTheme.displayMedium,
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
      ),
    );
  }
}
