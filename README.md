# MusicVid Studio Monorepo

Production-oriented local-first AI music video studio with Flutter desktop UI + Python orchestration pipeline.

## Directory layout

- `app_flutter/` Desktop application (Flutter, Dart)
- `backend_python/` FastAPI backend and generation pipeline
- `sunoapi/` Suno integration repository (submodule/checked-out)
- `midjourney/` Midjourney integration repository (submodule/checked-out)
- `shared/` Persistent shared settings (`settings.json`)
- `scripts/` Setup and runtime scripts
- `projects/` User project runtime data (never auto-deleted)
- `docs/` Architecture and operational docs

## Quick start (Linux/macOS)

```bash
./scripts/setup.sh
./scripts/run_backend.sh
# new shell
./scripts/run_flutter.sh
```

## Core backend capabilities
- Project create/load/save with durable filesystem model.
- Persistent settings for Suno, Midjourney, YouTube, TikTok, OpenAI.
- Workflow execution endpoint with resumable artifact writing.
- Audio analysis placeholders for WhisperX + Essentia integration points.
- Transition engine implementing rule-based decisions from scene energy/dynamics/brightness/mood shifts.
- FFmpeg filter graph command synthesis including xfade, zoompan, eq, and optional frei0r effects.

## API endpoints
- `GET /api/health`
- `GET|PUT /api/settings`
- `GET|POST|PUT /api/projects`
- `POST /api/workflow/run/{project_name}`

## Notes on integrations
- Suno and Midjourney are wrapped by adapters under `backend_python/app/integrations/`.
- Replace adapter placeholders with concrete calls to each submodule's API client/CLI.
- Install system tools: `ffmpeg`, optional frei0r plugin pack, WhisperX deps, Essentia deps.
