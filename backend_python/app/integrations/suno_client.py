import json
import subprocess
from pathlib import Path
from typing import Any


class SunoClient:
    def __init__(self, repo_path: Path):
        self.repo_path = repo_path
        self.api_base_url = "http://localhost:3000/api"  # Default sunoapi URL

    def generate_song(
        self,
        prompt: str,
        lyrics: str,
        mood: str,
        channel_style: str,
        overall_style: str,
        title: str = "Generated Song",
        tags: str = "music, ai-generated",
    ) -> dict[str, Any]:
        """
        Generate a song via Suno API with merged prompt from lyrics + moods + styles.
        
        Args:
            prompt: Song title/descriptor
            lyrics: Full lyrics text
            mood: Overall generation mood (e.g. "upbeat, energetic")
            channel_style: Channel-specific style (e.g. "lo-fi, chill")
            overall_style: Overall style (e.g. "cinematic, orchestral")
            title: Song title
            tags: Genre/style tags
            
        Returns:
            Generation result with song_id and metadata
        """
        # Build comprehensive prompt combining all elements
        merged_prompt = f"""
Title: {title}
Style: {overall_style}, {channel_style}
Mood: {mood}
Tags: {tags}

Lyrics:
{lyrics}
"""
        try:
            # Call sunoapi generate endpoint
            cmd = [
                "curl",
                "-X",
                "POST",
                f"{self.api_base_url}/generate",
                "-H",
                "Content-Type: application/json",
                "-d",
                json.dumps(
                    {
                        "prompt": merged_prompt,
                        "make_instrumental": False,
                        "wait_audio": False,  # Non-blocking
                    }
                ),
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                return json.loads(result.stdout)
            else:
                return {"error": result.stderr, "status": "failed"}
        except Exception as e:
            return {"error": str(e), "status": "failed"}

    def generate_sections(self, prompt: str, count: int = 2) -> list[dict]:
        """
        Generate multiple song sections (legacy method for backward compatibility).
        """
        sections = []
        for i in range(count):
            result = self.generate_song(
                prompt=f"Section {i+1}",
                lyrics=prompt,
                mood="cinematic, inspiring",
                channel_style="",
                overall_style="cinematic",
            )
            sections.append(
                {
                    "section": i + 1,
                    "prompt": prompt,
                    "generation_result": result,
                    "audio_path": f"generated/section_{i+1}.wav",
                }
            )
        return sections
