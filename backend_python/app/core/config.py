from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class AppSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="MVID_", env_file=".env", extra="ignore")

    projects_root: Path = Path("../projects")
    config_file: Path = Path("../shared/settings.json")
    suno_repo: Path = Path("../sunoapi")
    midjourney_repo: Path = Path("../midjourney")


settings = AppSettings()
