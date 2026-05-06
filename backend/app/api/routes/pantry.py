from fastapi import APIRouter, Depends, status

from app.models import PantryItem, PantryItemCreate, PantryItemUpdate
from app.services.pantry_service import PantryService

router = APIRouter(prefix="/pantry", tags=["pantry"])


@router.get("", response_model=list[PantryItem])
def list_items(service: PantryService = Depends()) -> list[PantryItem]:
    return service.list_items()


@router.post("", response_model=PantryItem, status_code=status.HTTP_201_CREATED)
def create_item(
    payload: PantryItemCreate,
    service: PantryService = Depends(),
) -> PantryItem:
    return service.create_item(payload)


@router.patch("/{item_id}", response_model=PantryItem)
def update_item(
    item_id: str,
    payload: PantryItemUpdate,
    service: PantryService = Depends(),
) -> PantryItem:
    return service.update_item(item_id, payload)


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: str, service: PantryService = Depends()) -> None:
    service.delete_item(item_id)
