#!/bin/sh
# Kernel Kiosk setup for Unix-like systems. Installs Go and Godot 4 when needed.
set -eu

PROJECT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
SKIP_EXPORT=false

usage() {
  printf '%s\n' "Usage: ./setup.sh [--skip-export]"
  printf '%s\n' "  --skip-export  Reuse an existing web/ Godot export."
}

case "${1:-}" in
  "") ;;
  --skip-export) SKIP_EXPORT=true ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    printf '%s\n' "Administrator privileges are required to install dependencies." >&2
    exit 1
  fi
  sudo "$@"
}

find_godot() {
  if [ -n "${GODOT:-}" ] && command -v "$GODOT" >/dev/null 2>&1; then
    printf '%s\n' "$GODOT"
    return
  fi
  for candidate in godot godot4 Godot; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

ensure_export_templates() {
  GODOT_BIN=$1
  GODOT_VERSION=$($GODOT_BIN --version | awk 'NR == 1 { print $1 }')
  TEMPLATE_TAG=$(printf '%s' "$GODOT_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+)\.([^.]+).*/\1-\2/')
  TEMPLATE_DIR_NAME=$(printf '%s' "$GODOT_VERSION" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+\.[^.]+).*/\1/')

  case "$(uname -s)" in
    Darwin) GODOT_DATA_DIR=${GODOT_DATA_DIR:-"$HOME/Library/Application Support/Godot"} ;;
    *) GODOT_DATA_DIR=${GODOT_DATA_DIR:-"${XDG_DATA_HOME:-$HOME/.local/share}/godot"} ;;
  esac
  TEMPLATE_DIR="$GODOT_DATA_DIR/export_templates/$TEMPLATE_DIR_NAME"
  if [ -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]; then
    return
  fi

  require_command curl
  require_command unzip
  printf 'Installing Godot %s Web export templates...\n' "$GODOT_VERSION"
  mkdir -p "$TEMPLATE_DIR"
  TEMPLATE_ARCHIVE="$TEMPLATE_DIR/Godot_v${TEMPLATE_TAG}_export_templates.tpz"
  if [ -f "$TEMPLATE_ARCHIVE" ] && ! unzip -tq "$TEMPLATE_ARCHIVE" >/dev/null 2>&1; then
    BAD_ARCHIVE="$TEMPLATE_ARCHIVE.corrupt-$(date +%s)"
    printf 'Existing template archive is corrupt; preserving it as %s and downloading again.\n' "$BAD_ARCHIVE"
    mv "$TEMPLATE_ARCHIVE" "$BAD_ARCHIVE"
  fi
  curl --fail --location --continue-at - --retry 3 --output "$TEMPLATE_ARCHIVE" "https://github.com/godotengine/godot/releases/download/${TEMPLATE_TAG}/Godot_v${TEMPLATE_TAG}_export_templates.tpz"
  if ! unzip -tq "$TEMPLATE_ARCHIVE" >/dev/null 2>&1; then
    printf '%s\n' "Downloaded Godot template archive is corrupt. Rerun setup to retry." >&2
    exit 1
  fi
  unzip -oq "$TEMPLATE_ARCHIVE" -d "$TEMPLATE_DIR"
  if [ -d "$TEMPLATE_DIR/templates" ]; then
    for template_file in "$TEMPLATE_DIR"/templates/*; do
      mv "$template_file" "$TEMPLATE_DIR/"
    done
    rmdir "$TEMPLATE_DIR/templates"
  fi
  if [ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]; then
    printf '%s\n' "The downloaded Godot templates did not include a Web export template." >&2
    exit 1
  fi
}

install_dependencies() {
  missing_go=false
  missing_make=false
  missing_godot=false
  command -v go >/dev/null 2>&1 || missing_go=true
  command -v make >/dev/null 2>&1 || missing_make=true
  if [ "$SKIP_EXPORT" = false ]; then
    find_godot >/dev/null 2>&1 || missing_godot=true
  fi

  if [ "$missing_go" = false ] && [ "$missing_make" = false ] && [ "$missing_godot" = false ]; then
    return
  fi

  printf '%s\n' "Installing missing build dependencies through the system package manager..."
  if command -v brew >/dev/null 2>&1; then
    [ "$missing_make" = false ] || brew install make
    [ "$missing_go" = false ] || brew install go
    [ "$missing_godot" = false ] || brew install godot
  elif command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update
    [ "$missing_make" = false ] || as_root apt-get install -y make
    [ "$missing_go" = false ] || as_root apt-get install -y golang-go
    [ "$missing_godot" = false ] || as_root apt-get install -y godot4
  elif command -v dnf >/dev/null 2>&1; then
    [ "$missing_make" = false ] || as_root dnf install -y make
    [ "$missing_go" = false ] || as_root dnf install -y golang
    [ "$missing_godot" = false ] || as_root dnf install -y godot
  elif command -v pacman >/dev/null 2>&1; then
    [ "$missing_make" = false ] || as_root pacman -Sy --needed --noconfirm make
    [ "$missing_go" = false ] || as_root pacman -S --needed --noconfirm go
    [ "$missing_godot" = false ] || as_root pacman -S --needed --noconfirm godot
  elif command -v apk >/dev/null 2>&1; then
    [ "$missing_make" = false ] || as_root apk add make
    [ "$missing_go" = false ] || as_root apk add go
    [ "$missing_godot" = false ] || as_root apk add godot
  elif command -v zypper >/dev/null 2>&1; then
    [ "$missing_make" = false ] || as_root zypper --non-interactive install make
    [ "$missing_go" = false ] || as_root zypper --non-interactive install go
    [ "$missing_godot" = false ] || as_root zypper --non-interactive install godot
  else
    printf '%s\n' "No supported package manager was found. Install Go 1.23+, make, and Godot 4.3+, then rerun." >&2
    exit 1
  fi
}

cd "$PROJECT_DIR"
install_dependencies
require_command go
require_command make

GO_VERSION=$(go version)
printf 'Using %s\n' "$GO_VERSION"

if [ "$SKIP_EXPORT" = false ]; then
  GODOT_BIN=$(find_godot || true)
  if [ -z "$GODOT_BIN" ]; then
    printf '%s\n' "Godot was installed but no command was found. Set GODOT to its executable path, then rerun." >&2
    exit 1
  fi
  printf 'Exporting Godot web build with %s...\n' "$GODOT_BIN"
  ensure_export_templates "$GODOT_BIN"
  GODOT="$GODOT_BIN" make export-web
elif [ ! -f web/index.html ]; then
  printf '%s\n' "web/index.html is missing; --skip-export cannot be used before a web export." >&2
  exit 1
fi

printf 'Testing server source...\n'
go test ./...

printf 'Building server for this machine...\n'
mkdir -p bin
go build -trimpath -ldflags='-s -w' -o bin/kernel-kiosk ./cmd/kernel-kiosk
chmod 755 bin/kernel-kiosk

printf '%s\n' ""
printf '%s\n' "Setup complete. Start Kernel Kiosk with:"
printf '%s\n' "  ./bin/kernel-kiosk"
printf '%s\n' "Open http://localhost:8009"
