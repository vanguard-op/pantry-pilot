import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

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
    );
  }

  void _onMealsChanged(PlannerMealsChanged event, Emitter<PlannerState> emit) {
    emit(state.copyWith(meals: event.meals));
  }

  Future<void> _onMealAdded(
    PlannedMealAdded event,
    Emitter<PlannerState> emit,
  ) async {
    await _plannerRepository.addMeal(event.meal);
  }

  Future<void> _onMealDeleted(
    PlannedMealDeleted event,
    Emitter<PlannerState> emit,
  ) async {
    await _plannerRepository.deleteMeal(event.id);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
