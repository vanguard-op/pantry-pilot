part of 'onboarding_bloc.dart';

enum OnboardingStatus { initial, ready }

class OnboardingState extends AsyncState {
  const OnboardingState({
    this.status = OnboardingStatus.initial,
    this.completed = false,
    super.requestStatus,
  });

  final OnboardingStatus status;
  final bool completed;

  OnboardingState copyWith({
    OnboardingStatus? status,
    bool? completed,
    Status<void>? requestStatus,
  }) {
    return OnboardingState(
      status: status ?? this.status,
      completed: completed ?? this.completed,
      requestStatus: requestStatus ?? this.requestStatus,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, completed, ...asyncProps];
}
