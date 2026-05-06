from datetime import date, datetime, timedelta

from fastapi import HTTPException, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import PlannedMeal, PlannedMealCreate, PlannedMealUpdate


class PlannerService:
    def __init__(self, session: SessionDep, user_id: UserIdDep) -> None:
        self._session = session
        self._user_id = user_id

    def list_meals(self) -> list[PlannedMeal]:
        statement = select(PlannedMeal).where(PlannedMeal.user_id == self._user_id)
        meals = list(self._session.exec(statement).all())
        return sorted(meals, key=lambda meal: (meal.date, meal.slot))

    def list_next_week(self, start: date | None = None) -> list[PlannedMeal]:
        start_date = start or date.today()
        end_date = start_date + timedelta(days=6)
        statement = select(PlannedMeal).where(
            PlannedMeal.user_id == self._user_id,
            PlannedMeal.date >= start_date,
            PlannedMeal.date <= end_date,
        )
        meals = list(self._session.exec(statement).all())
        return sorted(meals, key=lambda meal: (meal.date, meal.slot))

    def create_meal(self, payload: PlannedMealCreate) -> PlannedMeal:
        meal = PlannedMeal.model_validate(
            payload,
            update={"user_id": self._user_id, "slot": payload.slot.strip()},
        )
        self._session.add(meal)
        self._session.commit()
        self._session.refresh(meal)
        return meal

    def update_meal(self, meal_id: str, payload: PlannedMealUpdate) -> PlannedMeal:
        meal = self._session.get(PlannedMeal, meal_id)
        if not meal or meal.user_id != self._user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal not found")

        updates = payload.model_dump(exclude_unset=True)
        if "slot" in updates and updates["slot"]:
            updates["slot"] = updates["slot"].strip()

        for key, value in updates.items():
            setattr(meal, key, value)
        meal.updated_at = datetime.utcnow()

        self._session.add(meal)
        self._session.commit()
        self._session.refresh(meal)
        return meal

    def delete_meal(self, meal_id: str) -> None:
        meal = self._session.get(PlannedMeal, meal_id)
        if not meal or meal.user_id != self._user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal not found")
        self._session.delete(meal)
        self._session.commit()
