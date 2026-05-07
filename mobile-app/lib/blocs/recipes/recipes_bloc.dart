import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../core/async_state.dart';
import '../../data/api/api_client.dart';
import '../../data/models/recipe.dart';
import '../../data/repositories/recipe_repository.dart';

part 'recipes_event.dart';
part 'recipes_state.dart';

class RecipesBloc extends Bloc<RecipesEvent, RecipesState> {
  RecipesBloc({required RecipeRepository recipeRepository})
    : _recipeRepository = recipeRepository,
      super(const RecipesState()) {
    on<RecipesStarted>(_onStarted);
    on<RecipesChanged>(_onChanged);
    on<RecipesSearchChanged>(_onSearchChanged);
    on<RecipesTimeFilterChanged>(_onTimeFilterChanged);
    on<RecipesSkillFilterChanged>(_onSkillFilterChanged);
    on<RecipesDietFilterChanged>(_onDietFilterChanged);
    on<RecipeFavoriteToggled>(_onFavoriteToggled);
    on<RecipesRequestFailed>(_onRequestFailed);
  }

  final RecipeRepository _recipeRepository;
  StreamSubscription<List<Recipe>>? _subscription;

  Future<void> _onStarted(
    RecipesStarted event,
    Emitter<RecipesState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = _recipeRepository.watchAll().listen(
      (recipes) {
        add(RecipesChanged(recipes));
      },
      onError: (error) => add(
        RecipesRequestFailed(
          _errorMessage(error),
          sourceActionKey: event.actionKey,
        ),
      ),
    );

    await _runRequest(event, emit, _recipeRepository.initialize);
  }

  void _onChanged(RecipesChanged event, Emitter<RecipesState> emit) {
    emit(state.copyWith(recipes: event.recipes));
  }

  void _onSearchChanged(
    RecipesSearchChanged event,
    Emitter<RecipesState> emit,
  ) {
    emit(state.copyWith(searchTerm: event.searchTerm));
  }

  void _onTimeFilterChanged(
    RecipesTimeFilterChanged event,
    Emitter<RecipesState> emit,
  ) {
    emit(
      event.maxMinutes == null
          ? state.copyWith(clearMaxMinutesFilter: true)
          : state.copyWith(maxMinutesFilter: event.maxMinutes),
    );
  }

  void _onSkillFilterChanged(
    RecipesSkillFilterChanged event,
    Emitter<RecipesState> emit,
  ) {
    emit(
      event.skillLevel == null
          ? state.copyWith(clearSkillFilter: true)
          : state.copyWith(skillFilter: event.skillLevel),
    );
  }

  void _onDietFilterChanged(
    RecipesDietFilterChanged event,
    Emitter<RecipesState> emit,
  ) {
    emit(
      event.dietTag == null
          ? state.copyWith(clearDietFilter: true)
          : state.copyWith(dietFilter: event.dietTag),
    );
  }

  Future<void> _onFavoriteToggled(
    RecipeFavoriteToggled event,
    Emitter<RecipesState> emit,
  ) async {
    await _runRequest(
      event,
      emit,
      () => _recipeRepository.toggleFavorite(event.recipeId),
    );
  }

  void _onRequestFailed(
    RecipesRequestFailed event,
    Emitter<RecipesState> emit,
  ) {
    emit(
      state.copyWith(
        requestStatus: ErrorStatus<void>(
          message: event.message,
          actionKey: event.actionKey,
        ),
      ),
    );
  }

  Future<void> _runRequest(
    RecipesEvent event,
    Emitter<RecipesState> emit,
    Future<void> Function() run,
  ) async {
    emit(
      state.copyWith(
        requestStatus: LoadingStatus<void>(actionKey: event.actionKey),
      ),
    );

    var failed = false;
    try {
      await run();
      emit(
        state.copyWith(
          requestStatus: SuccessStatus<void>(actionKey: event.actionKey),
        ),
      );
    } catch (error) {
      failed = true;
      emit(
        state.copyWith(
          requestStatus: ErrorStatus<void>(
            message: _errorMessage(error),
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

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Unable to update recipes right now.';
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
