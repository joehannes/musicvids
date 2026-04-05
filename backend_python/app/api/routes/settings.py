from typing import Any

from fastapi import APIRouter

from app.core.config import settings as app_settings
from app.services.settings_store import SettingsStore

router = APIRouter()
store = SettingsStore(app_settings.config_file)


@router.get('')
def get_settings() -> dict[str, Any]:
    return store.load()


@router.put('')
def put_settings(payload: dict[str, Any]) -> dict[str, str]:
    store.save(payload)
    return {'status': 'saved'}
