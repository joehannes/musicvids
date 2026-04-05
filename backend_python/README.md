# Backend Python

FastAPI orchestration layer for local-first music-video generation.

## Run

```bash
cd backend_python
python -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn app.main:app --reload --port 8787
```

## Notes
- Integrates local submodules at `/sunoapi` and `/midjourney` through adapters.
- FFmpeg/frei0r availability is detected at runtime.
- Projects are persisted under `/projects/<project_name>` and never auto-deleted.
