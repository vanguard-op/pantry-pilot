from __future__ import annotations

from collections.abc import Sequence

from sqlmodel import Session, select

from app.models import Difficulty, Recipe, RecipeOwnershipScope


def seed_recipes_if_empty(session: Session) -> None:
    existing_recipe_id = session.exec(select(Recipe.id).limit(1)).first()
    if existing_recipe_id is not None:
        return

    recipes = [
        *_generate_curated_recipes(
            ownership_scope=RecipeOwnershipScope.starter_catalog,
            limit=50,
            title_suffix="",
            description=(
                "A practical weekday meal focused on pantry-friendly ingredients "
                "and easy prep."
            ),
            extra_tags=("Starter",),
        ),
        *_generate_curated_recipes(
            ownership_scope=RecipeOwnershipScope.plus_catalog,
            limit=24,
            title_suffix=" Plus",
            description=(
                "A premium curated recipe with broader ingredient variety and a "
                "slightly more ambitious cooking flow."
            ),
            extra_tags=("Plus", "Premium"),
        ),
    ]
    for recipe in recipes:
        session.add(recipe)
    session.commit()


def _generate_curated_recipes(
    *,
    ownership_scope: RecipeOwnershipScope,
    limit: int,
    title_suffix: str,
    description: str,
    extra_tags: tuple[str, ...],
) -> Sequence[Recipe]:
    proteins = ["Chicken", "Tofu", "Beans", "Egg", "Tuna"]
    carbs = ["Rice", "Pasta", "Potato", "Quinoa", "Wrap"]
    vegetables = ["Broccoli", "Carrot", "Bell Pepper", "Spinach", "Zucchini"]

    recipes: list[Recipe] = []
    index = 0

    for protein in proteins:
        for carb in carbs:
            for vegetable in vegetables:
                if len(recipes) >= limit:
                    return recipes

                if index % 3 == 0:
                    difficulty = Difficulty.beginner
                elif index % 3 == 1:
                    difficulty = Difficulty.intermediate
                else:
                    difficulty = Difficulty.confident

                prep = 8 + (index % 4) * 3
                cook = 15 + (index % 5) * 4
                title = f"{protein} {carb} with {vegetable}{title_suffix}"
                ingredients = [
                    protein.lower(),
                    carb.lower(),
                    vegetable.lower(),
                    "garlic",
                    "olive oil",
                    "salt",
                ]

                steps = [
                    {
                        "description": f"Prep the {protein}, {carb}, and {vegetable} into bite-size pieces.",
                        "duration_minutes": prep // 2,
                        "ingredient_mentions": [protein, carb, vegetable],
                    },
                    {
                        "description": f"Heat oil in a pan, cook the {protein}, and season with garlic and salt.",
                        "duration_minutes": cook // 2,
                        "ingredient_mentions": [protein, "garlic", "olive oil"],
                    },
                    {
                        "description": f"Add the {vegetable}, then combine with {carb} until fully warmed through.",
                        "duration_minutes": cook // 2,
                        "ingredient_mentions": [vegetable, carb],
                    },
                    {
                        "description": "Taste, adjust seasoning, and serve.",
                        "duration_minutes": 2,
                        "ingredient_mentions": ["salt"],
                    },
                ]

                tags = ["Weeknight", *extra_tags]
                if cook <= 25:
                    tags.append("Quick")
                if difficulty == Difficulty.beginner:
                    tags.append("Easy")
                if vegetable == "Spinach":
                    tags.append("Leafy Greens")

                recipes.append(
                    Recipe(
                        # Curated catalog recipes are platform-owned and shared across accounts.
                        user_id=None,
                        ownership_scope=ownership_scope,
                        title=title,
                        description=description,
                        prep_minutes=prep,
                        cook_minutes=cook,
                        servings=4,
                        difficulty=difficulty,
                        tags=tags,
                        ingredients=ingredients,
                        steps=steps,
                    )
                )

                index += 1

    return recipes