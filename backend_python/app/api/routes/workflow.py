from fastapi import APIRouter, HTTPException

from app.core.config import settings as app_settings
from app.models.schemas import WorkflowStep
from app.services.project_store import ProjectStore
from app.services.workflow_runner import WorkflowRunner

router = APIRouter()
store = ProjectStore(app_settings.projects_root)
runner = WorkflowRunner(app_settings.suno_repo, app_settings.midjourney_repo)


@router.post('/run/{project_name}')
def run_workflow(project_name: str, from_step: WorkflowStep = WorkflowStep.songs, to_step: WorkflowStep = WorkflowStep.upload) -> dict:
    try:
        project = store.load_project(project_name).model_dump(mode='json')
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail='project not found') from exc
    return runner.run(project, from_step=from_step, to_step=to_step)
