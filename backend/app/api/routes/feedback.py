from datetime import datetime

from fastapi import APIRouter, HTTPException, status
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import FeedbackEntry, FeedbackEntryCreate, FeedbackEntryUpdate

router = APIRouter(prefix="/feedback", tags=["feedback"])


@router.get("", response_model=list[FeedbackEntry])
def list_feedback(session: SessionDep, user_id: UserIdDep) -> list[FeedbackEntry]:
    statement = select(FeedbackEntry).where(FeedbackEntry.user_id == user_id)
    entries = list(session.exec(statement).all())
    return sorted(entries, key=lambda entry: entry.created_at, reverse=True)


@router.post("", response_model=FeedbackEntry, status_code=status.HTTP_201_CREATED)
def create_feedback(
    payload: FeedbackEntryCreate,
    session: SessionDep,
    user_id: UserIdDep,
) -> FeedbackEntry:
    entry = FeedbackEntry.model_validate(payload, update={"user_id": user_id})
    session.add(entry)
    session.commit()
    session.refresh(entry)
    return entry


@router.patch("/{entry_id}", response_model=FeedbackEntry)
def update_feedback(
    entry_id: str,
    payload: FeedbackEntryUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> FeedbackEntry:
    entry = session.get(FeedbackEntry, entry_id)
    if not entry or entry.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Feedback not found")

    entry.status = payload.status
    entry.updated_at = datetime.utcnow()
    session.add(entry)
    session.commit()
    session.refresh(entry)
    return entry
