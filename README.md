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

---

## Xubuntu Linux: full local build + run instructions (terminal only)

These instructions target **Xubuntu 22.04/24.04** and produce a runnable Linux desktop build of the Flutter app plus the backend API.

### 0) Ensure Linux desktop platform files exist (fixes "No Linux desktop project configured")

This repo now includes `app_flutter/linux/` CMake runner files. If you ever recreate the Flutter app or those files are missing, regenerate platform support with:

```bash
cd app_flutter
flutter create . --platforms=linux
```

Then run:

```bash
flutter config --enable-linux-desktop
flutter doctor
```

### 1) Install system dependencies

Use the included script:

```bash
./scripts/install_deps_xubuntu.sh
```

Or install manually:

```bash
sudo apt update
sudo apt install -y \
  git curl unzip xz-utils zip tar ca-certificates \
  build-essential pkg-config cmake ninja-build clang \
  python3 python3-venv python3-pip python3-dev \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  ffmpeg frei0r-plugins
```

Install Flutter (if not installed by script):

```bash
sudo snap install flutter --classic
```

Then verify:

```bash
flutter --version
flutter doctor
ffmpeg -version
```

### 2) Clone repo + initialize submodules

```bash
git clone <your-repo-url> musicvids
cd musicvids
git submodule update --init --recursive
```

### 3) Setup Python backend environment

```bash
python3 -m venv backend_python/.venv
source backend_python/.venv/bin/activate
pip install --upgrade pip
pip install -e ./backend_python
```

Optional runtime dependencies for richer local pipeline behavior:

```bash
# WhisperX (GPU/CPU availability will change install details)
pip install whisperx

# Essentia Python bindings (if available for your environment)
pip install essentia
```

### 4) Setup Flutter desktop dependencies

```bash
cd app_flutter
flutter config --enable-linux-desktop
flutter pub get
cd ..
```

### 5) Run backend + desktop app (dev mode)

Terminal 1:

```bash
./scripts/run_backend.sh
```

Terminal 2:

```bash
./scripts/run_flutter.sh
```

Backend default URL: `http://127.0.0.1:8787`

### 6) Compile Flutter app to a runnable Xubuntu desktop binary

```bash
cd app_flutter
flutter build linux --release
```

Compiled output will be in:

```text
app_flutter/build/linux/x64/release/bundle/
```

Run the compiled app directly:

```bash
./app_flutter/build/linux/x64/release/bundle/musicvids_studio
```

### 7) Build an installable `.deb` package for Xubuntu

After `flutter build linux --release`, create a Debian package:

```bash
./scripts/package_linux_deb.sh 0.1.0
```

Output file:

```text
app_flutter/build/linux/x64/release/musicvids-studio_0.1.0_amd64.deb
```

Install locally:

```bash
sudo apt install -y ./app_flutter/build/linux/x64/release/musicvids-studio_0.1.0_amd64.deb
```

Run from terminal:

```bash
musicvids-studio
```

### 8) Optional: package tarball for portable deployment

```bash
cd app_flutter/build/linux/x64/release
tar -czf musicvids_studio_linux_bundle.tar.gz bundle/
```

Copy the `tar.gz` to another Linux machine, extract it, and run the binary from `bundle/`.

---

## Quick start (existing helper scripts)

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
