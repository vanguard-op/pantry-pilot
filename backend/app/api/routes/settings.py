from datetime import datetime

from fastapi import APIRouter
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import SettingsModel, SettingsUpdate

router = APIRouter(prefix="/settings", tags=["settings"])


def _get_or_create_settings(session: SessionDep, user_id: str) -> SettingsModel:
    statement = select(SettingsModel).where(SettingsModel.user_id == user_id)
    settings = session.exec(statement).first()
    if settings:
        return settings

    settings = SettingsModel(user_id=user_id)
    session.add(settings)
    session.commit()
    session.refresh(settings)
    return settings


@router.get("", response_model=SettingsModel)
def get_settings(session: SessionDep, user_id: UserIdDep) -> SettingsModel:
    return _get_or_create_settings(session, user_id)


@router.put("", response_model=SettingsModel)
def update_settings(
    payload: SettingsUpdate,
    session: SessionDep,
    user_id: UserIdDep,
) -> SettingsModel:
    settings = _get_or_create_settings(session, user_id)
    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(settings, key, value)
    settings.updated_at = datetime.utcnow()

    session.add(settings)
    session.commit()
    session.refresh(settings)
    return settings
