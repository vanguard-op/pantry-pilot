from datetime import datetime

from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import SettingsModel, SettingsUpdate


class SettingsService:
    def __init__(self, session: SessionDep, user_id: UserIdDep) -> None:
        self._session = session
        self._user_id = user_id

    def get_or_create_settings(self) -> SettingsModel:
        statement = select(SettingsModel).where(SettingsModel.user_id == self._user_id)
        settings = self._session.exec(statement).first()
        if settings:
            return settings

        settings = SettingsModel(user_id=self._user_id)
        self._session.add(settings)
        self._session.commit()
        self._session.refresh(settings)
        return settings

    def update_settings(self, payload: SettingsUpdate) -> SettingsModel:
        settings = self.get_or_create_settings()
        updates = payload.model_dump(exclude_unset=True)
        for key, value in updates.items():
            setattr(settings, key, value)
        settings.updated_at = datetime.utcnow()

        self._session.add(settings)
        self._session.commit()
        self._session.refresh(settings)
        return settings
