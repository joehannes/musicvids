import json
from pathlib import Path
from typing import Any


class SettingsStore:
    def __init__(self, path: Path):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self.save(self.default())

    @staticmethod
    def default() -> dict[str, Any]:
        return {
            "suno": {"token": "", "base_url": ""},
            "midjourney": {"discord_token": "", "proxy_url": ""},
            "youtube": {"api_key": "", "channel_ids": []},
            "tiktok": {"username": "", "password": ""},
            "openai": {"api_key": ""},
        }

    def load(self) -> dict[str, Any]:
        return json.loads(self.path.read_text())

    def save(self, payload: dict[str, Any]) -> None:
        self.path.write_text(json.dumps(payload, indent=2, ensure_ascii=False))
