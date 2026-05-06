from datetime import date, timedelta

from fastapi import APIRouter
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import BoughtItem, PantryItem, PlannedMeal, Recipe, ShoppingListItem, ShoppingListResponse

router = APIRouter(prefix="/shopping", tags=["shopping"])


@router.get("", response_model=ShoppingListResponse)
def generate_shopping_list(
    session: SessionDep,
    user_id: UserIdDep,
    days: int = 7,
) -> ShoppingListResponse:
    today = date.today()
    end_date = today + timedelta(days=max(1, days) - 1)

    meals_statement = select(PlannedMeal).where(
        PlannedMeal.user_id == user_id,
        PlannedMeal.date >= today,
        PlannedMeal.date <= end_date,
    )
    pantry_statement = select(PantryItem).where(PantryItem.user_id == user_id)
    recipe_statement = select(Recipe).where(Recipe.user_id == user_id)

    meals = list(session.exec(meals_statement).all())
    pantry_items = list(session.exec(pantry_statement).all())
    recipes = list(session.exec(recipe_statement).all())

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
        ShoppingListItem(name=name, needed_for_meals=count)
        for name, count in sorted(missing_counts.items())
    ]
    return ShoppingListResponse(items=items)


@router.post("/sync-bought", response_model=list[PantryItem])
def sync_bought_items(
    payload: list[BoughtItem],
    session: SessionDep,
    user_id: UserIdDep,
) -> list[PantryItem]:
    statement = select(PantryItem).where(PantryItem.user_id == user_id)
    pantry_items = list(session.exec(statement).all())
    by_name = {item.name.strip().lower(): item for item in pantry_items}

    updated: list[PantryItem] = []
    for bought in payload:
        normalized = bought.name.strip().lower()
        if not normalized:
            continue

        existing = by_name.get(normalized)
        if existing:
            existing.quantity += bought.quantity
            session.add(existing)
            updated.append(existing)
            continue

        created = PantryItem(
            user_id=user_id,
            name=bought.name.strip(),
            quantity=bought.quantity,
            unit="pcs",
            storage_location="Pantry",
            expiry_date=None,
            low_stock_threshold=1,
        )
        session.add(created)
        updated.append(created)

    session.commit()
    for item in updated:
        session.refresh(item)
    return updated
