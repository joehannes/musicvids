from app.models.schemas import SceneAnalysis
from app.pipeline.transition_engine import TransitionEngine


def test_high_energy_prefers_fast_transition() -> None:
    engine = TransitionEngine()
    scene = SceneAnalysis(
        start=0,
        end=4,
        mood_current='intense',
        mood_previous='calm',
        mood_next='intense',
        energy=0.9,
        brightness=0.8,
        dynamic='rising',
    )
    decision = engine.decide(scene, None, None)
    assert decision.duration <= 0.8
    assert decision.transition in {'fadeblack', 'radial', 'pixelize'}
