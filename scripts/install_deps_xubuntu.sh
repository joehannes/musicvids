#!/usr/bin/env bash
set -euo pipefail

# Xubuntu/Ubuntu dependency bootstrap for local compilation and runtime.

sudo apt update
sudo apt install -y \
  git curl unzip xz-utils zip tar ca-certificates \
  build-essential pkg-config cmake ninja-build clang \
  python3 python3-venv python3-pip python3-dev \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  ffmpeg frei0r-plugins

if ! command -v flutter >/dev/null 2>&1; then
  if command -v snap >/dev/null 2>&1; then
    sudo snap install flutter --classic
  else
    echo "snap is not available. Install Flutter SDK manually from https://docs.flutter.dev/get-started/install/linux"
  fi
fi

echo "Dependency bootstrap complete."
