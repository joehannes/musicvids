from pathlib import Path


class MidjourneyClient:
    def __init__(self, repo_path: Path):
        self.repo_path = repo_path

    def generate_image(self, prompt: str, variations: int = 1) -> list[dict]:
        return [{"prompt": prompt, "index": i, "path": f"images/{i}.png"} for i in range(variations)]
