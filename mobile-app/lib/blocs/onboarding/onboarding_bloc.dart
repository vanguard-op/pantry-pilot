import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/pantry_item.dart';
import '../../data/repositories/pantry_repository.dart';
import '../../data/repositories/settings_repository.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required SettingsRepository settingsRepository,
    required PantryRepository pantryRepository,
  }) : _settingsRepository = settingsRepository,
       _pantryRepository = pantryRepository,
       super(const OnboardingState()) {
    on<OnboardingStarted>(_onStarted);
    on<OnboardingSubmitted>(_onSubmitted);
  }

  final SettingsRepository _settingsRepository;
  final PantryRepository _pantryRepository;

  void _onStarted(OnboardingStarted event, Emitter<OnboardingState> emit) {
    emit(
      state.copyWith(
        status: OnboardingStatus.ready,
        completed: _settingsRepository.onboardingComplete,
      ),
    );
  }

  Future<void> _onSubmitted(
    OnboardingSubmitted event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(status: OnboardingStatus.saving));

    await _settingsRepository.saveHouseholdProfile(
      size: event.householdSize,
      skillLevel: event.skillLevel,
      dietaryNotes: event.dietaryNotes,
    );

    if (event.staples.isNotEmpty) {
      final now = DateTime.now();
      final staples = <PantryItem>[];
      for (var i = 0; i < event.staples.length; i += 1) {
        staples.add(
          PantryItem(
            id: 'staple_${event.staples[i]}_$i',
            name: event.staples[i],
            quantity: 1,
            unit: 'pack',
            storageLocation: 'Pantry',
            expiryDate: now.add(const Duration(days: 30)),
            lowStockThreshold: 1,
          ),
        );
      }
      await _pantryRepository.upsertAll(staples);
    }

    await _settingsRepository.setOnboardingComplete(true);

    emit(state.copyWith(status: OnboardingStatus.ready, completed: true));
  }
}
