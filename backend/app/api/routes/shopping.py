from fastapi import APIRouter, Depends

from app.models import BoughtItem, PantryItem, ShoppingListResponse
from app.services.shopping_service import ShoppingService

router = APIRouter(prefix="/shopping", tags=["shopping"])


@router.get("", response_model=ShoppingListResponse)
def generate_shopping_list(
    service: ShoppingService = Depends(),
    days: int = 7,
) -> ShoppingListResponse:
    return service.generate_shopping_list(days)


@router.post("/sync-bought", response_model=list[PantryItem])
def sync_bought_items(
    payload: list[BoughtItem],
    service: ShoppingService = Depends(),
) -> list[PantryItem]:
    return service.sync_bought_items(payload)
