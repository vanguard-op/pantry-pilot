from datetime import datetime

from fastapi import HTTPException, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import FeedbackEntry, FeedbackEntryCreate, FeedbackEntryUpdate


class FeedbackService:
    def __init__(self, session: SessionDep, user_id: UserIdDep) -> None:
        self._session = session
        self._user_id = user_id

    def list_feedback(self) -> list[FeedbackEntry]:
        statement = select(FeedbackEntry).where(FeedbackEntry.user_id == self._user_id)
        entries = list(self._session.exec(statement).all())
        return sorted(entries, key=lambda entry: entry.created_at, reverse=True)

    def create_feedback(self, payload: FeedbackEntryCreate) -> FeedbackEntry:
        entry = FeedbackEntry.model_validate(payload, update={"user_id": self._user_id})
        self._session.add(entry)
        self._session.commit()
        self._session.refresh(entry)
        return entry

    def update_feedback(
        self,
        entry_id: str,
        payload: FeedbackEntryUpdate,
    ) -> FeedbackEntry:
        entry = self._session.get(FeedbackEntry, entry_id)
        if not entry or entry.user_id != self._user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Feedback not found")

        entry.status = payload.status
        entry.updated_at = datetime.utcnow()
        self._session.add(entry)
        self._session.commit()
        self._session.refresh(entry)
        return entry
