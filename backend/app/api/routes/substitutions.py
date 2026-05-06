from fastapi import APIRouter, Depends, Query

from app.models import SubstitutionHintsResponse
from app.services.substitution_service import SubstitutionService

router = APIRouter(prefix="/substitutions", tags=["substitutions"])


@router.get("", response_model=SubstitutionHintsResponse)
def get_substitution_hints(
    service: SubstitutionService = Depends(),
    ingredients: list[str] = Query(default=[]),
) -> SubstitutionHintsResponse:
    """Return substitution hints for a list of ingredient names.

    Each hint is enriched with pantry-aware suggestions when the user has
    a plausible substitute already in stock. Falls back to the knowledge
    base default for unknown ingredients.
    """
    return service.build_substitution_hints(ingredients)
