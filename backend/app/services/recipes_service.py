from datetime import datetime

from fastapi import HTTPException, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import (
    Difficulty,
    PantryCoverageResponse,
    PantryItem,
    Recipe,
    RecipeAccountMetadata,
    RecipeCreate,
    RecipeOwnershipScope,
    RecipePublic,
    RecipeUpdate,
)


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
    ) -> list[RecipePublic]:
        recipes = self._list_accessible_recipes()
        metadata_by_recipe_id = self._recipe_metadata_map(recipe_ids=[item.id for item in recipes])
        decorated = self._apply_account_metadata(
            recipes=recipes,
            metadata_by_recipe_id=metadata_by_recipe_id,
        )

        filtered = decorated
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

    def create_recipe(self, payload: RecipeCreate) -> RecipePublic:
        recipe = Recipe.model_validate(
            payload,
            update={
                "user_id": self._user_id,
                "ownership_scope": RecipeOwnershipScope.custom_account,
            },
        )
        self._session.add(recipe)
        self._session.commit()
        self._session.refresh(recipe)
        return self._decorate_recipe(recipe)

    def update_recipe(self, recipe_id: str, payload: RecipeUpdate) -> RecipePublic:
        recipe = self._session.get(Recipe, recipe_id)
        if (
            not recipe
            or recipe.ownership_scope != RecipeOwnershipScope.custom_account
            or recipe.user_id != self._user_id
        ):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

        updates = payload.model_dump(exclude_unset=True)
        for key, value in updates.items():
            setattr(recipe, key, value)
        recipe.updated_at = datetime.utcnow()

        self._session.add(recipe)
        self._session.commit()
        self._session.refresh(recipe)
        return self._decorate_recipe(recipe)

    def toggle_favorite(self, recipe_id: str) -> RecipePublic:
        recipe = self._require_accessible_recipe(recipe_id)

        metadata = self._session.get(RecipeAccountMetadata, (self._user_id, recipe_id))
        if metadata is None:
            metadata = RecipeAccountMetadata(
                user_id=self._user_id,
                recipe_id=recipe_id,
                is_favorite=True,
                updated_at=datetime.utcnow(),
            )
        else:
            metadata.is_favorite = not metadata.is_favorite
            metadata.updated_at = datetime.utcnow()

        self._session.add(metadata)
        self._session.commit()
        return self._decorate_recipe(recipe)

    def delete_recipe(self, recipe_id: str) -> None:
        recipe = self._session.get(Recipe, recipe_id)
        if (
            not recipe
            or recipe.ownership_scope != RecipeOwnershipScope.custom_account
            or recipe.user_id != self._user_id
        ):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

        self._session.delete(recipe)
        self._session.commit()

    def recipe_coverage(self, recipe_id: str) -> PantryCoverageResponse:
        recipe = self._require_accessible_recipe(recipe_id)

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

    def _list_accessible_recipes(self) -> list[Recipe]:
        statement = select(Recipe).where(
            (Recipe.ownership_scope == RecipeOwnershipScope.starter_catalog)
            | (Recipe.ownership_scope == RecipeOwnershipScope.plus_catalog)
            | (
                (Recipe.ownership_scope == RecipeOwnershipScope.custom_account)
                & (Recipe.user_id == self._user_id)
            )
        )
        return list(self._session.exec(statement).all())

    def _require_accessible_recipe(self, recipe_id: str) -> Recipe:
        recipe = self._session.get(Recipe, recipe_id)
        if not recipe:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

        is_catalog = recipe.ownership_scope in {
            RecipeOwnershipScope.starter_catalog,
            RecipeOwnershipScope.plus_catalog,
        }
        is_owned_custom = (
            recipe.ownership_scope == RecipeOwnershipScope.custom_account
            and recipe.user_id == self._user_id
        )
        if not (is_catalog or is_owned_custom):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
        return recipe

    def _recipe_metadata_map(self, recipe_ids: list[str]) -> dict[str, RecipeAccountMetadata]:
        if not recipe_ids:
            return {}

        statement = select(RecipeAccountMetadata).where(
            RecipeAccountMetadata.user_id == self._user_id,
            RecipeAccountMetadata.recipe_id.in_(recipe_ids),
        )
        metadata = list(self._session.exec(statement).all())
        return {item.recipe_id: item for item in metadata}

    def _apply_account_metadata(
        self,
        recipes: list[Recipe],
        metadata_by_recipe_id: dict[str, RecipeAccountMetadata],
    ) -> list[RecipePublic]:
        return [
            self._copy_recipe_with_favorite(
                recipe,
                metadata_by_recipe_id.get(recipe.id).is_favorite
                if recipe.id in metadata_by_recipe_id
                else False,
            )
            for recipe in recipes
        ]

    def _decorate_recipe(self, recipe: Recipe) -> RecipePublic:
        metadata = self._session.get(RecipeAccountMetadata, (self._user_id, recipe.id))
        return self._copy_recipe_with_favorite(
            recipe,
            metadata.is_favorite if metadata is not None else False,
        )

    def _copy_recipe_with_favorite(self, recipe: Recipe, is_favorite: bool) -> RecipePublic:
        return RecipePublic(
            id=recipe.id,
            title=recipe.title,
            description=recipe.description,
            prep_minutes=recipe.prep_minutes,
            cook_minutes=recipe.cook_minutes,
            servings=recipe.servings,
            difficulty=recipe.difficulty,
            tags=recipe.tags,
            ingredients=recipe.ingredients,
            steps=recipe.steps,
            ownership_scope=recipe.ownership_scope,
            is_favorite=is_favorite,
            created_at=recipe.created_at,
            updated_at=recipe.updated_at,
        )
