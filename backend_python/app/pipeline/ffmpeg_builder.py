from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from app.models.schemas import SceneAnalysis
from app.pipeline.transition_engine import TransitionEngine


@dataclass
class RenderTarget:
    aspect: str  # '16:9' or '9:16'
    width: int
    height: int


class FFmpegCommandBuilder:
    def __init__(self) -> None:
        self.transition_engine = TransitionEngine()

    def _scene_filter(self, idx: int, analysis: SceneAnalysis, use_frei0r: bool) -> str:
        chain = [f"[{idx}:v]scale=1920:1080,setsar=1"]
        if analysis.dynamic == 'rising':
            chain.append("zoompan=z='min(zoom+0.0012,1.2)':d=1")
        if analysis.brightness > 0.65:
            chain.append('eq=brightness=0.03:contrast=1.05')
        if use_frei0r:
            chain.append('frei0r=grain:0.15')
        return ','.join(chain) + f"[v{idx}]"

    def build(self, image_inputs: list[Path], analyses: list[SceneAnalysis], audio_path: Path, output_path: Path, target: RenderTarget, use_frei0r: bool = True) -> list[str]:
        if len(image_inputs) != len(analyses):
            raise ValueError('image_inputs and analyses must match')

        filters: list[str] = []
        for i, analysis in enumerate(analyses):
            filters.append(self._scene_filter(i, analysis, use_frei0r))

        current_stream = '[v0]'
        offset = 0.0
        for i in range(1, len(analyses)):
            decision = self.transition_engine.decide(analyses[i], analyses[i - 1], analyses[i + 1] if i + 1 < len(analyses) else None)
            filters.append(f"{current_stream}[v{i}]{decision.filter_snippet.format(offset=round(offset, 2))}[vx{i}]")
            current_stream = f"[vx{i}]"
            for effect in decision.effects:
                filters.append(f"{current_stream}{effect}[fx{i}]")
                current_stream = f"[fx{i}]"
            offset += max(0.1, analyses[i].end - analyses[i].start - decision.duration)

        filter_complex = ';'.join(filters)
        cmd = ['ffmpeg', '-y']
        for image in image_inputs:
            cmd += ['-loop', '1', '-t', '4', '-i', str(image)]
        cmd += ['-i', str(audio_path), '-filter_complex', filter_complex, '-map', current_stream, '-map', f'{len(image_inputs)}:a', '-shortest', '-s', f'{target.width}x{target.height}', str(output_path)]
        return cmd
