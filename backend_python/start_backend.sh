#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$ROOT_DIR/.venv_runtime"
LOG_DIR="${HOME}/.config/musicvids_studio/logs"
LOG_FILE="$LOG_DIR/backend.log"
PID_FILE="$LOG_DIR/backend.pid"

mkdir -p "$LOG_DIR"

if [ -f "$PID_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    exit 0
  fi
fi

if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

if "$VENV_DIR/bin/python" -c "import setuptools.build_meta" >/dev/null 2>&1; then
  if ! "$VENV_DIR/bin/pip" install --no-build-isolation --no-deps -e "$ROOT_DIR" >>"$LOG_FILE" 2>&1; then
    echo "WARN: editable install failed; falling back to PYTHONPATH startup." >>"$LOG_FILE"
  fi
else
  echo "WARN: setuptools.build_meta unavailable in runtime venv; skipping editable install." >>"$LOG_FILE"
fi

PYTHON_BIN="$VENV_DIR/bin/python"
if ! "$PYTHON_BIN" -c "import uvicorn" >/dev/null 2>&1; then
  echo "WARN: uvicorn not available in runtime venv; using system python." >>"$LOG_FILE"
  PYTHON_BIN="python3"
fi

PYTHONPATH="$ROOT_DIR:${PYTHONPATH:-}" setsid "$PYTHON_BIN" -m uvicorn app.main:app --host 127.0.0.1 --port 8787 >>"$LOG_FILE" 2>&1 < /dev/null &
echo $! >"$PID_FILE"
