part of 'onboarding_bloc.dart';

sealed class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class OnboardingStarted extends OnboardingEvent {
  const OnboardingStarted();
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
  List<Object?> get props => <Object?>[
    householdSize,
    skillLevel,
    dietaryNotes,
    staples,
  ];
}
