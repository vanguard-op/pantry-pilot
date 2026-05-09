from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from sqlmodel import Session, select

from app.models import Difficulty, Recipe, RecipeOwnershipScope


_RECIPES_JSON_PATH = Path(__file__).with_name("recipes.json")


def seed_recipes_if_empty(session: Session) -> None:
    existing_recipe_id = session.exec(select(Recipe.id).limit(1)).first()
    if existing_recipe_id is not None:
        return

    rows_with_scope = _load_seed_recipe_rows()
    recipes: list[Recipe] = []

    for row, ownership_scope in rows_with_scope:
        recipe = _build_recipe_from_row(row, ownership_scope=ownership_scope)
        if recipe is not None:
            recipes.append(recipe)

    for recipe in recipes:
        session.add(recipe)
    session.commit()


def _load_seed_recipe_rows() -> list[tuple[dict[str, Any], RecipeOwnershipScope]]:
    with _RECIPES_JSON_PATH.open("r", encoding="utf-8") as recipes_file:
        data = json.load(recipes_file)

    if not isinstance(data, dict):
        raise ValueError("recipes.json must contain an object with 'starter' and 'plus' keys")

    rows_with_scope: list[tuple[dict[str, Any], RecipeOwnershipScope]] = []

    # Process starter recipes
    starter_recipes = data.get("starter", [])
    if isinstance(starter_recipes, list):
        for row in starter_recipes:
            if isinstance(row, dict):
                rows_with_scope.append((row, RecipeOwnershipScope.starter_catalog))

    # Process plus recipes
    plus_recipes = data.get("plus", [])
    if isinstance(plus_recipes, list):
        for row in plus_recipes:
            if isinstance(row, dict):
                rows_with_scope.append((row, RecipeOwnershipScope.plus_catalog))

    return rows_with_scope


def _build_recipe_from_row(
    row: dict[str, Any],
    *,
    ownership_scope: RecipeOwnershipScope,
) -> Recipe:
    difficulty = Difficulty(str(row.get("difficulty", Difficulty.beginner.value)))

    return Recipe(
        # Catalog recipes are platform-owned and shared across accounts.
        user_id=None,
        ownership_scope=ownership_scope,
        title=str(row.get("title", "Untitled Recipe")),
        description=str(row.get("description", "")),
        prep_minutes=_safe_int(row.get("prep_minutes"), default=0),
        cook_minutes=_safe_int(row.get("cook_minutes"), default=0),
        servings=max(1, _safe_int(row.get("servings"), default=1)),
        difficulty=difficulty,
        tags=_list_or_empty(row.get("tags")),
        ingredients=_list_or_empty(row.get("ingredients")),
        steps=_list_or_empty(row.get("steps")),
    )


def _safe_int(value: Any, *, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _list_or_empty(value: Any) -> list[Any]:
    if not isinstance(value, list):
        return []
    return value
