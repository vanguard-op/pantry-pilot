from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.models import AICoverageResponse, AIShoppingGapsResponse
from app.services.ai_planning_service import AIPlanningService
from app.services.ai_planning_validation_service import AIPlanningValidationService

router = APIRouter(prefix="/ai/planner", tags=["ai-planner"])


@router.get("/coverage/{recipe_id}", response_model=AICoverageResponse)
def generate_ai_coverage(
    recipe_id: str,
    service: AIPlanningService = Depends(),
    validator: AIPlanningValidationService = Depends(),
    strict: bool = Query(default=True),
) -> AICoverageResponse:
    """Generate and validate AI pantry coverage JSON for a recipe.

    When strict=true, invalid payloads are rejected with HTTP 422.
    """
    payload = service.generate_recipe_coverage_payload(recipe_id)
    result = validator.validate_coverage_payload(payload)

    if strict and not result.validation.valid:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=[issue.model_dump() for issue in result.validation.issues],
        )
    return result


@router.get("/shopping-gaps", response_model=AIShoppingGapsResponse)
def generate_ai_shopping_gaps(
    service: AIPlanningService = Depends(),
    validator: AIPlanningValidationService = Depends(),
    days: int = Query(default=7, ge=1, le=30),
    strict: bool = Query(default=True),
) -> AIShoppingGapsResponse:
    """Generate and validate AI shopping gap JSON for upcoming planned meals.

    When strict=true, invalid payloads are rejected with HTTP 422.
    """
    payload = service.generate_shopping_gaps_payload(days)
    result = validator.validate_shopping_gaps_payload(payload)

    if strict and not result.validation.valid:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=[issue.model_dump() for issue in result.validation.issues],
        )
    return result
