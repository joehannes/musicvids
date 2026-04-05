from pathlib import Path


class SunoClient:
    def __init__(self, repo_path: Path):
        self.repo_path = repo_path

    def generate_sections(self, prompt: str, count: int = 2) -> list[dict]:
        return [
            {"section": i + 1, "prompt": prompt, "audio_path": f"generated/section_{i+1}.wav"}
            for i in range(count)
        ]
