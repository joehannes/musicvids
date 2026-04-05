from app.models.schemas import SceneAnalysis, TransitionDecision


class TransitionEngine:
    """Rule-based transition/effect mapper for FFmpeg filter graph synthesis."""

    def decide(self, scene_current: SceneAnalysis, scene_previous: SceneAnalysis | None, scene_next: SceneAnalysis | None) -> TransitionDecision:
        transition = 'fade'
        duration = 1.0
        effects: list[str] = []

        if scene_current.energy > 0.75:
            transition, duration = 'fadeblack', 0.45
        elif scene_current.energy < 0.30:
            transition, duration = 'fade', 1.5

        if scene_current.dynamic == 'rising':
            effects.append('zoompan=z=\'min(zoom+0.0015,1.25)\':d=1')
            transition = 'radial'
        elif scene_current.dynamic == 'falling':
            effects.append('eq=contrast=0.95:brightness=-0.02')

        if scene_current.brightness > 0.7:
            effects.append('frei0r=glow:0.6')

        if scene_previous and scene_previous.mood_current != scene_current.mood_current:
            transition = 'pixelize'
            duration = min(duration, 0.8)

        if scene_previous and scene_previous.energy < 0.4 and scene_current.energy > 0.7:
            duration = 0.4
        if scene_previous and scene_previous.energy > 0.7 and scene_current.energy < 0.4:
            duration = 1.3

        snippet = f"xfade=transition={transition}:duration={duration}:offset={{offset}}"
        return TransitionDecision(transition=transition, duration=duration, effects=effects, filter_snippet=snippet)
