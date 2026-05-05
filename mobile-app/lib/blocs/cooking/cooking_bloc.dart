import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/recipe.dart';

part 'cooking_event.dart';
part 'cooking_state.dart';

class CookingBloc extends Bloc<CookingEvent, CookingState> {
  CookingBloc() : super(const CookingState()) {
    on<CookingStarted>(_onStarted);
    on<CookingNextStep>(_onNextStep);
    on<CookingPreviousStep>(_onPreviousStep);
    on<CookingTimerStarted>(_onTimerStarted);
    on<CookingTimerTicked>(_onTimerTicked);
    on<CookingTimerStopped>(_onTimerStopped);
    on<CookingCompleted>(_onCompleted);
  }

  Timer? _timer;

  void _onStarted(CookingStarted event, Emitter<CookingState> emit) {
    _timer?.cancel();
    emit(
      state.copyWith(
        recipe: event.recipe,
        currentStepIndex: 0,
        secondsRemaining: event.recipe.steps.first.durationMinutes * 60,
        isTimerRunning: false,
        completed: false,
      ),
    );
  }

  void _onNextStep(CookingNextStep event, Emitter<CookingState> emit) {
    final recipe = state.recipe;
    if (recipe == null) {
      return;
    }
    if (state.currentStepIndex >= recipe.steps.length - 1) {
      add(const CookingCompleted());
      return;
    }

    _timer?.cancel();
    final nextIndex = state.currentStepIndex + 1;
    emit(
      state.copyWith(
        currentStepIndex: nextIndex,
        secondsRemaining: recipe.steps[nextIndex].durationMinutes * 60,
        isTimerRunning: false,
      ),
    );
  }

  void _onPreviousStep(CookingPreviousStep event, Emitter<CookingState> emit) {
    final recipe = state.recipe;
    if (recipe == null || state.currentStepIndex == 0) {
      return;
    }

    _timer?.cancel();
    final prevIndex = state.currentStepIndex - 1;
    emit(
      state.copyWith(
        currentStepIndex: prevIndex,
        secondsRemaining: recipe.steps[prevIndex].durationMinutes * 60,
        isTimerRunning: false,
      ),
    );
  }

  void _onTimerStarted(CookingTimerStarted event, Emitter<CookingState> emit) {
    if (state.isTimerRunning || state.secondsRemaining <= 0) {
      return;
    }

    emit(state.copyWith(isTimerRunning: true));
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(const CookingTimerTicked()),
    );
  }

  void _onTimerTicked(CookingTimerTicked event, Emitter<CookingState> emit) {
    if (!state.isTimerRunning) {
      return;
    }

    if (state.secondsRemaining <= 1) {
      _timer?.cancel();
      emit(state.copyWith(secondsRemaining: 0, isTimerRunning: false));
      return;
    }

    emit(state.copyWith(secondsRemaining: state.secondsRemaining - 1));
  }

  void _onTimerStopped(CookingTimerStopped event, Emitter<CookingState> emit) {
    _timer?.cancel();
    emit(state.copyWith(isTimerRunning: false));
  }

  void _onCompleted(CookingCompleted event, Emitter<CookingState> emit) {
    _timer?.cancel();
    emit(state.copyWith(completed: true, isTimerRunning: false));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
