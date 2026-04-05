#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/backend_python/.venv/bin/activate"
cd "$ROOT_DIR/backend_python"
uvicorn app.main:app --host 127.0.0.1 --port 8787 --reload
