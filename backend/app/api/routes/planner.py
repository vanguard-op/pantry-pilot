from datetime import date

from fastapi import APIRouter, Depends, status

from app.models import PlannedMeal, PlannedMealCreate, PlannedMealUpdate
from app.services.planner_service import PlannerService

router = APIRouter(prefix="/planner", tags=["planner"])


@router.get("", response_model=list[PlannedMeal])
def list_meals(service: PlannerService = Depends()) -> list[PlannedMeal]:
    return service.list_meals()


@router.get("/week", response_model=list[PlannedMeal])
def list_next_week(
    service: PlannerService = Depends(),
    start: date | None = None,
) -> list[PlannedMeal]:
    return service.list_next_week(start)


@router.post("", response_model=PlannedMeal, status_code=status.HTTP_201_CREATED)
def create_meal(
    payload: PlannedMealCreate,
    service: PlannerService = Depends(),
) -> PlannedMeal:
    return service.create_meal(payload)


@router.patch("/{meal_id}", response_model=PlannedMeal)
def update_meal(
    meal_id: str,
    payload: PlannedMealUpdate,
    service: PlannerService = Depends(),
) -> PlannedMeal:
    return service.update_meal(meal_id, payload)


@router.delete("/{meal_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_meal(meal_id: str, service: PlannerService = Depends()) -> None:
    service.delete_meal(meal_id)
