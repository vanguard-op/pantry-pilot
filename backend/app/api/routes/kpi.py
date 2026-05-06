from datetime import date, timedelta

from fastapi import APIRouter
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import KpiSummary, PantryItem, PlannedMeal

router = APIRouter(prefix="/kpi", tags=["kpi"])


@router.get("/summary", response_model=KpiSummary)
def get_kpi_summary(session: SessionDep, user_id: UserIdDep) -> KpiSummary:
    pantry_statement = select(PantryItem).where(PantryItem.user_id == user_id)
    planner_statement = select(PlannedMeal).where(PlannedMeal.user_id == user_id)

    pantry_items = list(session.exec(pantry_statement).all())
    planned_meals = list(session.exec(planner_statement).all())

    threshold_date = date.today() - timedelta(days=7)
    planned_last_7 = sum(1 for meal in planned_meals if meal.date >= threshold_date)
    use_soon = sum(
        1
        for item in pantry_items
        if item.expiry_date is not None and item.expiry_date <= (date.today() + timedelta(days=3))
    )

    ratio = 0.0
    if pantry_items:
        ratio = round(use_soon / len(pantry_items), 4)

    return KpiSummary(
        has_created_first_plan=len(planned_meals) > 0,
        planned_meals_last_7_days=planned_last_7,
        cooking_sessions_last_7_days=0,
        pantry_use_soon_ratio=ratio,
    )
