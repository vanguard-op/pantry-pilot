from fastapi import APIRouter, Depends, status

from app.models import FeedbackEntry, FeedbackEntryCreate, FeedbackEntryUpdate
from app.services.feedback_service import FeedbackService

router = APIRouter(prefix="/feedback", tags=["feedback"])


@router.get("", response_model=list[FeedbackEntry])
def list_feedback(service: FeedbackService = Depends()) -> list[FeedbackEntry]:
    return service.list_feedback()


@router.post("", response_model=FeedbackEntry, status_code=status.HTTP_201_CREATED)
def create_feedback(
    payload: FeedbackEntryCreate,
    service: FeedbackService = Depends(),
) -> FeedbackEntry:
    return service.create_feedback(payload)


@router.patch("/{entry_id}", response_model=FeedbackEntry)
def update_feedback(
    entry_id: str,
    payload: FeedbackEntryUpdate,
    service: FeedbackService = Depends(),
) -> FeedbackEntry:
    return service.update_feedback(entry_id, payload)
