#!/usr/bin/env bash
#
# setup_acestep.sh — install ACE-Step into a local venv and launch its API
# server, so `.claude/skills/music/scripts/acestep.sh` can render songs to WAV.
#
# Run this on a machine WITH a GPU (the model needs one to generate audio in a
# reasonable time). It is idempotent: re-running reuses the existing checkout
# and venv.
#
# Usage:
#   scripts/setup_acestep.sh             # install (if needed) + start server
#   scripts/setup_acestep.sh --install   # install only, don't start
#   scripts/setup_acestep.sh --start     # start only (assume installed)
#
# Configuration (env vars):
#   ACESTEP_HOME   Where to clone/install ACE-Step (default ./.acestep)
#   ACESTEP_REPO   Git URL                          (default official repo)
#   ACESTEP_PORT   API/Gradio port                  (default 7865)
#   ACESTEP_HOST   Bind address                     (default 0.0.0.0)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repo root
ACESTEP_HOME="${ACESTEP_HOME:-$HERE/.acestep}"
ACESTEP_REPO="${ACESTEP_REPO:-https://github.com/ace-step/ACE-Step.git}"
ACESTEP_PORT="${ACESTEP_PORT:-7865}"
ACESTEP_HOST="${ACESTEP_HOST:-0.0.0.0}"
VENV="$ACESTEP_HOME/.venv"

log()  { printf '\033[1;36m[setup]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n'  "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

MODE="all"
case "${1:-}" in
  --install) MODE="install" ;;
  --start)   MODE="start" ;;
  "" )       MODE="all" ;;
  *) die "unknown argument: $1 (use --install or --start)" ;;
esac

# --- preflight --------------------------------------------------------------
command -v git    >/dev/null || die "git not found"
PY="$(command -v python3 || true)"; [[ -n "$PY" ]] || die "python3 not found"

if command -v nvidia-smi >/dev/null 2>&1; then
  log "GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
else
  warn "No GPU detected — generation will be extremely slow or may fail."
  warn "ACE-Step is designed to run on a CUDA GPU."
fi

install_acestep() {
  if [[ ! -d "$ACESTEP_HOME/.git" ]]; then
    log "Cloning ACE-Step into $ACESTEP_HOME"
    git clone --depth 1 "$ACESTEP_REPO" "$ACESTEP_HOME"
  else
    log "ACE-Step checkout already present at $ACESTEP_HOME"
  fi

  if [[ ! -d "$VENV" ]]; then
    log "Creating venv at $VENV"
    "$PY" -m venv "$VENV"
  fi
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"

  log "Upgrading pip"
  python -m pip install --quiet --upgrade pip

  log "Installing ACE-Step (this can take a while — torch + model deps)"
  if [[ -f "$ACESTEP_HOME/pyproject.toml" || -f "$ACESTEP_HOME/setup.py" ]]; then
    python -m pip install -e "$ACESTEP_HOME"
  else
    # Fallback: published package, if the repo layout changes.
    python -m pip install acestep || die "Could not install ACE-Step; check $ACESTEP_REPO README."
  fi
  log "Install complete."
}

start_server() {
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"
  log "Starting ACE-Step API server on http://${ACESTEP_HOST}:${ACESTEP_PORT}"
  log "Leave this running, then in another terminal:"
  log "  .claude/skills/music/scripts/acestep.sh songs/restart.md"

  # The CLI entrypoint name has varied across versions; try the common ones.
  if command -v acestep >/dev/null 2>&1; then
    exec acestep --server_name "$ACESTEP_HOST" --port "$ACESTEP_PORT"
  elif python -c "import acestep.gui" >/dev/null 2>&1; then
    exec python -m acestep.gui --server_name "$ACESTEP_HOST" --port "$ACESTEP_PORT"
  elif [[ -f "$ACESTEP_HOME/app.py" ]]; then
    exec python "$ACESTEP_HOME/app.py" --server_name "$ACESTEP_HOST" --port "$ACESTEP_PORT"
  else
    die "Could not find an ACE-Step launch entrypoint. See $ACESTEP_HOME README and adjust ACESTEP_PORT/launch command."
  fi
}

case "$MODE" in
  install) install_acestep ;;
  start)   start_server ;;
  all)
    [[ -d "$VENV" && -d "$ACESTEP_HOME/.git" ]] || install_acestep
    start_server
    ;;
esac
