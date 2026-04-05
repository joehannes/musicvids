from typing import Any


class UploadService:
    def upload_youtube(self, video_path: str, metadata: dict[str, Any]) -> dict[str, Any]:
        return {'platform': 'youtube', 'status': 'stub', 'video_path': video_path, 'metadata': metadata}

    def upload_tiktok(self, video_path: str, metadata: dict[str, Any]) -> dict[str, Any]:
        return {'platform': 'tiktok', 'status': 'stub', 'video_path': video_path, 'metadata': metadata}
