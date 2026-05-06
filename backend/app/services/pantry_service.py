from datetime import datetime

from fastapi import HTTPException, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import PantryItem, PantryItemCreate, PantryItemUpdate


class PantryService:
    def __init__(self, session: SessionDep, user_id: UserIdDep) -> None:
        self._session = session
        self._user_id = user_id

    def list_items(self) -> list[PantryItem]:
        statement = select(PantryItem).where(PantryItem.user_id == self._user_id)
        return list(self._session.exec(statement).all())

    def create_item(self, payload: PantryItemCreate) -> PantryItem:
        item = PantryItem.model_validate(payload, update={"user_id": self._user_id})
        self._session.add(item)
        self._session.commit()
        self._session.refresh(item)
        return item

    def update_item(
        self,
        item_id: str,
        payload: PantryItemUpdate,
    ) -> PantryItem:
        item = self._session.get(PantryItem, item_id)
        if not item or item.user_id != self._user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

        updates = payload.model_dump(exclude_unset=True)
        for key, value in updates.items():
            setattr(item, key, value)
        item.updated_at = datetime.utcnow()

        self._session.add(item)
        self._session.commit()
        self._session.refresh(item)
        return item

    def delete_item(self, item_id: str) -> None:
        item = self._session.get(PantryItem, item_id)
        if not item or item.user_id != self._user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
        self._session.delete(item)
        self._session.commit()
