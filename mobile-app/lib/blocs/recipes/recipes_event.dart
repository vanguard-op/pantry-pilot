part of 'recipes_bloc.dart';

sealed class RecipesEvent extends Equatable implements ActionTrackedEvent {
  const RecipesEvent();

  @override
  String? get actionKey => null;

  @override
  List<Object?> get props => <Object?>[];
}

class RecipesStarted extends RecipesEvent {
  const RecipesStarted();

  @override
  String get actionKey => 'recipes.started';
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

class RecipesTimeFilterChanged extends RecipesEvent {
  const RecipesTimeFilterChanged(this.maxMinutes);

  final int? maxMinutes;

  @override
  List<Object?> get props => <Object?>[maxMinutes];
}

class RecipesSkillFilterChanged extends RecipesEvent {
  const RecipesSkillFilterChanged(this.skillLevel);

  final String? skillLevel;

  @override
  List<Object?> get props => <Object?>[skillLevel];
}

class RecipesDietFilterChanged extends RecipesEvent {
  const RecipesDietFilterChanged(this.dietTag);

  final String? dietTag;

  @override
  List<Object?> get props => <Object?>[dietTag];
}

class RecipeFavoriteToggled extends RecipesEvent {
  const RecipeFavoriteToggled(this.recipeId);

  final String recipeId;

  @override
  String get actionKey => 'recipes.favoriteToggled';

  @override
  List<Object?> get props => <Object?>[recipeId];
}

class RecipesRequestFailed extends RecipesEvent {
  const RecipesRequestFailed(this.message, {this.sourceActionKey});

  final String message;
  final String? sourceActionKey;

  @override
  String? get actionKey => sourceActionKey;

  @override
  List<Object?> get props => <Object?>[message, sourceActionKey];
}
