from typing import Any


class UploadService:
    def upload_youtube(self, video_path: str, metadata: dict[str, Any]) -> dict[str, Any]:
        channel_update = self.prepare_youtube_channel_update(metadata.get("channel", {}))
        video_insert = self.prepare_youtube_video_insert(video_path, metadata.get("video", {}))
        return {
            "platform": "youtube",
            "status": "prepared",
            "video_path": video_path,
            "channel_update": channel_update,
            "video_insert": video_insert,
        }

    def prepare_youtube_channel_update(self, channel: dict[str, Any]) -> dict[str, Any]:
        return {
            "part": "snippet,brandingSettings,status,localizations",
            "body": {
                "id": channel.get("youtube_channel_id") or channel.get("channel_id", ""),
                "snippet": {
                    "title": channel.get("title", ""),
                    "description": channel.get("description", ""),
                    "defaultLanguage": channel.get("yt_default_language") or channel.get("language", "en"),
                    "country": channel.get("yt_country", ""),
                },
                "brandingSettings": {
                    "channel": {
                        "keywords": channel.get("keywords", ""),
                    }
                },
                "status": {
                    "selfDeclaredMadeForKids": channel.get("yt_self_declared_made_for_kids"),
                },
                "localizations": channel.get("yt_localizations", {}),
            },
        }

    def prepare_youtube_video_insert(self, video_path: str, video: dict[str, Any]) -> dict[str, Any]:
        return {
            "part": "snippet,status,recordingDetails",
            "notifySubscribers": bool(video.get("notify_subscribers", False)),
            "media_body": video_path,
            "body": {
                "snippet": {
                    "title": video.get("title", ""),
                    "description": video.get("description", ""),
                    "tags": video.get("tags", []),
                    "categoryId": str(video.get("category_id", "10")),
                    "defaultLanguage": video.get("default_language", "en"),
                    "defaultAudioLanguage": video.get("default_audio_language", "en"),
                },
                "status": {
                    "privacyStatus": video.get("privacy_status", "private"),
                    "selfDeclaredMadeForKids": video.get("self_declared_made_for_kids", False),
                    "publishAt": video.get("publish_at", ""),
                    "embeddable": video.get("embeddable", True),
                    "publicStatsViewable": video.get("public_stats_viewable", True),
                    "license": video.get("license", "youtube"),
                },
                "recordingDetails": {
                    "recordingDate": video.get("recording_date", ""),
                },
            },
        }

    def upload_tiktok(self, video_path: str, metadata: dict[str, Any]) -> dict[str, Any]:
        return {'platform': 'tiktok', 'status': 'stub', 'video_path': video_path, 'metadata': metadata}
