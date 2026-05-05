part of 'planner_bloc.dart';

class PlannerState extends Equatable {
  const PlannerState({this.meals = const <PlannedMeal>[]});

  final List<PlannedMeal> meals;

  PlannerState copyWith({List<PlannedMeal>? meals}) {
    return PlannerState(meals: meals ?? this.meals);
  }

  @override
  List<Object?> get props => <Object?>[meals];
}
