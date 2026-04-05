# Architecture Overview

## Monorepo layers
- `app_flutter`: low-resource desktop UX for project-driven workflows.
- `backend_python`: deterministic workflow engine + local API.
- `shared`: settings + schema-like shared documents.
- `projects`: immutable outputs and runtime state.

## Workflow steps
1. Song generation (Suno adapter)
2. WhisperX + Essentia analysis
3. Prompt generation
4. Midjourney image generation
5. FFmpeg video rendering with transition engine
6. Optional uploads

## Determinism and resilience
- Each step writes explicit JSON artifacts in project folders.
- Workflow can resume from persisted artifacts.
- Steps are isolated and can continue even with partial failures.
