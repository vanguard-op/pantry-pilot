import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../core/async_state.dart';
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
        requestStatus: IdleStatus<void>(actionKey: event.actionKey),
      ),
    );
  }

  Future<void> _onSubmitted(
    OnboardingSubmitted event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(
      state.copyWith(
        requestStatus: LoadingStatus<void>(actionKey: event.actionKey),
      ),
    );

    var failed = false;
    try {
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

      emit(
        state.copyWith(
          status: OnboardingStatus.ready,
          completed: true,
          requestStatus: SuccessStatus<void>(actionKey: event.actionKey),
        ),
      );
    } catch (error) {
      failed = true;
      emit(
        state.copyWith(
          requestStatus: ErrorStatus<void>(
            message: 'Unable to finish onboarding right now.',
            actionKey: event.actionKey,
            cause: error,
          ),
        ),
      );
    } finally {
      if (!failed) {
        emit(
          state.copyWith(
            requestStatus: IdleStatus<void>(actionKey: event.actionKey),
          ),
        );
      }
    }
  }
}
