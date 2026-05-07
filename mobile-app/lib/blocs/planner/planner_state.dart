part of 'planner_bloc.dart';

class PlannerState extends AsyncState {
  const PlannerState({this.meals = const <PlannedMeal>[], super.requestStatus});

  final List<PlannedMeal> meals;

  PlannerState copyWith({
    List<PlannedMeal>? meals,
    Status<void>? requestStatus,
  }) {
    return PlannerState(
      meals: meals ?? this.meals,
      requestStatus: requestStatus ?? this.requestStatus,
    );
  }

  @override
  List<Object?> get props => <Object?>[meals, ...asyncProps];
}
