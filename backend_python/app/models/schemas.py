from __future__ import annotations

from enum import Enum
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field


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
    channel_id: str
    language: str
    title: str
    description: str
    vibe: str
    visual_style: str
    enabled: bool = True


class ProjectConfig(BaseModel):
    name: str
    root_path: Path
    lyrics: dict[str, dict[str, Any]] = Field(default_factory=dict)
    channels: list[ChannelProfile] = Field(default_factory=list)
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
