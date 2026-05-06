from fastapi import APIRouter, Depends

from app.models import (
    DashboardRecommendationsResponse,
    PlannerRecommendationsResponse,
)
from app.services.recommendation_service import RecommendationService

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/planner", response_model=PlannerRecommendationsResponse)
def planner_recommendations(
    service: RecommendationService = Depends(),
) -> PlannerRecommendationsResponse:
    return service.build_planner_recommendations()


@router.get("/dashboard", response_model=DashboardRecommendationsResponse)
def dashboard_recommendations(
    service: RecommendationService = Depends(),
) -> DashboardRecommendationsResponse:
    return service.build_dashboard_recommendations()
