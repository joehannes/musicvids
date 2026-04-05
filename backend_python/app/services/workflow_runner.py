from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

from app.integrations.midjourney_client import MidjourneyClient
from app.integrations.suno_client import SunoClient
from app.models.schemas import WorkflowStep
from app.pipeline.audio_analysis import run_essentia, run_whisperx
from app.pipeline.ffmpeg_builder import FFmpegCommandBuilder, RenderTarget
from app.pipeline.prompt_generator import build_prompts


class WorkflowRunner:
    def __init__(self, suno_repo: Path, midjourney_repo: Path):
        self.suno = SunoClient(suno_repo)
        self.midjourney = MidjourneyClient(midjourney_repo)
        self.ffmpeg = FFmpegCommandBuilder()

    def run(self, project: dict[str, Any], from_step: WorkflowStep = WorkflowStep.songs, to_step: WorkflowStep = WorkflowStep.upload) -> dict[str, Any]:
        report: dict[str, Any] = {'steps': [], 'errors': []}
        root = Path(project['root_path'])
        channels = project.get('channels', [])
        storyboard = project.get('storyboard', {})
        for channel in channels:
            if not channel.get('enabled', True):
                continue
            channel_id = channel['channel_id']
            song_dir = root / 'songs' / channel_id
            image_dir = root / 'images' / channel_id
            video_dir = root / 'videos' / channel_id
            for d in (song_dir, image_dir, video_dir):
                d.mkdir(parents=True, exist_ok=True)

            sections = self.suno.generate_sections(channel.get('vibe', 'cinematic music'))
            (song_dir / 'sections.json').write_text(json.dumps(sections, indent=2))
            report['steps'].append({'channel': channel_id, 'step': 'songs', 'generated': len(sections)})

            audio_path = song_dir / 'final.wav'
            if not audio_path.exists():
                audio_path.write_bytes(b'')
            whisper = run_whisperx(audio_path)
            analyses = run_essentia(audio_path, whisper['segments'])
            (song_dir / 'analysis.json').write_text(json.dumps([a.model_dump() for a in analyses], indent=2))

            prompts = build_prompts(storyboard, channel, analyses)
            (root / 'storyboards' / f'{channel_id}_prompts.json').write_text(json.dumps(prompts, indent=2))
            report['steps'].append({'channel': channel_id, 'step': 'prompts', 'generated': len(prompts['scenes'])})

            images = []
            for idx, s in enumerate(prompts['scenes']):
                generated = self.midjourney.generate_image(s['prompt'], variations=1)
                out = image_dir / f'scene_{idx:03}.png'
                out.write_bytes(b'')
                images.append(out)
                (image_dir / f'scene_{idx:03}.json').write_text(json.dumps(generated, indent=2))
            report['steps'].append({'channel': channel_id, 'step': 'images', 'generated': len(images)})

            target = RenderTarget(aspect='16:9', width=1920, height=1080)
            cmd = self.ffmpeg.build(images or [image_dir / 'scene_000.png'], analyses, audio_path, video_dir / 'final_16x9.mp4', target)
            (video_dir / 'render_command.sh').write_text(' '.join(cmd))
            try:
                subprocess.run(cmd, check=False, capture_output=True)
            except FileNotFoundError:
                report['errors'].append({'channel': channel_id, 'step': 'videos', 'error': 'ffmpeg not installed'})
            report['steps'].append({'channel': channel_id, 'step': 'videos', 'status': 'attempted'})

        return report
