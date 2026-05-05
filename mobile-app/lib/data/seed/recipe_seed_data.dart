import '../models/recipe.dart';
import '../models/recipe_step.dart';

List<Recipe> generateStarterRecipes() {
  const proteins = <String>['Chicken', 'Tofu', 'Beans', 'Egg', 'Tuna'];
  const carbs = <String>['Rice', 'Pasta', 'Potato', 'Quinoa', 'Wrap'];
  const vegetables = <String>[
    'Broccoli',
    'Carrot',
    'Bell Pepper',
    'Spinach',
    'Zucchini',
  ];

  final recipes = <Recipe>[];
  var index = 0;

  for (final protein in proteins) {
    for (final carb in carbs) {
      for (final vegetable in vegetables) {
        if (recipes.length >= 50) {
          return recipes;
        }

        final difficulty = index % 3 == 0
            ? 'Beginner'
            : index % 3 == 1
            ? 'Intermediate'
            : 'Confident';

        final prep = 8 + (index % 4) * 3;
        final cook = 15 + (index % 5) * 4;
        final title = '$protein $carb with $vegetable';
        final ingredients = <String>[
          protein.toLowerCase(),
          carb.toLowerCase(),
          vegetable.toLowerCase(),
          'garlic',
          'olive oil',
          'salt',
        ];

        recipes.add(
          Recipe(
            id: 'recipe_$index',
            title: title,
            description:
                'A practical weekday meal focused on pantry-friendly ingredients and easy prep.',
            prepMinutes: prep,
            cookMinutes: cook,
            servings: 4,
            difficulty: difficulty,
            tags: <String>[
              'Weeknight',
              if (cook <= 25) 'Quick',
              if (difficulty == 'Beginner') 'Easy',
              if (vegetable == 'Spinach') 'Leafy Greens',
            ],
            ingredients: ingredients,
            steps: <RecipeStep>[
              RecipeStep(
                description:
                    'Prep the $protein, $carb, and $vegetable into bite-size pieces.',
                durationMinutes: prep ~/ 2,
                ingredientMentions: <String>[protein, carb, vegetable],
              ),
              RecipeStep(
                description:
                    'Heat oil in a pan, cook the $protein, and season with garlic and salt.',
                durationMinutes: cook ~/ 2,
                ingredientMentions: <String>[protein, 'garlic', 'olive oil'],
              ),
              RecipeStep(
                description:
                    'Add the $vegetable, then combine with $carb until fully warmed through.',
                durationMinutes: cook ~/ 2,
                ingredientMentions: <String>[vegetable, carb],
              ),
              RecipeStep(
                description: 'Taste, adjust seasoning, and serve.',
                durationMinutes: 2,
                ingredientMentions: <String>['salt'],
              ),
            ],
            isFavorite: false,
          ),
        );

        index += 1;
      }
    }
  }

  return recipes;
}
