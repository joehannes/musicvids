from fastapi import APIRouter, HTTPException

from app.core.config import settings as app_settings
from app.models.schemas import ProjectConfig
from app.services.project_store import ProjectStore

router = APIRouter()
store = ProjectStore(app_settings.projects_root)


@router.get('')
def list_projects() -> list[str]:
    return store.list_projects()


@router.post('/{name}', response_model=ProjectConfig)
def create_project(name: str) -> ProjectConfig:
    return store.create_project(name)


@router.get('/{name}', response_model=ProjectConfig)
def get_project(name: str) -> ProjectConfig:
    try:
        return store.load_project(name)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail='project not found') from exc


@router.put('/{name}', response_model=dict)
def save_project(name: str, payload: ProjectConfig) -> dict[str, str]:
    if payload.name != name:
        raise HTTPException(status_code=400, detail='name mismatch')
    store.save_project(payload)
    return {'status': 'saved'}
