from datetime import datetime

from fastapi import APIRouter, HTTPException, Query, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import Difficulty, Recipe, RecipeCreate, RecipeUpdate

router = APIRouter(prefix="/recipes", tags=["recipes"])


@router.get("", response_model=list[Recipe])
def list_recipes(
    session: SessionDep,
    user_id: UserIdDep,
    search: str | None = None,
    max_minutes: int | None = Query(default=None, ge=1),
    skill: Difficulty | None = None,
    diet_tag: str | None = None,
    favorites_only: bool = False,
) -> list[Recipe]:
    statement = select(Recipe).where(Recipe.user_id == user_id)
    recipes = list(session.exec(statement).all())

    filtered = recipes
    if search:
        q = search.strip().lower()
        filtered = [
            recipe
            for recipe in filtered
            if q in recipe.title.lower()
            or any(q in ingredient.lower() for ingredient in recipe.ingredients)
        ]

    if max_minutes is not None:
        filtered = [
            recipe
            for recipe in filtered
            if (recipe.prep_minutes + recipe.cook_minutes) <= max_minutes
        ]

    if skill is not None:
        filtered = [recipe for recipe in filtered if recipe.difficulty == skill]

    if diet_tag:
        tag = diet_tag.lower().strip()
        filtered = [
            recipe
            for recipe in filtered
            if any(existing.lower() == tag for existing in recipe.tags)
        ]

    if favorites_only:
        filtered = [recipe for recipe in filtered if recipe.is_favorite]

    return filtered


@router.post("", response_model=Recipe, status_code=status.HTTP_201_CREATED)
def create_recipe(payload: RecipeCreate, session: SessionDep, user_id: UserIdDep) -> Recipe:
    recipe = Recipe.model_validate(payload, update={"user_id": user_id})
    session.add(recipe)
    session.commit()
    session.refresh(recipe)
    return recipe


@router.patch("/{recipe_id}", response_model=Recipe)
def update_recipe(
    recipe_id: str,
    payload: RecipeUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> Recipe:
    recipe = session.get(Recipe, recipe_id)
    if not recipe or recipe.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(recipe, key, value)
    recipe.updated_at = datetime.utcnow()

    session.add(recipe)
    session.commit()
    session.refresh(recipe)
    return recipe


@router.post("/{recipe_id}/favorite", response_model=Recipe)
def toggle_favorite(recipe_id: str, session: SessionDep, user_id: UserIdDep) -> Recipe:
    recipe = session.get(Recipe, recipe_id)
    if not recipe or recipe.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
    recipe.is_favorite = not recipe.is_favorite
    recipe.updated_at = datetime.utcnow()

    session.add(recipe)
    session.commit()
    session.refresh(recipe)
    return recipe


@router.delete("/{recipe_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_recipe(recipe_id: str, session: SessionDep, user_id: UserIdDep) -> None:
    recipe = session.get(Recipe, recipe_id)
    if not recipe or recipe.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
    session.delete(recipe)
    session.commit()
