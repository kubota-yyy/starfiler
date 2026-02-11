#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_SCRIPT="$SCRIPT_DIR/build_and_install.sh"

WATCH_INTERVAL_SECONDS="${WATCH_INTERVAL_SECONDS:-1}"
LAUNCH_FLAG="--launch"

usage() {
  cat <<'EOF'
Usage: scripts/watch_and_install.sh [options]

Options:
  --interval <sec>  Polling interval in seconds (default: 1)
  --launch          Launch app after each install (default)
  --no-launch       Do not launch app after install
  -h, --help        Show this help
EOF
}

while (($#)); do
  case "$1" in
    --interval)
      if [[ $# -lt 2 ]]; then
        echo "--interval requires a value" >&2
        exit 1
      fi
      WATCH_INTERVAL_SECONDS="$2"
      shift
      ;;
    --launch)
      LAUNCH_FLAG="--launch"
      ;;
    --no-launch)
      LAUNCH_FLAG="--no-launch"
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

if [[ ! -x "$BUILD_SCRIPT" ]]; then
  echo "Build script is missing or not executable: $BUILD_SCRIPT" >&2
  exit 1
fi

compute_state_hash() {
  /usr/bin/find "$REPO_ROOT/starfiler-app" \
    -type d \( -name .derivedData -o -name .git \) -prune -o \
    -type f \( \
      -name "*.swift" -o \
      -name "*.plist" -o \
      -name "*.json" -o \
      -name "*.entitlements" -o \
      -name "*.pbxproj" -o \
      -name "*.xcscheme" \
    \) \
    -exec /usr/bin/stat -f '%m %N' {} + 2>/dev/null \
    | /usr/bin/sort \
    | /usr/bin/shasum -a 256 \
    | /usr/bin/awk '{print $1}'
}

echo "[watch] initial build/install"
"$BUILD_SCRIPT" "$LAUNCH_FLAG" --quiet
LAST_HASH="$(compute_state_hash)"

echo "[watch] polling every ${WATCH_INTERVAL_SECONDS}s"
while true; do
  /bin/sleep "$WATCH_INTERVAL_SECONDS"
  CURRENT_HASH="$(compute_state_hash)"
  if [[ "$CURRENT_HASH" != "$LAST_HASH" ]]; then
    echo "[watch] change detected at $(/bin/date '+%Y-%m-%d %H:%M:%S')"
    if "$BUILD_SCRIPT" "$LAUNCH_FLAG" --quiet; then
      echo "[watch] install succeeded"
    else
      echo "[watch] build/install failed; waiting for next change" >&2
    fi
    LAST_HASH="$CURRENT_HASH"
  fi
done
