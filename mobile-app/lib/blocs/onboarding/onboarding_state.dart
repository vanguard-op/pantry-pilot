part of 'onboarding_bloc.dart';

enum OnboardingStatus { initial, ready, saving }

class OnboardingState extends Equatable {
  const OnboardingState({
    this.status = OnboardingStatus.initial,
    this.completed = false,
  });

  final OnboardingStatus status;
  final bool completed;

  OnboardingState copyWith({OnboardingStatus? status, bool? completed}) {
    return OnboardingState(
      status: status ?? this.status,
      completed: completed ?? this.completed,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, completed];
}
