part of 'recipes_bloc.dart';

class RecipesState extends Equatable {
  const RecipesState({this.recipes = const <Recipe>[], this.searchTerm = ''});

  final List<Recipe> recipes;
  final String searchTerm;

  List<Recipe> get filteredRecipes {
    if (searchTerm.trim().isEmpty) {
      return recipes;
    }
    final q = searchTerm.toLowerCase();
    return recipes
        .where(
          (recipe) =>
              recipe.title.toLowerCase().contains(q) ||
              recipe.ingredients.any(
                (ingredient) => ingredient.toLowerCase().contains(q),
              ),
        )
        .toList(growable: false);
  }

  RecipesState copyWith({List<Recipe>? recipes, String? searchTerm}) {
    return RecipesState(
      recipes: recipes ?? this.recipes,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }

  @override
  List<Object?> get props => <Object?>[recipes, searchTerm];
}
