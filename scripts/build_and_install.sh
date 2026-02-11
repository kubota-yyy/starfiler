#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_DIR="$REPO_ROOT/starfiler-app"
PROJECT_FILE="$PROJECT_DIR/starfiler.xcodeproj"
SCHEME="${SCHEME:-starfiler}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PROJECT_DIR/.derivedData}"
APP_NAME="${APP_NAME:-Starfiler.app}"
APP_SOURCE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME"
APP_DEST="${APP_DEST:-/Applications/$APP_NAME}"
PROCESS_NAME="${APP_NAME%.app}"
LEGACY_APP_DEST="/Applications/starfiler.app"
LEGACY_PROCESS_NAME="starfiler"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-${APP_NAME%.app}}"
SOURCE_EXECUTABLE="$APP_SOURCE/Contents/MacOS/$EXECUTABLE_NAME"
DEST_EXECUTABLE="$APP_DEST/Contents/MacOS/$EXECUTABLE_NAME"
NORMALIZED_APP_DEST="$(printf '%s' "$APP_DEST" | /usr/bin/tr '[:upper:]' '[:lower:]')"
NORMALIZED_LEGACY_APP_DEST="$(printf '%s' "$LEGACY_APP_DEST" | /usr/bin/tr '[:upper:]' '[:lower:]')"

LAUNCH_AFTER_INSTALL=true
QUIET=false

usage() {
  cat <<'EOF'
Usage: scripts/build_and_install.sh [options]

Options:
  --launch       Launch app after install (default)
  --no-launch    Install only
  --quiet        Quiet xcodebuild output
  -h, --help     Show this help
EOF
}

while (($#)); do
  case "$1" in
    --launch)
      LAUNCH_AFTER_INSTALL=true
      ;;
    --no-launch)
      LAUNCH_AFTER_INSTALL=false
      ;;
    --quiet)
      QUIET=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Project directory not found: $PROJECT_DIR" >&2
  exit 1
fi

echo "[build] scheme=$SCHEME configuration=$CONFIGURATION"
echo "[build] derivedData=$DERIVED_DATA_PATH"

if [[ "$QUIET" == true ]]; then
  /usr/bin/xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build \
    -quiet
else
  /usr/bin/xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
fi

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "Built app not found: $APP_SOURCE" >&2
  exit 1
fi

if /usr/bin/pgrep -x "$PROCESS_NAME" >/dev/null 2>&1; then
  echo "[install] stopping running process: $PROCESS_NAME"
  /usr/bin/pkill -x "$PROCESS_NAME" || true
  /bin/sleep 0.3
fi

if [[ "$APP_DEST" == "/Applications/Starfiler.app" ]] && /usr/bin/pgrep -x "$LEGACY_PROCESS_NAME" >/dev/null 2>&1; then
  echo "[install] stopping legacy process: $LEGACY_PROCESS_NAME"
  /usr/bin/pkill -x "$LEGACY_PROCESS_NAME" || true
  /bin/sleep 0.3
fi

echo "[install] $APP_DEST"
/bin/rm -rf "$APP_DEST"
/bin/cp -R "$APP_SOURCE" "$APP_DEST"

if [[ "$APP_DEST" == "/Applications/Starfiler.app" ]] && [[ "$NORMALIZED_APP_DEST" != "$NORMALIZED_LEGACY_APP_DEST" ]] && [[ -d "$LEGACY_APP_DEST" ]]; then
  echo "[install] removing legacy app: $LEGACY_APP_DEST"
  /bin/rm -rf "$LEGACY_APP_DEST"
fi

/usr/bin/xattr -dr com.apple.quarantine "$APP_DEST" >/dev/null 2>&1 || true
/usr/bin/codesign --verify --deep --strict "$APP_DEST"

if [[ ! -f "$SOURCE_EXECUTABLE" ]]; then
  echo "Source executable not found: $SOURCE_EXECUTABLE" >&2
  exit 1
fi

if [[ ! -f "$DEST_EXECUTABLE" ]]; then
  echo "Installed executable not found: $DEST_EXECUTABLE" >&2
  exit 1
fi

SOURCE_HASH="$(/usr/bin/shasum -a 256 "$SOURCE_EXECUTABLE" | /usr/bin/awk '{print $1}')"
DEST_HASH="$(/usr/bin/shasum -a 256 "$DEST_EXECUTABLE" | /usr/bin/awk '{print $1}')"
if [[ "$SOURCE_HASH" != "$DEST_HASH" ]]; then
  echo "Install verification failed: source and destination binaries differ." >&2
  echo "source: $SOURCE_EXECUTABLE" >&2
  echo "dest:   $DEST_EXECUTABLE" >&2
  exit 1
fi
echo "[verify] installed binary hash matches build output ($DEST_HASH)"

if [[ "$LAUNCH_AFTER_INSTALL" == true ]]; then
  echo "[launch] opening $APP_DEST"
  /usr/bin/open -a "$APP_DEST"
fi

echo "[done] installed $APP_DEST"
