from datetime import datetime

from fastapi import APIRouter, HTTPException, Query, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import Difficulty, PantryCoverageResponse, PantryItem, Recipe, RecipeCreate, RecipeUpdate

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


@router.get("/{recipe_id}/coverage", response_model=PantryCoverageResponse)
def get_recipe_coverage(
    recipe_id: str,
    session: SessionDep,
    user_id: UserIdDep,
) -> PantryCoverageResponse:
    """Return pantry coverage for a single recipe.

    Computes which of the recipe's ingredients are present in the user's
    pantry and returns the coverage percentage alongside the split lists.
    Moving this server-side means future enhancements (partial quantities,
    expiry awareness, unit normalisation) require no mobile app changes.
    """
    recipe = session.get(Recipe, recipe_id)
    if recipe is None or recipe.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

    pantry_names = {
        item.name.lower()
        for item in session.exec(
            select(PantryItem).where(PantryItem.user_id == user_id)
        ).all()
    }

    available = [i for i in recipe.ingredients if i.lower() in pantry_names]
    missing = [i for i in recipe.ingredients if i.lower() not in pantry_names]
    coverage = (
        round((len(available) / len(recipe.ingredients)) * 100)
        if recipe.ingredients
        else 0
    )

    return PantryCoverageResponse(
        recipe_id=recipe_id,
        coverage_percent=coverage,
        matched_count=len(available),
        total_count=len(recipe.ingredients),
        missing_ingredients=missing,
        available_ingredients=available,
    )
