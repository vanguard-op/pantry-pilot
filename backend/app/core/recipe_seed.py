from __future__ import annotations

from collections.abc import Sequence

from sqlmodel import Session, select

from app.models import Difficulty, Recipe, RecipeOwnershipScope


def seed_recipes_if_empty(session: Session, *, seed_user_id: str) -> None:
    existing_recipe_id = session.exec(select(Recipe.id).limit(1)).first()
    if existing_recipe_id is not None:
        return

    recipes = _generate_starter_recipes(seed_user_id)
    for recipe in recipes:
        session.add(recipe)
    session.commit()


def _generate_starter_recipes(_seed_user_id: str) -> Sequence[Recipe]:
    proteins = ["Chicken", "Tofu", "Beans", "Egg", "Tuna"]
    carbs = ["Rice", "Pasta", "Potato", "Quinoa", "Wrap"]
    vegetables = ["Broccoli", "Carrot", "Bell Pepper", "Spinach", "Zucchini"]

    recipes: list[Recipe] = []
    index = 0

    for protein in proteins:
        for carb in carbs:
            for vegetable in vegetables:
                if len(recipes) >= 50:
                    return recipes

                if index % 3 == 0:
                    difficulty = Difficulty.beginner
                elif index % 3 == 1:
                    difficulty = Difficulty.intermediate
                else:
                    difficulty = Difficulty.confident

                prep = 8 + (index % 4) * 3
                cook = 15 + (index % 5) * 4
                title = f"{protein} {carb} with {vegetable}"
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

                tags = ["Weeknight"]
                if cook <= 25:
                    tags.append("Quick")
                if difficulty == Difficulty.beginner:
                    tags.append("Easy")
                if vegetable == "Spinach":
                    tags.append("Leafy Greens")

                recipes.append(
                    Recipe(
                        # Starter recipes are platform-owned and shared across accounts.
                        user_id=None,
                        ownership_scope=RecipeOwnershipScope.global_catalog,
                        title=title,
                        description="A practical weekday meal focused on pantry-friendly ingredients and easy prep.",
                        prep_minutes=prep,
                        cook_minutes=cook,
                        servings=4,
                        difficulty=difficulty,
                        tags=tags,
                        ingredients=ingredients,
                        steps=steps,
                        is_favorite=False,
                    )
                )

                index += 1

    return recipes