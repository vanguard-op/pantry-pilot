import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../core/async_state.dart';
import '../../data/api/api_client.dart';
import '../../data/models/planned_meal.dart';
import '../../data/repositories/planner_repository.dart';

part 'planner_event.dart';
part 'planner_state.dart';

class PlannerBloc extends Bloc<PlannerEvent, PlannerState> {
  PlannerBloc({required PlannerRepository plannerRepository})
    : _plannerRepository = plannerRepository,
      super(const PlannerState()) {
    on<PlannerStarted>(_onStarted);
    on<PlannerMealsChanged>(_onMealsChanged);
    on<PlannedMealAdded>(_onMealAdded);
    on<PlannedMealDeleted>(_onMealDeleted);
    on<PlannerRequestFailed>(_onRequestFailed);
  }

  final PlannerRepository _plannerRepository;
  StreamSubscription<List<PlannedMeal>>? _subscription;

  Future<void> _onStarted(
    PlannerStarted event,
    Emitter<PlannerState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = _plannerRepository.watchAll().listen(
      (meals) => add(PlannerMealsChanged(meals)),
      onError: (error) => add(
        PlannerRequestFailed(
          _errorMessage(error),
          sourceActionKey: event.actionKey,
        ),
      ),
    );

    await _runRequest(event, emit, _plannerRepository.initialize);
  }

  void _onMealsChanged(PlannerMealsChanged event, Emitter<PlannerState> emit) {
    emit(state.copyWith(meals: event.meals));
  }

  Future<void> _onMealAdded(
    PlannedMealAdded event,
    Emitter<PlannerState> emit,
  ) async {
    await _runRequest(
      event,
      emit,
      () => _plannerRepository.addMeal(event.meal),
    );
  }

  Future<void> _onMealDeleted(
    PlannedMealDeleted event,
    Emitter<PlannerState> emit,
  ) async {
    await _runRequest(
      event,
      emit,
      () => _plannerRepository.deleteMeal(event.id),
    );
  }

  void _onRequestFailed(
    PlannerRequestFailed event,
    Emitter<PlannerState> emit,
  ) {
    emit(
      state.copyWith(
        requestStatus: ErrorStatus<void>(
          message: event.message,
          actionKey: event.actionKey,
        ),
      ),
    );
  }

  Future<void> _runRequest(
    PlannerEvent event,
    Emitter<PlannerState> emit,
    Future<void> Function() run,
  ) async {
    emit(
      state.copyWith(
        requestStatus: LoadingStatus<void>(actionKey: event.actionKey),
      ),
    );

    var failed = false;
    try {
      await run();
      emit(
        state.copyWith(
          requestStatus: SuccessStatus<void>(actionKey: event.actionKey),
        ),
      );
    } catch (error) {
      failed = true;
      emit(
        state.copyWith(
          requestStatus: ErrorStatus<void>(
            message: _errorMessage(error),
            actionKey: event.actionKey,
            cause: error,
          ),
        ),
      );
    } finally {
      if (!failed) {
        emit(
          state.copyWith(
            requestStatus: IdleStatus<void>(actionKey: event.actionKey),
          ),
        );
      }
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Unable to update planner right now.';
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
