from datetime import date, datetime, timedelta

from fastapi import APIRouter, HTTPException, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import PlannedMeal, PlannedMealCreate, PlannedMealUpdate

router = APIRouter(prefix="/planner", tags=["planner"])


@router.get("", response_model=list[PlannedMeal])
def list_meals(session: SessionDep, user_id: UserIdDep) -> list[PlannedMeal]:
    statement = select(PlannedMeal).where(PlannedMeal.user_id == user_id)
    meals = list(session.exec(statement).all())
    return sorted(meals, key=lambda meal: (meal.date, meal.slot))


@router.get("/week", response_model=list[PlannedMeal])
def list_next_week(
    session: SessionDep,
    user_id: UserIdDep,
    start: date | None = None,
) -> list[PlannedMeal]:
    start_date = start or date.today()
    end_date = start_date + timedelta(days=6)
    statement = select(PlannedMeal).where(
        PlannedMeal.user_id == user_id,
        PlannedMeal.date >= start_date,
        PlannedMeal.date <= end_date,
    )
    meals = list(session.exec(statement).all())
    return sorted(meals, key=lambda meal: (meal.date, meal.slot))


@router.post("", response_model=PlannedMeal, status_code=status.HTTP_201_CREATED)
def create_meal(
    payload: PlannedMealCreate,
    session: SessionDep,
    user_id: UserIdDep,
) -> PlannedMeal:
    meal = PlannedMeal.model_validate(
        payload,
        update={"user_id": user_id, "slot": payload.slot.strip()},
    )
    session.add(meal)
    session.commit()
    session.refresh(meal)
    return meal


@router.patch("/{meal_id}", response_model=PlannedMeal)
def update_meal(
    meal_id: str,
    payload: PlannedMealUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> PlannedMeal:
    meal = session.get(PlannedMeal, meal_id)
    if not meal or meal.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal not found")

    updates = payload.model_dump(exclude_unset=True)
    if "slot" in updates and updates["slot"]:
        updates["slot"] = updates["slot"].strip()

    for key, value in updates.items():
        setattr(meal, key, value)
    meal.updated_at = datetime.utcnow()

    session.add(meal)
    session.commit()
    session.refresh(meal)
    return meal


@router.delete("/{meal_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_meal(meal_id: str, session: SessionDep, user_id: UserIdDep) -> None:
    meal = session.get(PlannedMeal, meal_id)
    if not meal or meal.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal not found")
    session.delete(meal)
    session.commit()
