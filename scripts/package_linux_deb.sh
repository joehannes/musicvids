#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app_flutter"
BUILD_BUNDLE="$APP_DIR/build/linux/x64/release/bundle"
PKG_ROOT="$APP_DIR/build/linux/x64/release/deb_pkg"
VERSION="${1:-0.2.0}"
ARCH="amd64"
PKG_NAME="musicvids-studio"

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "dpkg-deb not found. Install with: sudo apt install -y dpkg-dev"
  exit 1
fi

if [ ! -d "$BUILD_BUNDLE" ]; then
  echo "Release bundle not found. Run:"
  echo "  cd app_flutter && flutter build linux --release"
  exit 1
fi

rm -rf "$PKG_ROOT"
mkdir -p "$PKG_ROOT/DEBIAN"
mkdir -p "$PKG_ROOT/opt/$PKG_NAME"
mkdir -p "$PKG_ROOT/usr/bin"
mkdir -p "$PKG_ROOT/usr/share/applications"

cp -r "$BUILD_BUNDLE"/* "$PKG_ROOT/opt/$PKG_NAME/"

cat > "$PKG_ROOT/usr/bin/musicvids-studio" <<'LAUNCHER'
#!/usr/bin/env bash
exec /opt/musicvids-studio/musicvids_studio "$@"
LAUNCHER
chmod +x "$PKG_ROOT/usr/bin/musicvids-studio"

cat > "$PKG_ROOT/usr/share/applications/musicvids-studio.desktop" <<'DESKTOP'
[Desktop Entry]
Name=MusicVid Studio
Comment=Local-first AI music video generation studio
Exec=/usr/bin/musicvids-studio
Terminal=false
Type=Application
Categories=AudioVideo;Video;
DESKTOP

cat > "$PKG_ROOT/DEBIAN/control" <<EOF2
Package: $PKG_NAME
Version: $VERSION
Section: video
Priority: optional
Architecture: $ARCH
Maintainer: MusicVid Studio Team
Depends: libgtk-3-0, libstdc++6
Description: Local-first AI music video generation studio
EOF2

dpkg-deb --build "$PKG_ROOT" "$APP_DIR/build/linux/x64/release/${PKG_NAME}_${VERSION}_${ARCH}.deb"

echo "Built package: $APP_DIR/build/linux/x64/release/${PKG_NAME}_${VERSION}_${ARCH}.deb"
