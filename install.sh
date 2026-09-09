#!/usr/bin/env bash
#
# agent-box installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/shftwst/agent-box/main/install.sh | bash
#
# Clones (or updates) agent-box and symlinks the four box wrappers onto PATH.
# Overridable with environment variables:
#   AGENT_BOX_DIR   install dir           (default: ~/.agent-box)
#   AGENT_BOX_BIN   symlink target dir    (default: /usr/local/bin, else ~/.local/bin)
#   AGENT_BOX_REPO  git remote            (default: https://github.com/shftwst/agent-box.git)
#   AGENT_BOX_REF   branch/tag to check out (default: main)

set -euo pipefail

AGENT_BOX_DIR="${AGENT_BOX_DIR:-$HOME/.agent-box}"
AGENT_BOX_REPO="${AGENT_BOX_REPO:-https://github.com/shftwst/agent-box.git}"
AGENT_BOX_REF="${AGENT_BOX_REF:-main}"
BOXES=(claude-box codex-box deepseek-box pi-box)

log()  { printf '[agent-box] %s\n' "$*"; }
die()  { printf '[agent-box] error: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is required but not found on PATH"

if ! command -v docker >/dev/null 2>&1; then
  log "warning: docker not found on PATH. Install Docker Desktop (or Docker Engine on Linux) before running a box."
fi

# Clone, or update an existing checkout in place.
if [ -d "$AGENT_BOX_DIR/.git" ]; then
  log "updating existing checkout at $AGENT_BOX_DIR"
  git -C "$AGENT_BOX_DIR" fetch --quiet origin "$AGENT_BOX_REF"
  git -C "$AGENT_BOX_DIR" checkout --quiet "$AGENT_BOX_REF"
  git -C "$AGENT_BOX_DIR" pull --ff-only --quiet
elif [ -e "$AGENT_BOX_DIR" ]; then
  die "$AGENT_BOX_DIR exists but is not a git checkout. Remove it or set AGENT_BOX_DIR."
else
  log "cloning $AGENT_BOX_REPO into $AGENT_BOX_DIR"
  git clone --quiet --branch "$AGENT_BOX_REF" "$AGENT_BOX_REPO" "$AGENT_BOX_DIR"
fi

chmod +x "${BOXES[@]/#/$AGENT_BOX_DIR/}"

# Pick a bin dir on PATH: honour an override, else /usr/local/bin if we can
# write to it (directly or via sudo), else fall back to ~/.local/bin.
SUDO=""
if [ -n "${AGENT_BOX_BIN:-}" ]; then
  bin="$AGENT_BOX_BIN"
elif [ -w /usr/local/bin ]; then
  bin="/usr/local/bin"
elif command -v sudo >/dev/null 2>&1 && [ -d /usr/local/bin ]; then
  bin="/usr/local/bin"
  SUDO="sudo"
  log "writing symlinks to $bin via sudo"
else
  bin="$HOME/.local/bin"
fi
mkdir -p "$bin" 2>/dev/null || $SUDO mkdir -p "$bin"

for box in "${BOXES[@]}"; do
  $SUDO ln -sf "$AGENT_BOX_DIR/$box" "$bin/$box"
done

log "installed ${#BOXES[@]} boxes to $bin: ${BOXES[*]}"

case ":$PATH:" in
  *":$bin:"*) ;;
  *) log "note: $bin is not on your PATH. Add it, e.g. export PATH=\"$bin:\$PATH\"" ;;
esac

log "done. cd into a project and run 'claude-box' (or codex-box / deepseek-box / pi-box)."
