from fastapi import APIRouter, Depends

from app.models import SettingsModel, SettingsUpdate
from app.services.settings_service import SettingsService

router = APIRouter(prefix="/settings", tags=["settings"])


@router.get("", response_model=SettingsModel)
def get_settings(service: SettingsService = Depends()) -> SettingsModel:
    return service.get_or_create_settings()


@router.put("", response_model=SettingsModel)
def update_settings(
    payload: SettingsUpdate,
    service: SettingsService = Depends(),
) -> SettingsModel:
    return service.update_settings(payload)
