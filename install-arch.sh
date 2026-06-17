#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_HOME="${WAYWHISPER_HOME:-$HOME/.local/share/waywhisper}"
CONFIG_DIR="$HOME/.config/waywhisper"
ENV_FILE="$CONFIG_DIR/waywhisper.env"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
DESKTOP_DIR="$HOME/.local/share/applications"

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
  )

  info "installing system packages"
  sudo pacman -S --needed "${packages[@]}"
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
  install -Dm755 "$ROOT_DIR/bin/waywhisper-daemon" "$BIN_DIR/waywhisper-daemon"
  install -Dm755 "$ROOT_DIR/bin/waywhisper-toggle" "$BIN_DIR/waywhisper-toggle"
  install -Dm644 "$ROOT_DIR/systemd/waywhisper.service" "$SYSTEMD_DIR/waywhisper.service"
  install -Dm644 "$ROOT_DIR/desktop/waywhisper-toggle.desktop" "$DESKTOP_DIR/waywhisper-toggle.desktop"

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
}

create_python_env() {
  mkdir -p "$APP_HOME"

  if [[ -x "$APP_HOME/venv/bin/python" ]]; then
    info "using existing Python environment"
  elif command -v conda >/dev/null 2>&1; then
    info "creating conda environment with Python 3.12"
    conda create -y -p "$APP_HOME/venv" python=3.12 pip
  else
    info "creating Python venv"
    python -m venv "$APP_HOME/venv"
    warn "Arch Python can be newer than some wheels. If pip install fails, install conda and run this script again."
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
  info "enabling services"
  systemctl --user daemon-reload
  systemctl --user enable --now waywhisper.service

  if systemctl --user list-unit-files ydotool.service >/dev/null 2>&1; then
    systemctl --user enable --now ydotool.service || \
      warn "ydotool service did not start; text will still be copied to clipboard"
  else
    warn "ydotool user service was not found; text will still be copied to clipboard"
  fi
}

print_next_steps() {
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
