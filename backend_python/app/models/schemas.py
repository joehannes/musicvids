from __future__ import annotations

from enum import Enum
from pathlib import Path
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class WorkflowStep(str, Enum):
    songs = "songs"
    analyze = "analyze"
    prompts = "prompts"
    images = "images"
    videos = "videos"
    upload = "upload"


class Scene(BaseModel):
    text: str
    imagery: str
    type: str = "single"
    manualStart: float | None = None
    manualEnd: float | None = None


class Storyboard(BaseModel):
    globalMood: str
    scenes: list[Scene] = Field(default_factory=list)


class ChannelProfile(BaseModel):
    model_config = ConfigDict(extra="allow")

    channel_id: str
    youtube_channel_id: str = ""
    language: str
    title: str
    handle: str = ""
    description: str
    keywords: str = ""
    brand_category: str = ""
    overall_style: str = "cinematic"
    channel_style: str = ""
    vibe: str
    visual_style: str
    enabled: bool = True
    yt_custom_url: str = ""
    yt_country: str = ""
    yt_default_language: str = ""
    yt_published_at: str = ""
    yt_subscriber_count: int = 0
    yt_video_count: int = 0
    yt_view_count: int = 0
    yt_hidden_subscriber_count: bool = False
    yt_is_linked: bool = False
    yt_made_for_kids: bool | None = None
    yt_self_declared_made_for_kids: bool | None = None
    yt_privacy_status: str = ""
    yt_branding: dict[str, Any] = Field(default_factory=dict)
    yt_topic_ids: list[str] = Field(default_factory=list)
    yt_topic_categories: list[str] = Field(default_factory=list)
    yt_localizations: dict[str, Any] = Field(default_factory=dict)
    yt_sync_source: str = ""
    yt_synced_at: str = ""


class GenerationMoods(BaseModel):
    music_mood: str = "cinematic, inspiring"
    image_mood: str = "photorealistic, cinematic"
    video_mood: str = "smooth transitions, dynamic"


class ProjectConfig(BaseModel):
    model_config = ConfigDict(extra="allow")

    name: str
    root_path: Path
    lyrics: dict[str, dict[str, Any]] = Field(default_factory=dict)
    channels: list[ChannelProfile] = Field(default_factory=list)
    generation_moods: GenerationMoods = Field(default_factory=GenerationMoods)
    storyboard: Storyboard = Field(default_factory=lambda: Storyboard(globalMood="cinematic", scenes=[]))
    characters: list[dict[str, Any]] = Field(default_factory=list)


class TransitionDecision(BaseModel):
    transition: str
    duration: float
    effects: list[str]
    filter_snippet: str


class SceneAnalysis(BaseModel):
    start: float
    end: float
    mood_current: str
    mood_previous: str
    mood_next: str
    energy: float
    brightness: float
    dynamic: str
