from datetime import datetime

from fastapi import HTTPException, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import Difficulty, PantryCoverageResponse, PantryItem, Recipe, RecipeCreate, RecipeUpdate


class RecipesService:
    def __init__(self, session: SessionDep, user_id: UserIdDep) -> None:
        self._session = session
        self._user_id = user_id

    def list_recipes(
        self,
        search: str | None = None,
        max_minutes: int | None = None,
        skill: Difficulty | None = None,
        diet_tag: str | None = None,
        favorites_only: bool = False,
    ) -> list[Recipe]:
        statement = select(Recipe).where(Recipe.user_id == self._user_id)
        recipes = list(self._session.exec(statement).all())

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

    def create_recipe(self, payload: RecipeCreate) -> Recipe:
        recipe = Recipe.model_validate(payload, update={"user_id": self._user_id})
        self._session.add(recipe)
        self._session.commit()
        self._session.refresh(recipe)
        return recipe

    def update_recipe(self, recipe_id: str, payload: RecipeUpdate) -> Recipe:
        recipe = self._session.get(Recipe, recipe_id)
        if not recipe or recipe.user_id != self._user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

        updates = payload.model_dump(exclude_unset=True)
        for key, value in updates.items():
            setattr(recipe, key, value)
        recipe.updated_at = datetime.utcnow()

        self._session.add(recipe)
        self._session.commit()
        self._session.refresh(recipe)
        return recipe

    def toggle_favorite(self, recipe_id: str) -> Recipe:
        recipe = self._session.get(Recipe, recipe_id)
        if not recipe or recipe.user_id != self._user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
        recipe.is_favorite = not recipe.is_favorite
        recipe.updated_at = datetime.utcnow()

        self._session.add(recipe)
        self._session.commit()
        self._session.refresh(recipe)
        return recipe

    def delete_recipe(self, recipe_id: str) -> None:
        recipe = self._session.get(Recipe, recipe_id)
        if not recipe or recipe.user_id != self._user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
        self._session.delete(recipe)
        self._session.commit()

    def recipe_coverage(self, recipe_id: str) -> PantryCoverageResponse:
        recipe = self._session.get(Recipe, recipe_id)
        if recipe is None or recipe.user_id != self._user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

        pantry_names = {
            item.name.lower()
            for item in self._session.exec(
                select(PantryItem).where(PantryItem.user_id == self._user_id)
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
