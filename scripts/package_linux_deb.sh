#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app_flutter"
BACKEND_DIR="$ROOT_DIR/backend_python"
BUILD_BUNDLE="$APP_DIR/build/linux/x64/release/bundle"
PKG_ROOT="$APP_DIR/build/linux/x64/release/deb_pkg"

CURRENT_PUBSPEC_VERSION=$(awk '/^version:/{print $2; exit}' "$APP_DIR/pubspec.yaml")
CURRENT_CORE="${CURRENT_PUBSPEC_VERSION%%+*}"
CURRENT_BUILD="${CURRENT_PUBSPEC_VERSION#*+}"
if [[ "$CURRENT_BUILD" == "$CURRENT_PUBSPEC_VERSION" ]]; then
  CURRENT_BUILD="0"
fi
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_CORE"

NEXT_PATCH=$((PATCH + 1))
NEXT_BUILD=$((CURRENT_BUILD + 1))
AUTO_VERSION="${MAJOR}.${MINOR}.${NEXT_PATCH}+${NEXT_BUILD}"

VERSION="${1:-$AUTO_VERSION}"
ARCH="amd64"
PKG_NAME="musicvids-studio"
PUBSPEC_VERSION="$VERSION"
if [[ "$PUBSPEC_VERSION" != *"+"* ]]; then
  PUBSPEC_VERSION="${PUBSPEC_VERSION}+${NEXT_BUILD}"
fi

DEB_VERSION="${PUBSPEC_VERSION%%+*}"

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "dpkg-deb not found. Install with: sudo apt install -y dpkg-dev"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH. Install Flutter SDK first."
  exit 1
fi

python3 - <<PY
from pathlib import Path
pubspec = Path("$APP_DIR/pubspec.yaml")
lines = pubspec.read_text().splitlines()
updated = []
replaced = False
for line in lines:
    if line.startswith("version:"):
        updated.append(f"version: $PUBSPEC_VERSION")
        replaced = True
    else:
        updated.append(line)
if not replaced:
    raise SystemExit("Could not find `version:` line in pubspec.yaml")
pubspec.write_text("\\n".join(updated) + "\\n")
PY

python3 - <<PY
from pathlib import Path
candidates = [
    Path("$APP_DIR/lib/screens/dashboard_screen.dart"),
    Path("$ROOT_DIR/bckup/lib/screens/dashboard_screen.dart"),
]
for file in candidates:
    if not file.exists():
        continue
    content = file.read_text()
    fixed = content.replace("return const ListView(", "return ListView(")
    if fixed != content:
        file.write_text(fixed)
        print(f"Applied compatibility fix in {file}")
PY

python3 - <<PY
from pathlib import Path
file = Path("$APP_DIR/lib/widgets/settings_dialog.dart")
if file.exists():
    lines = file.read_text().splitlines()
    targets = {
        "  late final Map<String, TextEditingController> shortcutControllers;",
        "  final List<TextEditingController> customSequenceControllers = [];",
        "  final List<TextEditingController> customLabelControllers = [];",
    }
    seen = set()
    output = []
    changed = False
    for line in lines:
        if line in targets:
            if line in seen:
                changed = True
                continue
            seen.add(line)
        output.append(line)
    if changed:
        file.write_text("\\n".join(output) + "\\n")
        print(f"Removed duplicate controller declarations in {file}")
PY

(
  cd "$APP_DIR"
  flutter clean
  flutter pub get
  flutter build linux --release
)

if [ ! -d "$BUILD_BUNDLE" ]; then
  echo "Release bundle missing after build: $BUILD_BUNDLE"
  exit 1
fi

rm -rf "$PKG_ROOT"
mkdir -p "$PKG_ROOT/DEBIAN"
mkdir -p "$PKG_ROOT/opt/$PKG_NAME"
mkdir -p "$PKG_ROOT/opt/$PKG_NAME/backend"
mkdir -p "$PKG_ROOT/usr/bin"
mkdir -p "$PKG_ROOT/usr/share/applications"

cp -r "$BUILD_BUNDLE"/* "$PKG_ROOT/opt/$PKG_NAME/"
cp -r "$BACKEND_DIR"/* "$PKG_ROOT/opt/$PKG_NAME/backend/"

cat > "$PKG_ROOT/usr/bin/musicvids-studio" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

if [ -x /opt/musicvids-studio/backend/start_backend.sh ]; then
  /opt/musicvids-studio/backend/start_backend.sh || true
fi

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
Version: $DEB_VERSION
Section: video
Priority: optional
Architecture: $ARCH
Maintainer: MusicVid Studio Team
Depends: libgtk-3-0, libstdc++6, python3, python3-venv
Description: Local-first AI music video generation studio
EOF2

dpkg-deb --build "$PKG_ROOT" "$APP_DIR/build/linux/x64/release/${PKG_NAME}_${DEB_VERSION}_${ARCH}.deb"

echo "Built package: $APP_DIR/build/linux/x64/release/${PKG_NAME}_${DEB_VERSION}_${ARCH}.deb"
