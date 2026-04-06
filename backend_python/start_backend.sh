#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$ROOT_DIR/.venv_runtime"
LOG_DIR="${HOME}/.config/musicvids_studio/logs"
LOG_FILE="$LOG_DIR/backend.log"
PID_FILE="$LOG_DIR/backend.pid"
DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/musicvids_studio"
PROJECTS_ROOT="$DATA_ROOT/projects"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/musicvids_studio"
SETTINGS_FILE="$CONFIG_ROOT/settings/settings.json"

mkdir -p "$LOG_DIR"
mkdir -p "$PROJECTS_ROOT"
mkdir -p "$CONFIG_ROOT/settings"

if [ -f "$PID_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    exit 0
  fi
fi

if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/pip" install --upgrade pip >>"$LOG_FILE" 2>&1
  "$VENV_DIR/bin/pip" install -e "$ROOT_DIR" >>"$LOG_FILE" 2>&1
fi

export MVID_PROJECTS_ROOT="$PROJECTS_ROOT"
export MVID_CONFIG_FILE="$SETTINGS_FILE"

cd "$ROOT_DIR"
nohup "$VENV_DIR/bin/python" -m uvicorn app.main:app --host 127.0.0.1 --port 8787 --app-dir "$ROOT_DIR" >>"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"
