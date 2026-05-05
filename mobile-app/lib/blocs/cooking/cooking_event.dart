part of 'cooking_bloc.dart';

sealed class CookingEvent extends Equatable {
  const CookingEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class CookingStarted extends CookingEvent {
  const CookingStarted(this.recipe);

  final Recipe recipe;

  @override
  List<Object?> get props => <Object?>[recipe];
}

class CookingNextStep extends CookingEvent {
  const CookingNextStep();
}

class CookingPreviousStep extends CookingEvent {
  const CookingPreviousStep();
}

class CookingTimerStarted extends CookingEvent {
  const CookingTimerStarted();
}

class CookingTimerTicked extends CookingEvent {
  const CookingTimerTicked();
}

class CookingTimerStopped extends CookingEvent {
  const CookingTimerStopped();
}

class CookingCompleted extends CookingEvent {
  const CookingCompleted();
}
