#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_RELEASE_DIR="$ROOT_DIR/app_flutter/build/linux/x64/release"

"$ROOT_DIR/scripts/package_linux_deb.sh" "$@"

LATEST_DEB="$(ls -t "$APP_RELEASE_DIR"/musicvids-studio_*_amd64.deb | head -n 1)"
if [[ -z "${LATEST_DEB:-}" ]]; then
  echo "No deb package found in $APP_RELEASE_DIR"
  exit 1
fi

echo "Installing package: $LATEST_DEB"
if command -v sudo >/dev/null 2>&1; then
  sudo dpkg -i "$LATEST_DEB"
else
  dpkg -i "$LATEST_DEB"
fi

echo "Installation complete."
