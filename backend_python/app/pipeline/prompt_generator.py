from typing import Any

from app.models.schemas import SceneAnalysis


def build_prompts(storyboard: dict[str, Any], channel: dict[str, Any], scenes: list[SceneAnalysis]) -> dict:
    prompt_scenes = []
    sb_scenes = storyboard.get('scenes', [])
    for i, scene in enumerate(scenes):
        sb = sb_scenes[i] if i < len(sb_scenes) else {}
        imagery = sb.get('imagery', 'abstract cinematic composition')
        text = sb.get('text', '')
        prompt = (
            f"{imagery}, style={channel.get('visual_style','cinematic')}, mood={scene.mood_current}, "
            f"transition context prev={scene.mood_previous} next={scene.mood_next}, lyrics={text}"
        )
        prompt_scenes.append(
            {
                'start': scene.start,
                'end': scene.end,
                'prompt': prompt,
                'mood': scene.mood_current,
                'transition_hint': 'dynamic cut' if scene.energy > 0.7 else 'soft dissolve',
                'effect_hint': 'glow+zoom' if scene.brightness > 0.7 else 'subtle grain',
            }
        )
    return {'scenes': prompt_scenes}
