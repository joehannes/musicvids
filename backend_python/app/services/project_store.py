from __future__ import annotations

import json
from pathlib import Path

from app.models.schemas import ProjectConfig

PROJECT_SUBDIRS = ["songs", "images", "videos", "storyboards", "characters", "logs"]


class ProjectStore:
    def __init__(self, root: Path):
        self.root = root
        self.root.mkdir(parents=True, exist_ok=True)

    def list_projects(self) -> list[str]:
        return sorted([d.name for d in self.root.iterdir() if d.is_dir()])

    def create_project(self, name: str) -> ProjectConfig:
        project_dir = self.root / name
        project_dir.mkdir(parents=True, exist_ok=True)
        for sub in PROJECT_SUBDIRS:
            (project_dir / sub).mkdir(exist_ok=True)
        config = ProjectConfig(name=name, root_path=project_dir)
        self.save_project(config)
        return config

    def load_project(self, name: str) -> ProjectConfig:
        fp = self.root / name / "project.json"
        payload = json.loads(fp.read_text())
        payload["root_path"] = str(self.root / name)
        return ProjectConfig.model_validate(payload)

    def save_project(self, project: ProjectConfig) -> None:
        fp = project.root_path / "project.json"
        data = project.model_dump(mode="json")
        fp.write_text(json.dumps(data, indent=2, ensure_ascii=False))
