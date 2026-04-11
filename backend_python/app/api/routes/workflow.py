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


@router.post('/suno/{project_name}')
def generate_suno_songs(project_name: str, channel_ids: list[str] | None = None) -> dict:
    """
    Generate Suno songs for all or specific channels in a project.
    
    Args:
        project_name: Name of the project
        channel_ids: Optional list of specific channel IDs to generate for (all enabled if not provided)
        
    Returns:
        Generation report with results for each channel
    """
    try:
        project = store.load_project(project_name).model_dump(mode='json')
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail='project not found') from exc
    
    # Filter channels if specific ones requested
    if channel_ids:
        project['channels'] = [ch for ch in project.get('channels', []) if ch['channel_id'] in channel_ids]
    
    # Run only the song generation step
    return runner.run(project, from_step=WorkflowStep.songs, to_step=WorkflowStep.songs)


@router.post('/midjourney/{project_name}')
def generate_midjourney_images(project_name: str, channel_ids: list[str] | None = None) -> dict:
    """
    Generate Midjourney images for all or specific channels in a project.
    """
    try:
        project = store.load_project(project_name).model_dump(mode='json')
    except FileNotFoundError as exc:
        raise HTTPException(status_code=404, detail='project not found') from exc
    
    if channel_ids:
        project['channels'] = [ch for ch in project.get('channels', []) if ch['channel_id'] in channel_ids]
    
    return runner.run(project, from_step=WorkflowStep.prompts, to_step=WorkflowStep.images)
