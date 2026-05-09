from datetime import date, timedelta

from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import (
    BoughtItem,
    PantryItem,
    PantryItemKind,
    PlannedMeal,
    Recipe,
    RecipeOwnershipScope,
    ShoppingListItem,
    ShoppingListResponse,
)


class ShoppingService:
    def __init__(self, session: SessionDep, user_id: UserIdDep) -> None:
        self._session = session
        self._user_id = user_id

    def generate_shopping_list(self, days: int = 7) -> ShoppingListResponse:
        today = date.today()
        end_date = today + timedelta(days=max(1, days) - 1)

        meals_statement = select(PlannedMeal).where(
            PlannedMeal.user_id == self._user_id,
            PlannedMeal.date >= today,
            PlannedMeal.date <= end_date,
        )
        pantry_statement = select(PantryItem).where(PantryItem.user_id == self._user_id)
        recipe_statement = select(Recipe).where(
            (Recipe.ownership_scope == RecipeOwnershipScope.starter_catalog)
            | (Recipe.ownership_scope == RecipeOwnershipScope.plus_catalog)
            | (
                (Recipe.ownership_scope == RecipeOwnershipScope.custom_account)
                & (Recipe.user_id == self._user_id)
            )
        )

        meals = list(self._session.exec(meals_statement).all())
        pantry_items = list(self._session.exec(pantry_statement).all())
        recipes = list(self._session.exec(recipe_statement).all())

        recipe_by_id = {recipe.id: recipe for recipe in recipes}
        pantry_names = {item.name.strip().lower() for item in pantry_items}

        missing_counts: dict[str, int] = {}
        for meal in meals:
            recipe = recipe_by_id.get(meal.recipe_id)
            if not recipe:
                continue
            for ingredient in recipe.ingredients:
                normalized = ingredient.strip().lower()
                if not normalized or normalized in pantry_names:
                    continue
                missing_counts[normalized] = missing_counts.get(normalized, 0) + 1

        items = [
            self._build_shopping_list_item(name, count)
            for name, count in sorted(missing_counts.items())
        ]
        return ShoppingListResponse(items=items)

    def sync_bought_items(self, payload: list[BoughtItem]) -> list[PantryItem]:
        statement = select(PantryItem).where(PantryItem.user_id == self._user_id)
        pantry_items = list(self._session.exec(statement).all())
        by_name = {item.name.strip().lower(): item for item in pantry_items}

        updated: list[PantryItem] = []
        for bought in payload:
            normalized = bought.name.strip().lower()
            if not normalized:
                continue

            existing = by_name.get(normalized)
            if existing:
                existing.quantity += bought.quantity
                self._session.add(existing)
                updated.append(existing)
                continue

            created = PantryItem(
                user_id=self._user_id,
                name=bought.name.strip(),
                quantity=bought.quantity,
                unit=self._normalize_unit(bought.unit),
                storage_location="Pantry",
                item_kind=PantryItemKind.ingredient,
                expiry_date=None,
                low_stock_threshold=1,
            )
            self._session.add(created)
            updated.append(created)

        self._session.commit()
        for item in updated:
            self._session.refresh(item)
        return updated

    def _build_shopping_list_item(self, name: str, count: int) -> ShoppingListItem:
        return ShoppingListItem(
            name=name,
            needed_for_meals=count,
            unit=self._suggest_unit(name),
            suggested_quantity=1,
        )

    def _normalize_unit(self, unit: str | None) -> str:
        normalized = (unit or "").strip().lower()
        return normalized or "pcs"

    def _suggest_unit(self, ingredient_name: str) -> str:
        """Return a backend-owned default unit for a shopping item.

        This rule-based stub keeps unit selection centralized so it can later be
        swapped for a richer AI-assisted suggestion flow without changing the
        API contract consumed by the mobile app.
        """

        normalized = ingredient_name.strip().lower()
        if not normalized:
            return "pcs"

        keyword_units = {
            "g": {"rice", "pasta", "flour", "sugar", "cheese", "oats"},
            "ml": {"milk", "broth", "stock", "soy sauce", "vinegar", "oil"},
            "tbsp": {"olive oil", "sesame oil"},
            "tsp": {"salt", "paprika", "cumin", "pepper", "spice"},
            "pcs": {
                "onion",
                "tomato",
                "lemon",
                "lime",
                "avocado",
                "cucumber",
                "potato",
                "carrot",
                "egg",
            },
        }

        for unit, keywords in keyword_units.items():
            if any(keyword in normalized for keyword in keywords):
                return unit
        return "pcs"
