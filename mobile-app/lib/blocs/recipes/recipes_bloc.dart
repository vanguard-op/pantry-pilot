import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

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
    on<RecipeFavoriteToggled>(_onFavoriteToggled);
  }

  final RecipeRepository _recipeRepository;
  StreamSubscription<List<Recipe>>? _subscription;

  Future<void> _onStarted(
    RecipesStarted event,
    Emitter<RecipesState> emit,
  ) async {
    await _recipeRepository.seedIfNeeded();
    await _subscription?.cancel();
    _subscription = _recipeRepository.watchAll().listen((recipes) {
      add(RecipesChanged(recipes));
    });
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

  Future<void> _onFavoriteToggled(
    RecipeFavoriteToggled event,
    Emitter<RecipesState> emit,
  ) async {
    await _recipeRepository.toggleFavorite(event.recipeId);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
