part of 'cooking_bloc.dart';

class CookingState extends Equatable {
  const CookingState({
    this.recipe,
    this.currentStepIndex = 0,
    this.secondsRemaining = 0,
    this.isTimerRunning = false,
    this.completed = false,
  });

  final Recipe? recipe;
  final int currentStepIndex;
  final int secondsRemaining;
  final bool isTimerRunning;
  final bool completed;

  String get mmss {
    final minutes = (secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  CookingState copyWith({
    Recipe? recipe,
    int? currentStepIndex,
    int? secondsRemaining,
    bool? isTimerRunning,
    bool? completed,
  }) {
    return CookingState(
      recipe: recipe ?? this.recipe,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      completed: completed ?? this.completed,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    recipe,
    currentStepIndex,
    secondsRemaining,
    isTimerRunning,
    completed,
  ];
}
