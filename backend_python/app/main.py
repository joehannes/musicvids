from fastapi import FastAPI

from app.api.routes import health, projects, workflow, settings

app = FastAPI(title="MusicVid Studio Backend", version="0.1.0")

app.include_router(health.router, prefix="/api")
app.include_router(settings.router, prefix="/api/settings", tags=["settings"])
app.include_router(projects.router, prefix="/api/projects", tags=["projects"])
app.include_router(workflow.router, prefix="/api/workflow", tags=["workflow"])
