part of 'recipes_bloc.dart';

class RecipesState extends Equatable {
  const RecipesState({
    this.recipes = const <Recipe>[],
    this.searchTerm = '',
    this.maxMinutesFilter,
    this.skillFilter,
    this.dietFilter,
  });

  final List<Recipe> recipes;
  final String searchTerm;
  final int? maxMinutesFilter;
  final String? skillFilter;
  final String? dietFilter;

  List<Recipe> get filteredRecipes {
    final q = searchTerm.toLowerCase();
    final filtered = recipes.where((recipe) {
      final matchesSearch =
          q.isEmpty ||
          recipe.title.toLowerCase().contains(q) ||
          recipe.ingredients.any(
            (ingredient) => ingredient.toLowerCase().contains(q),
          );
      final matchesTime =
          maxMinutesFilter == null || recipe.totalMinutes <= maxMinutesFilter!;
      final matchesSkill =
          skillFilter == null || recipe.difficulty == skillFilter;
      final matchesDiet =
          dietFilter == null ||
          recipe.tags.any((tag) => tag.toLowerCase() == dietFilter!.toLowerCase());

      return matchesSearch && matchesTime && matchesSkill && matchesDiet;
    }).toList(growable: true);

    filtered.sort((left, right) {
      if (left.isFavorite != right.isFavorite) {
        return left.isFavorite ? -1 : 1;
      }
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });

    return filtered;
  }

  RecipesState copyWith({
    List<Recipe>? recipes,
    String? searchTerm,
    int? maxMinutesFilter,
    String? skillFilter,
    String? dietFilter,
    bool clearMaxMinutesFilter = false,
    bool clearSkillFilter = false,
    bool clearDietFilter = false,
  }) {
    return RecipesState(
      recipes: recipes ?? this.recipes,
      searchTerm: searchTerm ?? this.searchTerm,
      maxMinutesFilter: clearMaxMinutesFilter
          ? null
          : (maxMinutesFilter ?? this.maxMinutesFilter),
      skillFilter: clearSkillFilter ? null : (skillFilter ?? this.skillFilter),
      dietFilter: clearDietFilter ? null : (dietFilter ?? this.dietFilter),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    recipes,
    searchTerm,
    maxMinutesFilter,
    skillFilter,
    dietFilter,
  ];
}
