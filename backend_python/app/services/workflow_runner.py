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
        lyrics_data = project.get('lyrics', {})
        generation_moods = project.get('generation_moods', {})
        
        music_mood = generation_moods.get('music_mood', 'cinematic, inspiring')
        image_mood = generation_moods.get('image_mood', 'photorealistic, cinematic')
        video_mood = generation_moods.get('video_mood', 'smooth transitions, dynamic')
        
        # Extract lyrics tone/notes if available
        tone_notes = (lyrics_data.get('tone_notes') or 'neutral').strip()
        
        for channel in channels:
            if not channel.get('enabled', True):
                continue
                
            channel_id = channel['channel_id']
            channel_language = channel.get('language', 'en')
            song_dir = root / 'songs' / channel_id
            image_dir = root / 'images' / channel_id
            video_dir = root / 'videos' / channel_id
            
            for d in (song_dir, image_dir, video_dir):
                d.mkdir(parents=True, exist_ok=True)

            # SONG GENERATION STEP
            if from_step <= WorkflowStep.songs <= to_step:
                # Extract lyrics for this channel's language
                channel_lyrics = self._extract_lyrics_for_language(lyrics_data, channel_language)
                
                # Get channel-specific styles
                overall_style = channel.get('overall_style', 'cinematic')
                channel_style = channel.get('channel_style', '')
                vibe = channel.get('vibe', 'cinematic')
                
                # Merge moods: music_mood + channel_style + tone_notes + vibe
                merged_mood = f"{music_mood}, {tone_notes}, {vibe}".strip(', ')
                
                # Generate song via Suno
                song_result = self.suno.generate_song(
                    prompt=f"{channel['title']} - {channel_language}",
                    lyrics=channel_lyrics,
                    mood=merged_mood,
                    channel_style=channel_style,
                    overall_style=overall_style,
                    title=f"{channel['title']} ({channel_language})",
                    tags=f"{overall_style}, {channel_style}, {vibe}",
                )
                
                (song_dir / 'generation_result.json').write_text(json.dumps(song_result, indent=2))
                report['steps'].append({
                    'channel': channel_id,
                    'step': 'songs',
                    'language': channel_language,
                    'mood': merged_mood,
                    'status': 'generated' if song_result.get('status') != 'failed' else 'failed',
                    'result': song_result,
                })

            # AUDIO ANALYSIS STEP
            if from_step <= WorkflowStep.analyze <= to_step:
                audio_path = song_dir / 'final.wav'
                if not audio_path.exists():
                    audio_path.write_bytes(b'')
                    
                whisper = run_whisperx(audio_path)
                analyses = run_essentia(audio_path, whisper['segments'])
                (song_dir / 'analysis.json').write_text(json.dumps([a.model_dump() for a in analyses], indent=2))
                report['steps'].append({'channel': channel_id, 'step': 'analyze', 'status': 'complete'})

            # PROMPT GENERATION STEP
            if from_step <= WorkflowStep.prompts <= to_step:
                prompts = build_prompts(storyboard, channel, [])
                (root / 'storyboards' / f'{channel_id}_prompts.json').write_text(json.dumps(prompts, indent=2))
                report['steps'].append({
                    'channel': channel_id,
                    'step': 'prompts',
                    'image_mood': image_mood,
                    'generated': len(prompts.get('scenes', [])),
                })

            # IMAGE GENERATION STEP
            if from_step <= WorkflowStep.images <= to_step:
                prompts_path = root / 'storyboards' / f'{channel_id}_prompts.json'
                if prompts_path.exists():
                    prompts = json.loads(prompts_path.read_text())
                else:
                    prompts = {'scenes': []}
                    
                images = []
                for idx, s in enumerate(prompts.get('scenes', [])):
                    # Augment image prompt with image_mood
                    augmented_prompt = f"{s.get('prompt', '')} {image_mood}"
                    generated = self.midjourney.generate_image(augmented_prompt, variations=1)
                    out = image_dir / f'scene_{idx:03}.png'
                    out.write_bytes(b'')
                    images.append(out)
                    (image_dir / f'scene_{idx:03}.json').write_text(json.dumps(generated, indent=2))
                    
                report['steps'].append({'channel': channel_id, 'step': 'images', 'generated': len(images)})

            # VIDEO RENDERING STEP
            if from_step <= WorkflowStep.videos <= to_step:
                target = RenderTarget(aspect='16:9', width=1920, height=1080)
                analyses = []
                audio_path = song_dir / 'final.wav'
                images_list = list((image_dir).glob('scene_*.png')) or [image_dir / 'scene_000.png']
                
                cmd = self.ffmpeg.build(images_list, analyses, audio_path, video_dir / 'final_16x9.mp4', target)
                (video_dir / 'render_command.sh').write_text(' '.join(cmd))
                
                try:
                    subprocess.run(cmd, check=False, capture_output=True, timeout=300)
                    report['steps'].append({'channel': channel_id, 'step': 'videos', 'status': 'complete', 'video_mood': video_mood})
                except FileNotFoundError:
                    report['errors'].append({'channel': channel_id, 'step': 'videos', 'error': 'ffmpeg not installed'})
                except subprocess.TimeoutExpired:
                    report['errors'].append({'channel': channel_id, 'step': 'videos', 'error': 'rendering timeout'})

        return report

    def _extract_lyrics_for_language(self, lyrics_data: dict[str, Any], language: str) -> str:
        """Extract the full lyrics text for a specific language from the lyrics section."""
        if not lyrics_data or not language:
            return "Instrumental"
            
        blocks = lyrics_data.get('blocks', [])
        lyric_lines = []
        
        for block in blocks:
            if isinstance(block, dict):
                texts = block.get('texts', {})
                if isinstance(texts, dict):
                    line = texts.get(language, '').strip()
                    if line:
                        lyric_lines.append(line)
        
        return '\n'.join(lyric_lines) if lyric_lines else "Instrumental"
