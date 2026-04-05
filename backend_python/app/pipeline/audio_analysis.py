from __future__ import annotations

from pathlib import Path

from app.models.schemas import SceneAnalysis


def run_whisperx(audio_path: Path) -> dict:
    # Placeholder integration point for WhisperX CLI / Python API.
    return {
        'segments': [
            {'start': 0.0, 'end': 5.0, 'text': 'First line'},
            {'start': 5.0, 'end': 10.0, 'text': 'Second line'},
        ],
        'words': [],
    }


def run_essentia(audio_path: Path, segments: list[dict]) -> list[SceneAnalysis]:
    # Placeholder deterministic fallback metrics when essentia is unavailable.
    output: list[SceneAnalysis] = []
    moods = ['calm', 'hopeful', 'intense']
    for i, seg in enumerate(segments):
        output.append(
            SceneAnalysis(
                start=seg['start'],
                end=seg['end'],
                mood_current=moods[i % len(moods)],
                mood_previous=moods[(i - 1) % len(moods)],
                mood_next=moods[(i + 1) % len(moods)],
                energy=min(1.0, 0.3 + (i * 0.25)),
                brightness=min(1.0, 0.4 + (i * 0.2)),
                dynamic='rising' if i % 2 == 0 else 'falling',
            )
        )
    return output
