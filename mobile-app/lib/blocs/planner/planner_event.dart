part of 'planner_bloc.dart';

sealed class PlannerEvent extends Equatable implements ActionTrackedEvent {
  const PlannerEvent();

  @override
  String? get actionKey => null;

  @override
  List<Object?> get props => <Object?>[];
}

class PlannerStarted extends PlannerEvent {
  const PlannerStarted();

  @override
  String get actionKey => 'planner.started';
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
  String get actionKey => 'planner.mealAdded';

  @override
  List<Object?> get props => <Object?>[meal];
}

class PlannedMealDeleted extends PlannerEvent {
  const PlannedMealDeleted(this.id);

  final String id;

  @override
  String get actionKey => 'planner.mealDeleted';

  @override
  List<Object?> get props => <Object?>[id];
}

class PlannerRequestFailed extends PlannerEvent {
  const PlannerRequestFailed(this.message, {this.sourceActionKey});

  final String message;
  final String? sourceActionKey;

  @override
  String? get actionKey => sourceActionKey;

  @override
  List<Object?> get props => <Object?>[message, sourceActionKey];
}
