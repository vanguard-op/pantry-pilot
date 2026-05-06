from fastapi import APIRouter, Depends, Query, status

from app.models import Difficulty, PantryCoverageResponse, Recipe, RecipeCreate, RecipeUpdate
from app.services.recipes_service import RecipesService

router = APIRouter(prefix="/recipes", tags=["recipes"])


@router.get("", response_model=list[Recipe])
def list_recipes(
    service: RecipesService = Depends(),
    search: str | None = None,
    max_minutes: int | None = Query(default=None, ge=1),
    skill: Difficulty | None = None,
    diet_tag: str | None = None,
    favorites_only: bool = False,
) -> list[Recipe]:
    return service.list_recipes(
        search=search,
        max_minutes=max_minutes,
        skill=skill,
        diet_tag=diet_tag,
        favorites_only=favorites_only,
    )


@router.post("", response_model=Recipe, status_code=status.HTTP_201_CREATED)
def create_recipe(payload: RecipeCreate, service: RecipesService = Depends()) -> Recipe:
    return service.create_recipe(payload)


@router.patch("/{recipe_id}", response_model=Recipe)
def update_recipe(
    recipe_id: str,
    payload: RecipeUpdate,
    service: RecipesService = Depends(),
) -> Recipe:
    return service.update_recipe(recipe_id, payload)


@router.post("/{recipe_id}/favorite", response_model=Recipe)
def toggle_favorite(recipe_id: str, service: RecipesService = Depends()) -> Recipe:
    return service.toggle_favorite(recipe_id)


@router.delete("/{recipe_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_recipe(recipe_id: str, service: RecipesService = Depends()) -> None:
    service.delete_recipe(recipe_id)


@router.get("/{recipe_id}/coverage", response_model=PantryCoverageResponse)
def get_recipe_coverage(
    recipe_id: str,
    service: RecipesService = Depends(),
) -> PantryCoverageResponse:
    """Return pantry coverage for a single recipe.

    Computes which of the recipe's ingredients are present in the user's
    pantry and returns the coverage percentage alongside the split lists.
    Moving this server-side means future enhancements (partial quantities,
    expiry awareness, unit normalisation) require no mobile app changes.
    """
    return service.recipe_coverage(recipe_id)
