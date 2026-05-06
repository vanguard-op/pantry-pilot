from datetime import datetime

from fastapi import APIRouter, HTTPException, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import PantryItem, PantryItemCreate, PantryItemUpdate

router = APIRouter(prefix="/pantry", tags=["pantry"])


@router.get("", response_model=list[PantryItem])
def list_items(session: SessionDep, user_id: UserIdDep) -> list[PantryItem]:
    statement = select(PantryItem).where(PantryItem.user_id == user_id)
    return list(session.exec(statement).all())


@router.post("", response_model=PantryItem, status_code=status.HTTP_201_CREATED)
def create_item(
    payload: PantryItemCreate,
    session: SessionDep,
    user_id: UserIdDep,
) -> PantryItem:
    item = PantryItem.model_validate(payload, update={"user_id": user_id})
    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@router.patch("/{item_id}", response_model=PantryItem)
def update_item(
    item_id: str,
    payload: PantryItemUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> PantryItem:
    item = session.get(PantryItem, item_id)
    if not item or item.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(item, key, value)
    item.updated_at = datetime.utcnow()

    session.add(item)
    session.commit()
    session.refresh(item)
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: str, session: SessionDep, user_id: UserIdDep) -> None:
    item = session.get(PantryItem, item_id)
    if not item or item.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    session.delete(item)
    session.commit()
