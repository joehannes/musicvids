#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 -m venv "$ROOT_DIR/backend_python/.venv"
source "$ROOT_DIR/backend_python/.venv/bin/activate"
pip install -e "$ROOT_DIR/backend_python"

if command -v flutter >/dev/null 2>&1; then
  (cd "$ROOT_DIR/app_flutter" && flutter pub get)
else
  echo "flutter not found; install Flutter SDK to run desktop UI"
fi

echo "Setup complete."
