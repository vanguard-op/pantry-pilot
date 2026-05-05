part of 'recipes_bloc.dart';

sealed class RecipesEvent extends Equatable {
  const RecipesEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class RecipesStarted extends RecipesEvent {
  const RecipesStarted();
}

class RecipesChanged extends RecipesEvent {
  const RecipesChanged(this.recipes);

  final List<Recipe> recipes;

  @override
  List<Object?> get props => <Object?>[recipes];
}

class RecipesSearchChanged extends RecipesEvent {
  const RecipesSearchChanged(this.searchTerm);

  final String searchTerm;

  @override
  List<Object?> get props => <Object?>[searchTerm];
}

class RecipeFavoriteToggled extends RecipesEvent {
  const RecipeFavoriteToggled(this.recipeId);

  final String recipeId;

  @override
  List<Object?> get props => <Object?>[recipeId];
}
