#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_HOME="${WAYWHISPER_HOME:-$HOME/.local/share/waywhisper}"
CONFIG_DIR="$HOME/.config/waywhisper"
ENV_FILE="$CONFIG_DIR/waywhisper.env"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
DESKTOP_DIR="$HOME/.local/share/applications"
DRY_RUN=false
START_SERVICE=true

info() {
  printf '[waywhisper] %s\n' "$*"
}

warn() {
  printf '[waywhisper] warning: %s\n' "$*" >&2
}

die() {
  printf '[waywhisper] error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ./install-arch.sh [--dry-run] [--no-start]

Options:
  --dry-run   Show what would be installed without changing the system.
  --no-start  Install files and dependencies without starting user services.
  -h, --help  Show this help.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      --no-start) START_SERVICE=false ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $1" ;;
    esac
    shift
  done
}

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[waywhisper] dry-run:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_arch() {
  command -v pacman >/dev/null 2>&1 || die "this installer is written for Arch Linux"
}

install_packages() {
  local packages=(
    python
    python-pip
    python-virtualenv
    pipewire
    pipewire-pulse
    wl-clipboard
    ydotool
    libnotify
    uv
  )

  info "installing system packages"
  run sudo pacman -S --needed "${packages[@]}"
}

detect_default_source() {
  pactl get-default-source 2>/dev/null || printf '@DEFAULT_SOURCE@'
}

ensure_config_key() {
  local key="$1"
  local value="$2"

  if ! grep -q "^${key}=" "$ENV_FILE"; then
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

install_files() {
  info "installing files"
  run install -Dm755 "$ROOT_DIR/bin/waywhisper-daemon" "$BIN_DIR/waywhisper-daemon"
  run install -Dm755 "$ROOT_DIR/bin/waywhisper-toggle" "$BIN_DIR/waywhisper-toggle"
  run install -Dm755 "$ROOT_DIR/bin/waywhisper-stop" "$BIN_DIR/waywhisper-stop"
  run install -Dm644 "$ROOT_DIR/systemd/waywhisper.service" "$SYSTEMD_DIR/waywhisper.service"
  run install -Dm644 "$ROOT_DIR/desktop/waywhisper-toggle.desktop" "$DESKTOP_DIR/waywhisper-toggle.desktop"
  run install -Dm644 "$ROOT_DIR/desktop/waywhisper-stop.desktop" "$DESKTOP_DIR/waywhisper-stop.desktop"

  if [[ "$DRY_RUN" == true ]]; then
    info "would create or update config at $ENV_FILE"
    return
  fi

  mkdir -p "$CONFIG_DIR"
  if [[ ! -f "$ENV_FILE" ]]; then
    local mic
    mic="$(detect_default_source)"
    sed "s|^WAYWHISPER_MIC=.*|WAYWHISPER_MIC=$mic|" \
      "$ROOT_DIR/config/waywhisper.env.example" > "$ENV_FILE"
  else
    info "keeping existing config at $ENV_FILE"
  fi

  ensure_config_key WAYWHISPER_VAD_FILTER false
  ensure_config_key WAYWHISPER_CONDITION_ON_PREVIOUS_TEXT false
  ensure_config_key WAYWHISPER_PASTE_MODE clipboard
  ensure_config_key WAYWHISPER_EXIT_AFTER_TRANSCRIBE false
}

create_python_env() {
  run mkdir -p "$APP_HOME"

  if [[ "$DRY_RUN" == true ]]; then
    if command -v conda >/dev/null 2>&1; then
      info "would create Python environment with conda"
    elif command -v uv >/dev/null 2>&1; then
      info "would create Python 3.12 environment with uv"
    else
      warn "neither conda nor uv was found; pacman would install uv first"
    fi
    info "would install faster-whisper into $APP_HOME/venv"
    return
  fi

  if [[ -x "$APP_HOME/venv/bin/python" ]]; then
    info "using existing Python environment"
  elif command -v conda >/dev/null 2>&1; then
    info "creating conda environment with Python 3.12"
    conda create -y -p "$APP_HOME/venv" python=3.12 pip
  elif command -v uv >/dev/null 2>&1; then
    info "creating uv environment with Python 3.12"
    uv python install 3.12
    uv venv --python 3.12 "$APP_HOME/venv"
  else
    die "conda or uv is required to create a Python 3.12 environment"
  fi

  info "installing Python packages"
  "$APP_HOME/venv/bin/python" -m pip install --upgrade pip wheel
  "$APP_HOME/venv/bin/python" -m pip install --upgrade faster-whisper
}

show_vram_note() {
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    warn "nvidia-smi was not found; the default auto mode will use CPU"
    return
  fi

  local free total name
  name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || true)"
  total="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)"
  free="$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)"

  if [[ -n "$free" && "$free" =~ ^[0-9]+$ ]]; then
    info "GPU: ${name:-NVIDIA}, VRAM free/total: ${free}/${total:-?} MiB"
    if (( free < 4500 )); then
      warn "large-v3-turbo may not fit comfortably right now. Close GPU-heavy apps or set WAYWHISPER_MODEL=medium."
    fi
  fi
}

enable_services() {
  if [[ "$START_SERVICE" != true ]]; then
    info "services were installed but not started because --no-start was used"
    return
  fi

  info "enabling services"
  run systemctl --user daemon-reload
  run systemctl --user enable --now waywhisper.service

  if systemctl --user list-unit-files ydotool.service >/dev/null 2>&1; then
    run systemctl --user enable --now ydotool.service || \
      warn "ydotool service did not start; text will still be copied to clipboard"
  else
    warn "ydotool user service was not found; text will still be copied to clipboard"
  fi
}

print_next_steps() {
  if [[ "$DRY_RUN" == true ]]; then
    cat <<EOF

Dry run finished. No files were installed and no services were started.

Run the installer without --dry-run to install WayWhisper:
  ./install-arch.sh

EOF
    return
  fi

  cat <<EOF

WayWhisper is installed.

KDE Plasma shortcut:
  1. Open System Settings -> Keyboard -> Shortcuts.
  2. Add an application/command shortcut for:
       $BIN_DIR/waywhisper-toggle
  3. Bind it to Meta+H, Win+H, or any key you like.

Useful commands:
  systemctl --user status waywhisper
  systemctl --user restart waywhisper
  systemctl --user stop waywhisper
  journalctl --user -u waywhisper -f

Before launching a game or another VRAM-heavy app, stop the daemon:
  systemctl --user stop waywhisper

Start it again afterwards:
  systemctl --user start waywhisper

Config:
  $ENV_FILE

Last transcript backup:
  $HOME/.cache/waywhisper/last.txt

EOF
}

main() {
  parse_args "$@"
  require_arch

  if [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]]; then
    warn "current session is not Wayland; this setup is intended for Wayland"
  fi

  case "${XDG_CURRENT_DESKTOP:-}" in
    *KDE*|*Plasma*|*plasma*) ;;
    *) warn "KDE Plasma was not detected. The daemon still works, but shortcut setup may differ." ;;
  esac

  install_packages
  install_files
  create_python_env
  show_vram_note
  enable_services
  print_next_steps
}

main "$@"
