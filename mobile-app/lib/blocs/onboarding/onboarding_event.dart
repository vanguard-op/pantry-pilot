part of 'onboarding_bloc.dart';

sealed class OnboardingEvent extends Equatable implements ActionTrackedEvent {
  const OnboardingEvent();

  @override
  String? get actionKey => null;

  @override
  List<Object?> get props => <Object?>[];
}

class OnboardingStarted extends OnboardingEvent {
  const OnboardingStarted();

  @override
  String get actionKey => 'onboarding.started';
}

class OnboardingSubmitted extends OnboardingEvent {
  const OnboardingSubmitted({
    required this.householdSize,
    required this.skillLevel,
    required this.dietaryNotes,
    required this.staples,
  });

  final int householdSize;
  final String skillLevel;
  final String dietaryNotes;
  final List<String> staples;

  @override
  String get actionKey => 'onboarding.submitted';

  @override
  List<Object?> get props => <Object?>[
    householdSize,
    skillLevel,
    dietaryNotes,
    staples,
  ];
}
