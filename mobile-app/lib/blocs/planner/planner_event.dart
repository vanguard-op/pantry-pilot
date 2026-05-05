part of 'planner_bloc.dart';

sealed class PlannerEvent extends Equatable {
  const PlannerEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class PlannerStarted extends PlannerEvent {
  const PlannerStarted();
}

class PlannerMealsChanged extends PlannerEvent {
  const PlannerMealsChanged(this.meals);

  final List<PlannedMeal> meals;

  @override
  List<Object?> get props => <Object?>[meals];
}

class PlannedMealAdded extends PlannerEvent {
  const PlannedMealAdded(this.meal);

  final PlannedMeal meal;

  @override
  List<Object?> get props => <Object?>[meal];
}

class PlannedMealDeleted extends PlannerEvent {
  const PlannedMealDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => <Object?>[id];
}
